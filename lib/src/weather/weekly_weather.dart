/// Weather sample for one in-game week. The engine consumes only
/// `growthFactor`; the auxiliary fields exist so host apps can render
/// richer UI without re-deriving the same numbers.
class WeeklyWeather {
  /// 0.0 (catastrophic) to 1.0 (ideal). Multiplied into the field's
  /// quality on each advance. The engine uses only this value for
  /// gameplay logic.
  final double growthFactor;

  /// Average air temperature in Celsius. Display-only.
  final double temperatureC;

  /// Cumulative precipitation for the week, millimetres. Display-only.
  final double precipitationMm;

  /// Free-form label for UI ("warm sunny week", "cold and rainy").
  /// Localized strings are the host app's responsibility.
  final String label;

  const WeeklyWeather({
    required this.growthFactor,
    required this.temperatureC,
    required this.precipitationMm,
    required this.label,
  });
}
