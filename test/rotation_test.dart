import 'package:flutter_test/flutter_test.dart';
import 'package:oksigenia_farmkit/oksigenia_farmkit.dart';

/// Helpers that grow a single crop to maturity under perfect weather
/// so the test focuses on fertility / rotation behaviour rather than
/// growth-stage timing.
void _growToHarvest(Field f, Crop c) {
  f.plant(c);
  for (var i = 0; i < c.turnsToMature; i++) {
    f.advance(weatherFactor: 1.0);
  }
}

void main() {
  group('Soil fertility', () {
    test('starts at 1.0 on a fresh field', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      expect(f.fertility, 1.0);
    });

    test('drops by nutrientDemand after harvesting a heavy feeder', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      _growToHarvest(f, Crop.tomato); // demand 0.25
      f.harvest();
      expect(f.fertility, closeTo(0.75, 1e-9));
    });

    test('cannot drop below 0', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      // Drain repeatedly with rotated families so streak does not
      // amplify; just demonstrate the floor.
      for (var i = 0; i < 8; i++) {
        _growToHarvest(f, Crop.tomato);
        f.harvest();
        // Plant something else next turn to reset streak.
        if (i.isEven) {
          _growToHarvest(f, Crop.carrot);
          f.harvest();
        }
      }
      expect(f.fertility, greaterThanOrEqualTo(0.0));
    });

    test('regenerates during fallow turns', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      _growToHarvest(f, Crop.tomato);
      f.harvest(); // fertility 0.75
      f.advance(weatherFactor: 0.5); // empty field — fallow recovery
      expect(f.fertility, greaterThan(0.75));
    });

    test('caps at 1.0 even after long fallow', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      for (var i = 0; i < 100; i++) {
        f.advance(weatherFactor: 0.5);
      }
      expect(f.fertility, 1.0);
    });
  });

  group('Crop rotation', () {
    test('mono-culture drains fertility faster than rotation', () {
      final mono = Field(id: 'mono', size: 1.0, soil: SoilType.loam);
      final rot = Field(id: 'rot', size: 1.0, soil: SoilType.loam);

      // Three tomato cycles back-to-back vs alternating tomato/carrot.
      for (var i = 0; i < 3; i++) {
        _growToHarvest(mono, Crop.tomato);
        mono.harvest();
      }
      _growToHarvest(rot, Crop.tomato);
      rot.harvest();
      _growToHarvest(rot, Crop.carrot);
      rot.harvest();
      _growToHarvest(rot, Crop.tomato);
      rot.harvest();

      // Skip fallow regeneration by chaining harvests immediately —
      // both fields had the same number of advances so the only
      // difference is the streak multiplier.
      expect(mono.fertility, lessThan(rot.fertility));
    });

    test('streak resets after planting a different family', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      _growToHarvest(f, Crop.tomato);
      f.harvest();
      _growToHarvest(f, Crop.tomato); // streak 1
      expect(f.consecutiveSameFamily, 1);
      f.harvest();
      _growToHarvest(f, Crop.carrot); // rotation: streak 0
      expect(f.consecutiveSameFamily, 0);
    });

    test('CropFamily.other never accumulates a streak', () {
      // Crops without a declared family (default `other`) should not
      // trigger mono-culture penalties — keeps backwards compat for
      // hosts that have not migrated their catalog yet.
      const generic = Crop(
        id: 'generic',
        displayName: 'Generic',
        turnsToMature: 2,
        preferredSoils: {SoilType.loam},
        basePrice: 5.0,
      );
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      _growToHarvest(f, generic);
      f.harvest();
      _growToHarvest(f, generic);
      expect(f.consecutiveSameFamily, 0);
    });
  });

  group('Nitrogen fixers', () {
    test('legume cover restores fertility instead of draining', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      _growToHarvest(f, Crop.tomato);
      f.harvest();
      _growToHarvest(f, Crop.tomato);
      f.harvest();
      final degraded = f.fertility;
      _growToHarvest(f, Crop.legumeCover);
      f.harvest();
      expect(f.fertility, greaterThan(degraded));
    });

    test('legume cover breaks the same-family streak', () {
      final f = Field(id: 'a', size: 1.0, soil: SoilType.loam);
      _growToHarvest(f, Crop.tomato);
      f.harvest();
      _growToHarvest(f, Crop.tomato);
      f.harvest();
      _growToHarvest(f, Crop.legumeCover);
      f.harvest();
      // After harvesting the cover crop the field's reset state means
      // the next planting starts a fresh streak.
      _growToHarvest(f, Crop.tomato);
      expect(f.consecutiveSameFamily, 0);
    });
  });

  group('Quality with depleted fertility', () {
    test('depleted field grows lower-quality crops than virgin field', () {
      final virgin = Field(id: 'v', size: 1.0, soil: SoilType.loam);
      final tired = Field(id: 't', size: 1.0, soil: SoilType.loam);
      // Drain `tired` aggressively.
      for (var i = 0; i < 4; i++) {
        _growToHarvest(tired, Crop.tomato);
        tired.harvest();
      }
      // Same crop, perfect weather, fresh planting on each.
      _growToHarvest(virgin, Crop.tomato);
      _growToHarvest(tired, Crop.tomato);
      expect(tired.quality, lessThan(virgin.quality));
    });
  });

  group('Serialization v2', () {
    test('round-trip preserves fertility, family and streak', () {
      final farm = Farm(
        fields: [Field(id: 'a', size: 1.0, soil: SoilType.loam)],
        weather: const MockWeatherProvider.seasonal(),
      );
      _growToHarvest(farm.field('a'), Crop.tomato);
      farm.harvest('a');
      _growToHarvest(farm.field('a'), Crop.tomato); // streak 1
      farm.harvest('a');

      final snapshot = Serialization.farmToMap(farm);

      final restored = Farm(
        fields: [Field(id: 'a', size: 1.0, soil: SoilType.loam)],
        weather: const MockWeatherProvider.seasonal(),
      );
      Serialization.applyFarmFromMap(restored, snapshot);

      expect(restored.field('a').fertility,
          closeTo(farm.field('a').fertility, 1e-9));
      expect(restored.field('a').lastHarvestedFamily,
          farm.field('a').lastHarvestedFamily);
      // Streak is preserved at the moment the snapshot was taken: the
      // last action on the source farm was a harvest, so the streak
      // counter recorded on disk reflects that state.
      expect(restored.field('a').consecutiveSameFamily,
          farm.field('a').consecutiveSameFamily);
    });

    test('migrates schema v1 saves with sensible defaults', () {
      final farm = Farm(
        fields: [Field(id: 'a', size: 1.0, soil: SoilType.loam)],
        weather: const MockWeatherProvider.seasonal(),
      );
      // Hand-craft a v1 payload — no fertility / family / streak.
      final v1 = {
        'schema': 1,
        'turn': 7,
        'fields': [
          {
            'id': 'a',
            'size': 1.0,
            'soil': 'loam',
            'cropId': 'tomato',
            'turnsGrown': 3,
            'quality': 0.6,
          }
        ],
      };
      Serialization.applyFarmFromMap(farm, v1);
      expect(farm.turn, 7);
      expect(farm.field('a').fertility, 1.0);
      expect(farm.field('a').lastHarvestedFamily, isNull);
      expect(farm.field('a').consecutiveSameFamily, 0);
    });
  });
}
