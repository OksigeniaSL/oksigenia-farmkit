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

  /// Likelihood of pest / disease outbreak during this week, in
  /// `[0, 1]`. Hot and humid weeks push it up; dry and cool weeks
  /// keep it low. Defaults to `0.0` so weather providers that pre-date
  /// the pest subsystem (or hosts that disable it) cause no pest
  /// pressure on fields. Combined with `Crop.pestSusceptibility`
  /// at the field level to drive `pestPressure` accumulation.
  final double pestRisk;

  const WeeklyWeather({
    required this.growthFactor,
    required this.temperatureC,
    required this.precipitationMm,
    required this.label,
    this.pestRisk = 0.0,
  });
}
