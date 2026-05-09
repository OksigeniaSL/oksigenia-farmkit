import 'package:flutter_test/flutter_test.dart';
import 'package:oksigenia_farmkit/oksigenia_farmkit.dart';

void main() {
  group('ClimatePreset.sample', () {
    test('temperate baseline matches the documented average', () {
      // Sampling the full year and averaging should round to the
      // baseline. This locks in the convention so consumers can
      // reason about the curve without reading the code.
      double sum = 0;
      for (var t = 0; t < 52; t++) {
        sum += ClimatePreset.temperate.sample(t).tempC;
      }
      final mean = sum / 52;
      expect(mean, closeTo(ClimatePreset.temperate.baselineTempC, 0.5));
    });

    test('tropical preset has lower seasonal swing than temperate', () {
      final tropicalRange = _seasonalRange(ClimatePreset.tropical);
      final temperateRange = _seasonalRange(ClimatePreset.temperate);
      expect(tropicalRange, lessThan(temperateRange));
    });

    test('continental preset swings harder than temperate', () {
      expect(_seasonalRange(ClimatePreset.continental),
          greaterThan(_seasonalRange(ClimatePreset.temperate)));
    });

    test('southern-cone preset peaks in southern summer (week ~39)', () {
      // Find the warmest week of the year for the preset.
      int hottestWeek = 0;
      double hottestTemp = double.negativeInfinity;
      for (var t = 0; t < 52; t++) {
        final s = ClimatePreset.subtropicalSouthernCone.sample(t);
        if (s.tempC > hottestTemp) {
          hottestTemp = s.tempC;
          hottestWeek = t;
        }
      }
      // With phaseOffsetWeeks=26, the temperature peak lands at
      // (52 - 26 + 13) % 52 = 39, give or take a week.
      expect(hottestWeek, inInclusiveRange(36, 42));
    });

    test('precipitation never goes negative', () {
      for (final preset in ClimatePreset.bundled) {
        for (var t = 0; t < 52; t++) {
          expect(preset.sample(t).precipMm, greaterThanOrEqualTo(0));
        }
      }
    });
  });

  group('MockWeatherProvider with bundled presets', () {
    test('forClimate constructor selects the requested preset', () {
      const tropicalProv =
          MockWeatherProvider.forClimate(ClimatePreset.tropical);
      const temperateProv =
          MockWeatherProvider.forClimate(ClimatePreset.temperate);
      double tropicalAvg = 0;
      double temperateAvg = 0;
      for (var t = 0; t < 52; t++) {
        tropicalAvg += tropicalProv.sample(turn: t).temperatureC;
        temperateAvg += temperateProv.sample(turn: t).temperatureC;
      }
      tropicalAvg /= 52;
      temperateAvg /= 52;
      expect(tropicalAvg, greaterThan(temperateAvg));
    });

    test('growth factor stays in [0, 1] for every bundled preset', () {
      for (final preset in ClimatePreset.bundled) {
        final prov = MockWeatherProvider.forClimate(preset);
        for (var t = 0; t < 200; t++) {
          final w = prov.sample(turn: t);
          expect(w.growthFactor, inInclusiveRange(0.0, 1.0),
              reason: 'preset ${preset.name} turn $t');
        }
      }
    });

    test('determinism is preserved per preset + seed', () {
      const a = MockWeatherProvider.forClimate(ClimatePreset.tropical);
      const b = MockWeatherProvider.forClimate(ClimatePreset.tropical);
      for (var t = 0; t < 20; t++) {
        expect(a.sample(turn: t).temperatureC,
            b.sample(turn: t).temperatureC);
      }
    });
  });
}

double _seasonalRange(ClimatePreset preset) {
  double minT = double.infinity;
  double maxT = double.negativeInfinity;
  for (var t = 0; t < 52; t++) {
    final s = preset.sample(t);
    if (s.tempC < minT) minT = s.tempC;
    if (s.tempC > maxT) maxT = s.tempC;
  }
  return maxT - minT;
}
