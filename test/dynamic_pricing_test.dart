import 'package:flutter_test/flutter_test.dart';
import 'package:oksigenia_farmkit/oksigenia_farmkit.dart';

void main() {
  group('seasonForTurn', () {
    test('northern hemisphere starts in summer at turn 0', () {
      expect(seasonForTurn(0), Season.summer);
      expect(seasonForTurn(13), Season.autumn);
      expect(seasonForTurn(26), Season.winter);
      expect(seasonForTurn(39), Season.spring);
    });

    test('cycles back to summer after a full year', () {
      expect(seasonForTurn(52), Season.summer);
      // 65 = 52 + 13, así que coincide con seasonForTurn(13) = autumn.
      expect(seasonForTurn(65), Season.autumn);
    });

    test('southern hemisphere is shifted 6 months from northern', () {
      expect(seasonForTurn(0, southernHemisphere: true), Season.winter);
      expect(seasonForTurn(13, southernHemisphere: true), Season.spring);
      expect(seasonForTurn(26, southernHemisphere: true), Season.summer);
      expect(seasonForTurn(39, southernHemisphere: true), Season.autumn);
    });
  });

  group('SeasonalDynamicPricing — seasonal modulation', () {
    const econ = SeasonalDynamicPricing();

    test('off-season tomato pays more than peak summer', () {
      // Tomato (nightshade) peaks in winter (off-season) per default curve.
      final summerPrice = econ.dynamicPrice(
        Crop.tomato,
        quality: 0.7,
        turn: 0, // summer NH
      );
      final winterPrice = econ.dynamicPrice(
        Crop.tomato,
        quality: 0.7,
        turn: 26, // winter NH
      );
      expect(winterPrice, greaterThan(summerPrice));
    });

    test('lettuce peaks in summer (heat stress, scarcity premium)', () {
      final summerLettuce = econ.dynamicPrice(
        Crop.lettuce,
        quality: 0.7,
        turn: 0,
      );
      final winterLettuce = econ.dynamicPrice(
        Crop.lettuce,
        quality: 0.7,
        turn: 26,
      );
      expect(summerLettuce, greaterThan(winterLettuce));
    });

    test('falls back to base price when family lacks a seasonal curve', () {
      const generic = Crop(
        id: 'mystery',
        displayName: 'Mystery',
        turnsToMature: 3,
        preferredSoils: {SoilType.loam},
        basePrice: 10.0,
      );
      // CropFamily.other has a curve of 1.0 across all seasons.
      final p1 = econ.dynamicPrice(generic, quality: 0.5, turn: 0);
      final p2 = econ.dynamicPrice(generic, quality: 0.5, turn: 26);
      expect(p1, closeTo(p2, 1e-9));
    });
  });

  group('SeasonalDynamicPricing — weather shock', () {
    const econ = SeasonalDynamicPricing();
    const summerWeather = WeeklyWeather(
      growthFactor: 1.0,
      temperatureC: 26,
      precipitationMm: 15, // moderate
      label: 'mild',
    );
    const drought = WeeklyWeather(
      growthFactor: 0.6,
      temperatureC: 30,
      precipitationMm: 0.5,
      label: 'dry',
    );
    const flood = WeeklyWeather(
      growthFactor: 0.5,
      temperatureC: 22,
      precipitationMm: 80,
      label: 'wet',
    );

    test('drought week multiplies price by droughtShock', () {
      final base = econ.dynamicPrice(
        Crop.tomato,
        quality: 0.7,
        turn: 0,
        currentWeather: summerWeather,
      );
      final shocked = econ.dynamicPrice(
        Crop.tomato,
        quality: 0.7,
        turn: 0,
        currentWeather: drought,
      );
      expect(shocked / base, closeTo(econ.droughtShock, 1e-9));
    });

    test('flood week multiplies price by floodShock', () {
      final base = econ.dynamicPrice(
        Crop.tomato,
        quality: 0.7,
        turn: 0,
        currentWeather: summerWeather,
      );
      final shocked = econ.dynamicPrice(
        Crop.tomato,
        quality: 0.7,
        turn: 0,
        currentWeather: flood,
      );
      expect(shocked / base, closeTo(econ.floodShock, 1e-9));
    });

    test('moderate weather leaves the price unchanged from non-weather call', () {
      final withWeather = econ.dynamicPrice(
        Crop.tomato,
        quality: 0.7,
        turn: 0,
        currentWeather: summerWeather,
      );
      final withoutWeather = econ.dynamicPrice(
        Crop.tomato,
        quality: 0.7,
        turn: 0,
      );
      expect(withWeather, closeTo(withoutWeather, 1e-9));
    });
  });

  group('Backwards compatibility', () {
    test('expectedPrice ignores turn and weather (legacy contract)', () {
      const econ = SeasonalDynamicPricing();
      // Same crop and quality at any turn returns the same price via
      // the inherited expectedPrice — this is the contract that lets
      // host apps adopt the class without rewiring.
      final a = econ.expectedPrice(Crop.tomato, quality: 0.5);
      final b = econ.expectedPrice(Crop.tomato, quality: 0.5);
      expect(a, closeTo(b, 1e-9));
      // And it equals what plain LinearQualityPricing would give.
      const legacy = LinearQualityPricing();
      expect(a, closeTo(legacy.expectedPrice(Crop.tomato, quality: 0.5), 1e-9));
    });
  });

  group('seasonalTrend helper', () {
    test('returns the multiplier the price will use', () {
      const econ = SeasonalDynamicPricing();
      final trend = econ.seasonalTrend(Crop.tomato, turn: 26);
      // Tomato in winter NH is the peak per default curve.
      expect(trend, greaterThan(1.0));
    });
  });
}
