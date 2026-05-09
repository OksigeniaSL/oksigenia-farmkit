/// Discrete phases a planted crop progresses through. The engine
/// advances a planted field through these stages turn by turn,
/// modulated by soil and weather. The state machine is intentionally
/// linear — no branches, no regression — to keep the gameplay
/// predictable for younger players.
enum GrowthStage {
  /// No crop planted on the field.
  empty,

  /// Just sown. Vulnerable to extreme weather. One-turn minimum.
  seedling,

  /// Actively growing. Most turns spent here. Quality accrues based
  /// on the weather sequence experienced in this stage.
  growing,

  /// Fully grown and harvestable. Stays at this stage until harvested
  /// or the season changes; rotting is handled by the consumer if
  /// they want that complexity.
  ready,
}
