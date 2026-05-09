import 'crop.dart';
import 'growth_stage.dart';
import 'soil.dart';

/// A parcel of land. Holds at most one planted crop at a time.
/// Field instances are mutable so the engine can advance their
/// internal state without reallocating; consumers that want
/// immutability should snapshot via `toJson()`.
class Field {
  /// Stable identifier within a single `Farm`. Lowercase recommended.
  final String id;

  /// Relative size in abstract units. Scales the harvest yield.
  /// A field of size `2.0` produces twice the yield of size `1.0`
  /// for the same crop and conditions.
  final double size;

  /// Soil type. Immutable after construction; if the host app wants
  /// soil improvement mechanics, it should swap fields in and out
  /// rather than mutate this property.
  final SoilType soil;

  /// Currently planted crop, or `null` if the field is empty.
  Crop? _crop;

  /// Turns elapsed since planting. Reset to `0` on plant or harvest.
  int _turnsGrown = 0;

  /// Accumulated quality 0..1 derived from weather exposure during
  /// the growing stage. Filled by the engine as turns advance.
  double _quality = 0.0;

  /// Public read-only view of the planted crop.
  Crop? get crop => _crop;

  /// Public read-only view of how many turns the current crop has been growing.
  int get turnsGrown => _turnsGrown;

  /// Public read-only view of accumulated quality (0.0 worst, 1.0 best).
  double get quality => _quality;

  /// Derived growth stage. Pure function of `_crop` and `_turnsGrown`.
  GrowthStage get growthStage {
    final c = _crop;
    if (c == null) return GrowthStage.empty;
    if (_turnsGrown < 1) return GrowthStage.seedling;
    if (_turnsGrown < c.turnsToMature) return GrowthStage.growing;
    return GrowthStage.ready;
  }

  Field({required this.id, required this.size, required this.soil});

  /// Plant a crop. Throws `StateError` if the field is not empty —
  /// callers should `harvest()` first.
  void plant(Crop crop) {
    if (_crop != null) {
      throw StateError(
        'Field "$id" already has a crop ($_crop). Harvest before planting.',
      );
    }
    _crop = crop;
    _turnsGrown = 0;
    _quality = 0.0;
  }

  /// Harvest the field. Returns the yield amount (size * quality)
  /// or `0.0` if there was no crop ready. The field is reset.
  double harvest() {
    if (growthStage != GrowthStage.ready) return 0.0;
    final yieldAmount = size * _quality;
    _crop = null;
    _turnsGrown = 0;
    _quality = 0.0;
    return yieldAmount;
  }

  /// Advance one turn. Consumed by the engine's turn loop. The
  /// `weatherFactor` is a 0..1 multiplier supplied by `WeatherProvider`
  /// representing how favourable this week was for the crop.
  ///
  /// The accumulated quality is the average weather factor across the
  /// growing stage, weighted by the soil multiplier. This formula is
  /// deliberately simple — host apps that want richer agronomy should
  /// extend `Field` rather than overloading the kit.
  void advance({required double weatherFactor}) {
    final c = _crop;
    if (c == null) return;
    _turnsGrown += 1;
    if (growthStage == GrowthStage.growing || growthStage == GrowthStage.ready) {
      // Running average over the turns spent in active growth.
      final soilMul = soilGrowthMultiplier[soil] ?? 1.0;
      final preferredBonus = c.preferredSoils.contains(soil) ? 1.05 : 0.9;
      final contribution = weatherFactor * soilMul * preferredBonus;
      // Clamp to [0, 1] before averaging so bonus does not break invariant.
      final clamped = contribution.clamp(0.0, 1.0);
      final n = _turnsGrown.clamp(1, 100);
      _quality = ((_quality * (n - 1)) + clamped) / n;
    }
  }

  /// Internal hook for `Serialization` to rehydrate a field without
  /// going through `plant()`. Not exported in the public barrel.
  void hydrateFromMap({Crop? crop, int turnsGrown = 0, double quality = 0.0}) {
    _crop = crop;
    _turnsGrown = turnsGrown;
    _quality = quality;
  }
}
