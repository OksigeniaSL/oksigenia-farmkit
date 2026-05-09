import 'weekly_weather.dart';

/// Strategy interface for the weather subsystem. Implementations
/// produce one `WeeklyWeather` per turn. They may be deterministic
/// (mock provider) or pull from a live meteorological API on the
/// host side.
abstract class WeatherProvider {
  /// Generate the weather for the requested turn. Implementations
  /// must be pure with respect to the turn number — i.e. calling
  /// `sample(turn: 5)` twice should return equivalent data — so
  /// save / load preserves a coherent simulation history.
  WeeklyWeather sample({required int turn});

  /// Required so const subclasses keep `const` capability.
  const WeatherProvider();
}
