import 'dart:math';

import 'climate_preset.dart';
import 'weather_provider.dart';
import 'weekly_weather.dart';

/// Deterministic seasonal weather. Cycles through a 52-week year
/// driven by a `ClimatePreset` and adds a small pseudo-random jitter
/// seeded by the turn number so repeated calls with the same turn
/// produce the same output.
///
/// Useful for tests, demos, and any host that does not wire a real
/// meteorological API.
class MockWeatherProvider extends WeatherProvider {
  /// Seed for the jitter. Same seed + same turn = same weather.
  final int seed;

  /// Bundled climate parameters. Defaults to `ClimatePreset.temperate`.
  final ClimatePreset climate;

  const MockWeatherProvider({
    this.seed = 42,
    this.climate = ClimatePreset.temperate,
  });

  /// Convenience constructor for the most common case.
  const MockWeatherProvider.seasonal() : this();

  /// Convenience constructor for a specific bundled climate.
  /// Equivalent to `MockWeatherProvider(climate: preset)` but reads
  /// more naturally at the call site.
  const MockWeatherProvider.forClimate(ClimatePreset preset, {int seed = 42})
      : this(seed: seed, climate: preset);

  @override
  WeeklyWeather sample({required int turn}) {
    final base = climate.sample(turn);

    // Jitter: deterministic pseudo-random based on turn + seed.
    final jitter = Random(seed ^ turn);
    final tempJitter = (jitter.nextDouble() - 0.5) * 4.0;
    final precipJitter = (jitter.nextDouble() - 0.5) * 8.0;

    final actualTemp = base.tempC + tempJitter;
    final actualPrecip = (base.precipMm + precipJitter).clamp(0.0, 200.0);

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
    if (actualPrecip < 2) {
      factor *= 0.6;
    } else if (actualPrecip > 50) {
      factor *= 0.5;
    }

    final label = _label(actualTemp, actualPrecip);

    return WeeklyWeather(
      growthFactor: factor.clamp(0.0, 1.0),
      temperatureC: actualTemp,
      precipitationMm: actualPrecip,
      label: label,
      pestRisk: _pestRisk(actualTemp, actualPrecip),
    );
  }

  /// Mosquitos, hongos y plagas en general explotan con calor +
  /// humedad. Modelo simple: cada eje normalizado en [0, 1] y
  /// multiplicado. Días fríos o secos rinden cerca de 0; semanas
  /// 28°C+ con 30+ mm rinden cerca de 1.
  double _pestRisk(double temp, double precip) {
    final tempFactor = ((temp - 18) / 12).clamp(0.0, 1.0);
    final humidityFactor = (precip / 50).clamp(0.0, 1.0);
    return tempFactor * humidityFactor;
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
