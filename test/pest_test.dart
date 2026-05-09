import 'package:flutter_test/flutter_test.dart';
import 'package:oksigenia_farmkit/oksigenia_farmkit.dart';

/// Crop sintético altamente susceptible para que la presión suba
/// rápido en los tests sin pelear con el ruido del mock. `turnsToMature`
/// = 2 permite cosechar tras 2 advances → útil para probar el reset
/// que el harvest hace sobre el pestPressure.
const _verySusceptible = Crop(
  id: 'vulnerable',
  displayName: 'Vulnerable',
  turnsToMature: 2,
  preferredSoils: {SoilType.loam},
  basePrice: 10.0,
  family: CropFamily.nightshade,
  pestSusceptibility: 1.0,
);

/// Crop sintético resistente, baseline para comparar.
const _resistant = Crop(
  id: 'resistant',
  displayName: 'Resistant',
  turnsToMature: 5,
  preferredSoils: {SoilType.loam},
  basePrice: 10.0,
  pestSusceptibility: 0.0,
);

void main() {
  group('Field.advance with pestRisk', () {
    test('susceptible crop accumulates pestPressure each turn', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      f.plant(_verySusceptible);
      // pestRisk 0.8 sostenido: cada turno suma 0.8 * 1.0 * 0.35 = 0.28.
      // Tras 2 turnos debería haber pasado 0.5.
      f.advance(weatherFactor: 1.0, pestRisk: 0.8);
      f.advance(weatherFactor: 1.0, pestRisk: 0.8);
      expect(f.pestPressure, greaterThan(0.5));
    });

    test('resistant crop barely accumulates pressure', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      f.plant(_resistant);
      for (var i = 0; i < 5; i++) {
        f.advance(weatherFactor: 1.0, pestRisk: 1.0);
      }
      expect(f.pestPressure, lessThan(0.05));
    });

    test('zero pestRisk leaves pestPressure unchanged', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      f.plant(_verySusceptible);
      f.advance(weatherFactor: 1.0, pestRisk: 0.0);
      f.advance(weatherFactor: 1.0, pestRisk: 0.0);
      expect(f.pestPressure, 0.0);
    });

    test('pestPressure caps at 1.0', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      f.plant(_verySusceptible);
      for (var i = 0; i < 50; i++) {
        f.advance(weatherFactor: 1.0, pestRisk: 1.0);
      }
      expect(f.pestPressure, lessThanOrEqualTo(1.0));
    });

    test('fallow turn decays pestPressure', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      f.plant(_verySusceptible);
      f.advance(weatherFactor: 1.0, pestRisk: 1.0);
      f.advance(weatherFactor: 1.0, pestRisk: 1.0);
      // Cosechar limpia el cultivo. La presión queda al 30%.
      f.harvest();
      final afterHarvest = f.pestPressure;
      // Un turno en barbecho decae 0.10 más.
      f.advance(weatherFactor: 1.0, pestRisk: 0.0);
      expect(f.pestPressure, lessThan(afterHarvest));
    });
  });

  group('Field.applyTreatment', () {
    test('reduces pestPressure by the requested amount', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      f.plant(_verySusceptible);
      f.advance(weatherFactor: 1.0, pestRisk: 1.0);
      f.advance(weatherFactor: 1.0, pestRisk: 1.0);
      final before = f.pestPressure;
      f.applyTreatment(reduction: 0.4);
      expect(f.pestPressure, closeTo(before - 0.4, 1e-9));
    });

    test('clamps at zero', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      f.plant(_verySusceptible);
      f.applyTreatment(reduction: 1.0);
      expect(f.pestPressure, 0.0);
    });
  });

  group('Field.advance quality penalty under pest', () {
    test('high pestPressure lowers final quality vs healthy field', () {
      final clean = Field(id: 'c', size: 1.0, soil: SoilType.loam);
      final infected = Field(id: 'i', size: 1.0, soil: SoilType.loam);
      // El campo "infected" arranca con 0.6 de pestPressure inyectado
      // a través de un cultivo previo + acumulación. Lo simulamos con
      // muchos turnos de pestRisk antes de plantar el cultivo a medir.
      clean.plant(Crop.tomato);
      // Para inducir presión: plant + advances con pestRisk antes.
      infected.plant(_verySusceptible);
      for (var i = 0; i < 3; i++) {
        infected.advance(weatherFactor: 0.0, pestRisk: 1.0);
      }
      infected.harvest(); // limpia parcial pero mantiene algo de presión
      // Ahora plantamos tomate igual que en clean y comparamos.
      infected.plant(Crop.tomato);
      for (var i = 0; i < Crop.tomato.turnsToMature; i++) {
        // weatherFactor perfecto; pestRisk 0 para aislar el efecto del
        // pestPressure preexistente.
        clean.advance(weatherFactor: 1.0, pestRisk: 0.0);
        infected.advance(weatherFactor: 1.0, pestRisk: 0.0);
      }
      expect(infected.quality, lessThan(clean.quality));
    });
  });

  group('Farm pest events', () {
    Farm makeFarm() => Farm(
          fields: [Field(id: 'a', size: 1.0, soil: SoilType.loam)],
          weather: const MockWeatherProvider.seasonal(),
        );

    test('fires pestOutbreak when pressure crosses 0.3', () {
      final farm = makeFarm();
      farm.field('a').plant(_verySusceptible);
      // Un solo advance manual con pestRisk=1.0 → pestPressure = 0.35
      // (cae en banda outbreak, no critical). El advance del Farm
      // sumará algo más pero seguirá en outbreak para verificar la
      // emisión de pestOutbreak antes de saltar a critical.
      farm.field('a').advance(weatherFactor: 1.0, pestRisk: 1.0);
      farm.advanceTurn();
      final events = farm.drainEvents();
      expect(events.any((e) => e.kind == FarmEventKind.pestOutbreak), isTrue);
    });

    test('treat() reduces pressure and fires pestCleared if crosses below 0.1', () {
      final farm = makeFarm();
      farm.field('a').plant(_verySusceptible);
      farm.field('a').advance(weatherFactor: 1.0, pestRisk: 1.0);
      farm.field('a').advance(weatherFactor: 1.0, pestRisk: 1.0);
      farm.advanceTurn();
      farm.drainEvents(); // limpiar previos
      farm.treat('a', reduction: 1.0);
      final events = farm.drainEvents();
      expect(events.any((e) => e.kind == FarmEventKind.pestCleared), isTrue);
    });
  });

  group('MockWeatherProvider pestRisk', () {
    test('hot humid weeks produce non-zero pestRisk', () {
      // El preset tropical tiene baseline 26°C con precip alta — el
      // pestRisk debería superar 0.3 en al menos algún turno del año.
      const prov = MockWeatherProvider.forClimate(ClimatePreset.tropical);
      var maxRisk = 0.0;
      for (var t = 0; t < 52; t++) {
        final r = prov.sample(turn: t).pestRisk;
        if (r > maxRisk) maxRisk = r;
      }
      expect(maxRisk, greaterThan(0.3));
    });

    test('cold dry weeks produce zero pestRisk', () {
      // Preset continental con jitter mínimo: el invierno cae < 18°C
      // y la precip baja. Verificamos que algún turno de invierno
      // efectivamente da pestRisk 0.
      const prov = MockWeatherProvider.forClimate(ClimatePreset.continental);
      var sawZero = false;
      for (var t = 0; t < 52; t++) {
        if (prov.sample(turn: t).pestRisk == 0) sawZero = true;
      }
      expect(sawZero, isTrue);
    });
  });
}
