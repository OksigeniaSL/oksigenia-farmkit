import 'soil.dart';

/// A crop archetype: data-only description of how a plant grows in
/// the simulation. Host apps map their real-world products onto
/// these archetypes — for example a tomato in the host catalog reuses
/// the `Crop.tomato` definition.
///
/// The kit ships with a small built-in library of generic archetypes;
/// consumers add their own with the `Crop` constructor and a unique
/// `id`. Two crops with the same id are considered equal.
class Crop {
  /// Stable identifier across saves. Lowercase snake_case recommended.
  final String id;

  /// Human-readable label. Display only, never used for logic.
  final String displayName;

  /// Number of turns from sowing to harvest under ideal conditions
  /// (loam soil, no weather penalties). Real growth in the
  /// simulation is `turnsToMature * weather * soil` factors.
  final int turnsToMature;

  /// Soil types where this crop thrives. Plantings outside this set
  /// still grow but accumulate slower and yield lower quality.
  final Set<SoilType> preferredSoils;

  /// Base sell price in abstract currency units. The host app maps
  /// this to its own monetary system. The economy layer multiplies
  /// it by quality before returning the actual sell price.
  final double basePrice;

  const Crop({
    required this.id,
    required this.displayName,
    required this.turnsToMature,
    required this.preferredSoils,
    required this.basePrice,
  });

  /// Wheat-like archetype. Fast cycle, hardy, low margin.
  static const Crop wheat = Crop(
    id: 'wheat',
    displayName: 'Wheat',
    turnsToMature: 3,
    preferredSoils: {SoilType.loam, SoilType.sandy},
    basePrice: 10.0,
  );

  /// Tomato-like archetype. Medium cycle, water-thirsty, higher margin.
  static const Crop tomato = Crop(
    id: 'tomato',
    displayName: 'Tomato',
    turnsToMature: 5,
    preferredSoils: {SoilType.loam, SoilType.clay},
    basePrice: 18.0,
  );

  /// Root-vegetable archetype. Slow but resilient, medium margin.
  static const Crop carrot = Crop(
    id: 'carrot',
    displayName: 'Carrot',
    turnsToMature: 6,
    preferredSoils: {SoilType.sandy, SoilType.loam},
    basePrice: 12.0,
  );

  /// Leafy archetype. Fast cycle, fragile, low margin.
  static const Crop lettuce = Crop(
    id: 'lettuce',
    displayName: 'Lettuce',
    turnsToMature: 2,
    preferredSoils: {SoilType.loam},
    basePrice: 8.0,
  );

  /// Default library shipped with the kit. Consumers may extend or
  /// ignore it.
  static const List<Crop> defaultLibrary = [wheat, tomato, carrot, lettuce];

  @override
  bool operator ==(Object other) => other is Crop && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
