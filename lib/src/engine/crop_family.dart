/// Botanical family of a crop. Used by the engine for crop-rotation
/// mechanics: planting two crops of the same family back-to-back on
/// the same field accelerates soil exhaustion, while alternating
/// families lets the soil recover. Legumes that fix nitrogen are
/// flagged separately on `Crop.fixesNitrogen` rather than as a family,
/// because some grasses (clover-like covers) also regenerate soil.
///
/// The taxonomy is intentionally pragmatic — coarse enough that host
/// apps without a botanist on staff can still classify their products,
/// fine enough to drive interesting strategic decisions.
enum CropFamily {
  /// Solanaceae — tomato, pepper, eggplant, potato. Heavy feeders.
  nightshade,

  /// Brassicaceae — cabbage, broccoli, kale, radish. Heavy feeders.
  brassica,

  /// Fabaceae — beans, peas, lentils, alfalfa. Light feeders, often
  /// nitrogen-fixing.
  legume,

  /// Apiaceae and other root vegetables — carrot, cassava, sweet
  /// potato, beetroot. Medium feeders, loosen the soil.
  root,

  /// Leafy greens — lettuce, chard, spinach. Light feeders.
  leafy,

  /// Cereals — wheat, maize, rice, oats. Medium-to-heavy feeders.
  grass,

  /// Anything that does not fit the categories above. Treated as a
  /// neutral family — never matches itself for rotation penalties,
  /// so a host app that does not classify its crops gets the old
  /// pre-rotation behaviour by default.
  other,
}
