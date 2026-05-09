import 'package:flutter_test/flutter_test.dart';
import 'package:oksigenia_farmkit/oksigenia_farmkit.dart';

void main() {
  group('Field growth state machine', () {
    test('empty field reports GrowthStage.empty', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      expect(f.growthStage, GrowthStage.empty);
      expect(f.crop, isNull);
    });

    test('newly planted field is seedling for the first turn', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      f.plant(Crop.tomato);
      expect(f.growthStage, GrowthStage.seedling);
    });

    test('field reaches ready stage after turnsToMature advances', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      f.plant(Crop.lettuce); // turnsToMature = 2
      f.advance(weatherFactor: 1.0);
      expect(f.growthStage, GrowthStage.growing);
      f.advance(weatherFactor: 1.0);
      expect(f.growthStage, GrowthStage.ready);
    });

    test('planting on an occupied field throws', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      f.plant(Crop.tomato);
      expect(() => f.plant(Crop.wheat), throwsStateError);
    });

    test('harvest of unready field returns 0 and leaves crop in place', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      f.plant(Crop.tomato);
      f.advance(weatherFactor: 1.0);
      expect(f.harvest(), 0.0);
      expect(f.crop, Crop.tomato);
    });

    test('harvest of ready field clears it and returns positive yield', () {
      final f = Field(id: 'a', size: 2.0, soil: SoilType.loam);
      f.plant(Crop.lettuce);
      f.advance(weatherFactor: 1.0);
      f.advance(weatherFactor: 1.0);
      final y = f.harvest();
      expect(y, greaterThan(0.0));
      expect(f.crop, isNull);
      expect(f.growthStage, GrowthStage.empty);
    });
  });

  group('Quality accumulation', () {
    test('perfect weather on preferred soil yields high quality', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      f.plant(Crop.tomato);
      for (var i = 0; i < Crop.tomato.turnsToMature; i++) {
        f.advance(weatherFactor: 1.0);
      }
      expect(f.quality, greaterThan(0.9));
    });

    test('zero weather drives quality to zero', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      f.plant(Crop.tomato);
      for (var i = 0; i < Crop.tomato.turnsToMature; i++) {
        f.advance(weatherFactor: 0.0);
      }
      expect(f.quality, 0.0);
    });
  });

  group('Farm facade', () {
    test('advanceTurn increments the turn counter', () {
      final farm = Farm(
        fields: [Field(id: 'a', size: 1.0, soil: SoilType.loam)],
        weather: const MockWeatherProvider.seasonal(),
      );
      expect(farm.turn, 0);
      farm.advanceTurn();
      expect(farm.turn, 1);
    });

    test('looking up an unknown field throws', () {
      final farm = Farm(
        fields: [Field(id: 'a', size: 1.0, soil: SoilType.loam)],
        weather: const MockWeatherProvider.seasonal(),
      );
      expect(() => farm.field('does-not-exist'), throwsStateError);
    });
  });

  group('Economy', () {
    const econ = LinearQualityPricing();

    test('quality 0 returns floor price', () {
      expect(econ.expectedPrice(Crop.tomato, quality: 0.0),
          closeTo(Crop.tomato.basePrice * 0.4, 1e-9));
    });

    test('quality 1 returns ceiling price', () {
      expect(econ.expectedPrice(Crop.tomato, quality: 1.0),
          closeTo(Crop.tomato.basePrice * 1.4, 1e-9));
    });

    test('out-of-range quality is clamped', () {
      final low = econ.expectedPrice(Crop.tomato, quality: -0.5);
      final high = econ.expectedPrice(Crop.tomato, quality: 1.5);
      expect(low, closeTo(Crop.tomato.basePrice * 0.4, 1e-9));
      expect(high, closeTo(Crop.tomato.basePrice * 1.4, 1e-9));
    });
  });

  group('MockWeatherProvider', () {
    const provider = MockWeatherProvider.seasonal();

    test('same turn returns equivalent samples (deterministic)', () {
      final a = provider.sample(turn: 10);
      final b = provider.sample(turn: 10);
      expect(a.growthFactor, b.growthFactor);
      expect(a.temperatureC, b.temperatureC);
    });

    test('growth factor stays in [0, 1]', () {
      for (var t = 0; t < 200; t++) {
        final w = provider.sample(turn: t);
        expect(w.growthFactor, inInclusiveRange(0.0, 1.0));
      }
    });
  });

  group('Serialization', () {
    test('round-trip preserves field state and turn count', () {
      final farm = Farm(
        fields: [
          Field(id: 'a', size: 1.0, soil: SoilType.loam),
          Field(id: 'b', size: 0.5, soil: SoilType.sandy),
        ],
        weather: const MockWeatherProvider.seasonal(),
      );
      farm.plant(fieldId: 'a', crop: Crop.tomato);
      farm.advanceTurn();
      farm.advanceTurn();

      final snapshot = Serialization.farmToMap(farm);

      // Build a fresh farm with the same shape and apply.
      final restored = Farm(
        fields: [
          Field(id: 'a', size: 1.0, soil: SoilType.loam),
          Field(id: 'b', size: 0.5, soil: SoilType.sandy),
        ],
        weather: const MockWeatherProvider.seasonal(),
      );
      Serialization.applyFarmFromMap(restored, snapshot);

      expect(restored.turn, farm.turn);
      expect(restored.field('a').crop, Crop.tomato);
      expect(restored.field('a').turnsGrown, farm.field('a').turnsGrown);
      expect(restored.field('a').quality, farm.field('a').quality);
      expect(restored.field('b').crop, isNull);
    });

    test('refuses unknown schema version', () {
      final farm = Farm(
        fields: [Field(id: 'a', size: 1.0, soil: SoilType.loam)],
        weather: const MockWeatherProvider.seasonal(),
      );
      expect(
        () => Serialization.applyFarmFromMap(farm, {'schema': 999}),
        throwsStateError,
      );
    });
  });
}
