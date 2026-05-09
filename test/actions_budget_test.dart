import 'package:flutter_test/flutter_test.dart';
import 'package:oksigenia_farmkit/oksigenia_farmkit.dart';

Farm makeBudgetedFarm({int actions = 2}) => Farm(
      fields: [
        Field(id: 'a', size: 1.0, soil: SoilType.loam),
        Field(id: 'b', size: 1.0, soil: SoilType.loam),
      ],
      weather: const MockWeatherProvider.seasonal(),
      actionsPerTurn: actions,
    );

void main() {
  group('Action budget — disabled by default', () {
    test('farm without actionsPerTurn allows unlimited actions', () {
      final farm = Farm(
        fields: [Field(id: 'a', size: 1.0, soil: SoilType.loam)],
        weather: const MockWeatherProvider.seasonal(),
      );
      expect(farm.actionsPerTurn, isNull);
      expect(farm.actionsRemaining, isNull);
      // 100 plantings shouldn't throw — but we can't actually plant
      // 100 times without harvesting; we settle for 1 plant + 1 reset.
      farm.plant(fieldId: 'a', crop: Crop.lettuce);
      farm.advanceTurn();
      farm.advanceTurn();
      // Harvest, replant, harvest, replant — none throws.
      farm.harvest('a');
      farm.plant(fieldId: 'a', crop: Crop.tomato);
      // Si no había budget, actionsRemaining sigue null.
      expect(farm.actionsRemaining, isNull);
    });
  });

  group('Action budget — enabled', () {
    test('farm reports correct initial actions', () {
      final farm = makeBudgetedFarm(actions: 3);
      expect(farm.actionsRemaining, 3);
    });

    test('plant consumes one action', () {
      final farm = makeBudgetedFarm(actions: 3);
      farm.plant(fieldId: 'a', crop: Crop.lettuce);
      expect(farm.actionsRemaining, 2);
    });

    test('harvest consumes one action', () {
      final farm = makeBudgetedFarm(actions: 5);
      farm.plant(fieldId: 'a', crop: Crop.lettuce);
      // Avanzar turnos hasta que esté lista (turnsToMature=2 + seed).
      // El advance recarga el budget, así que después tendremos 5 de
      // nuevo y harvest sólo bajará uno.
      farm.advanceTurn();
      farm.advanceTurn();
      expect(farm.actionsRemaining, 5);
      farm.harvest('a');
      expect(farm.actionsRemaining, 4);
    });

    test('treat consumes one action', () {
      final farm = makeBudgetedFarm(actions: 3);
      farm.plant(fieldId: 'a', crop: Crop.tomato);
      farm.treat('a');
      // 1 plant + 1 treat = 2 acciones.
      expect(farm.actionsRemaining, 1);
    });

    test('out of actions throws', () {
      final farm = makeBudgetedFarm(actions: 1);
      farm.plant(fieldId: 'a', crop: Crop.lettuce);
      expect(farm.actionsRemaining, 0);
      expect(
        () => farm.plant(fieldId: 'b', crop: Crop.tomato),
        throwsA(isA<OutOfActionsError>()),
      );
    });

    test('advanceTurn refills the budget', () {
      final farm = makeBudgetedFarm(actions: 2);
      farm.plant(fieldId: 'a', crop: Crop.lettuce);
      farm.plant(fieldId: 'b', crop: Crop.tomato);
      expect(farm.actionsRemaining, 0);
      farm.advanceTurn();
      expect(farm.actionsRemaining, 2);
    });

    test('actionsPerTurn = 0 freezes the farm', () {
      final farm = makeBudgetedFarm(actions: 0);
      expect(
        () => farm.plant(fieldId: 'a', crop: Crop.lettuce),
        throwsA(isA<OutOfActionsError>()),
      );
    });
  });
}
