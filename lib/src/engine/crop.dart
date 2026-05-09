import 'crop_family.dart';
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

  /// Botanical family. Drives crop-rotation mechanics. Defaults to
  /// `CropFamily.other` so hosts that do not classify their crops
  /// keep the pre-rotation behaviour (no mono-culture penalty).
  final CropFamily family;

  /// Relative draw on soil fertility per harvest, in `[0, 1]`. A
  /// value of `0.0` is a non-feeder (cover crop), `1.0` is the
  /// hungriest commercial crop in the host catalog. The engine uses
  /// this to deduct fertility from the field on harvest.
  ///
  /// Default `0.1` keeps the engine forgiving for hosts that do not
  /// tune the value — the field still degrades but slowly.
  final double nutrientDemand;

  /// If `true`, harvesting this crop *adds* fertility to the field
  /// instead of removing it (modelling nitrogen-fixing cover crops
  /// like beans, lentils, alfalfa). The amount added is governed by
  /// `nutrientDemand` interpreted in reverse — a higher demand value
  /// means a larger regeneration boost.
  ///
  /// Crops with `fixesNitrogen: true` and `family: CropFamily.legume`
  /// are the canonical use case, but the kit does not enforce it —
  /// host apps can flag any crop as a soil restorer.
  final bool fixesNitrogen;

  const Crop({
    required this.id,
    required this.displayName,
    required this.turnsToMature,
    required this.preferredSoils,
    required this.basePrice,
    this.family = CropFamily.other,
    this.nutrientDemand = 0.1,
    this.fixesNitrogen = false,
  });

  /// Wheat-like archetype. Fast cycle, hardy, low margin.
  static const Crop wheat = Crop(
    id: 'wheat',
    displayName: 'Wheat',
    turnsToMature: 3,
    preferredSoils: {SoilType.loam, SoilType.sandy},
    basePrice: 10.0,
    family: CropFamily.grass,
    nutrientDemand: 0.15,
  );

  /// Tomato-like archetype. Medium cycle, water-thirsty, higher margin.
  static const Crop tomato = Crop(
    id: 'tomato',
    displayName: 'Tomato',
    turnsToMature: 5,
    preferredSoils: {SoilType.loam, SoilType.clay},
    basePrice: 18.0,
    family: CropFamily.nightshade,
    nutrientDemand: 0.25,
  );

  /// Root-vegetable archetype. Slow but resilient, medium margin.
  static const Crop carrot = Crop(
    id: 'carrot',
    displayName: 'Carrot',
    turnsToMature: 6,
    preferredSoils: {SoilType.sandy, SoilType.loam},
    basePrice: 12.0,
    family: CropFamily.root,
    nutrientDemand: 0.12,
  );

  /// Leafy archetype. Fast cycle, fragile, low margin.
  static const Crop lettuce = Crop(
    id: 'lettuce',
    displayName: 'Lettuce',
    turnsToMature: 2,
    preferredSoils: {SoilType.loam},
    basePrice: 8.0,
    family: CropFamily.leafy,
    nutrientDemand: 0.08,
  );

  /// Generic legume cover crop. Restores soil fertility instead of
  /// drawing from it. Modelled on beans / clover. Short cycle, low
  /// commercial value but strategic value as a rotation between
  /// heavy feeders.
  static const Crop legumeCover = Crop(
    id: 'legume_cover',
    displayName: 'Legume cover',
    turnsToMature: 3,
    preferredSoils: {SoilType.loam, SoilType.sandy, SoilType.clay},
    basePrice: 6.0,
    family: CropFamily.legume,
    nutrientDemand: 0.3,
    fixesNitrogen: true,
  );

  /// Default library shipped with the kit. Consumers may extend or
  /// ignore it.
  static const List<Crop> defaultLibrary = [
    wheat,
    tomato,
    carrot,
    lettuce,
    legumeCover,
  ];

  @override
  bool operator ==(Object other) => other is Crop && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
