/// Soil categories the engine understands.
///
/// The taxonomy is intentionally coarse — three families that map to
/// real agronomic behaviour without forcing the host app to model
/// pH, nutrients or porosity individually. Each soil applies a
/// multiplier to the base growth rate of any crop planted on it.
enum SoilType {
  /// Mixed soil. The neutral baseline. Multiplier `1.0`.
  loam,

  /// Sandy soil. Drains fast, warms early, suits root crops; weaker
  /// for water-thirsty leafy crops. Multiplier `0.85`.
  sandy,

  /// Clay soil. Holds water, slow to warm, rewards patience and
  /// careful crop choice. Multiplier `0.9` but pairs with a lower
  /// drought penalty (handled in `WeatherProvider`).
  clay,
}

/// Growth-rate multiplier for a soil. Pure data — no business logic
/// hidden in here so consumers can override or replace the table.
const Map<SoilType, double> soilGrowthMultiplier = {
  SoilType.loam: 1.0,
  SoilType.sandy: 0.85,
  SoilType.clay: 0.9,
};
