import 'dart:math';

import 'weather_provider.dart';
import 'weekly_weather.dart';

/// Deterministic seasonal weather. Cycles through summer / autumn /
/// winter / spring with a 52-week period and adds a small pseudo-
/// random jitter seeded by the turn number so repeated calls with
/// the same turn produce the same output.
///
/// Useful for tests, demos, and any host that does not wire a real
/// meteorological API.
class MockWeatherProvider extends WeatherProvider {
  /// Seed for the jitter. Same seed + same turn = same weather.
  final int seed;

  /// Base average temperature for the year, Celsius. Default `20`.
  final double baselineTempC;

  /// Peak-to-peak temperature swing through the seasonal cycle.
  /// Default `15` (so temperatures range roughly `12.5..27.5`).
  final double seasonalTempSwing;

  const MockWeatherProvider({
    this.seed = 42,
    this.baselineTempC = 20.0,
    this.seasonalTempSwing = 15.0,
  });

  /// Convenience constructor for the most common case.
  const MockWeatherProvider.seasonal() : this();

  @override
  WeeklyWeather sample({required int turn}) {
    // Seasonal sine: 52 weeks per year. Phase offset puts week 0 at
    // the start of summer in the southern hemisphere context the
    // kit was bootstrapped from, but the result is symmetric around
    // the baseline so consumers in any hemisphere stay sensible.
    final phase = (2 * pi * (turn % 52)) / 52;
    final seasonal = sin(phase);
    final temp = baselineTempC + (seasonalTempSwing / 2) * seasonal;

    // Jitter: deterministic pseudo-random based on turn + seed.
    final jitter = Random(seed ^ turn);
    final tempJitter = (jitter.nextDouble() - 0.5) * 4.0;
    final precipMm = jitter.nextDouble() * 30.0;

    final actualTemp = temp + tempJitter;

    // Growth factor: penalize extreme temperatures (<5° or >35°)
    // and very dry weeks (<2 mm) or extremely wet weeks (>50 mm).
    var factor = 1.0;
    if (actualTemp < 5) {
      factor *= 0.4;
    } else if (actualTemp < 10) {
      factor *= 0.7;
    } else if (actualTemp > 35) {
      factor *= 0.4;
    } else if (actualTemp > 30) {
      factor *= 0.7;
    }
    if (precipMm < 2) {
      factor *= 0.6;
    } else if (precipMm > 50) {
      factor *= 0.5;
    }

    final label = _label(actualTemp, precipMm);

    return WeeklyWeather(
      growthFactor: factor.clamp(0.0, 1.0),
      temperatureC: actualTemp,
      precipitationMm: precipMm,
      label: label,
    );
  }

  String _label(double temp, double precip) {
    final hot = temp > 28;
    final cold = temp < 10;
    final wet = precip > 25;
    final dry = precip < 5;
    if (hot && wet) return 'hot and rainy';
    if (hot && dry) return 'hot and dry';
    if (cold && wet) return 'cold and rainy';
    if (cold && dry) return 'cold and dry';
    if (wet) return 'wet';
    if (dry) return 'dry';
    return 'mild';
  }
}
