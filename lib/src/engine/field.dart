import 'crop.dart';
import 'crop_family.dart';
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

  /// Soil fertility, in `[0, 1]`. Starts at `1.0` (virgin land) and
  /// degrades as crops are harvested. Recovers slowly during fallow
  /// turns and jumps when a nitrogen-fixing crop is harvested.
  ///
  /// Multiplies the effective weather factor on `advance` so a
  /// depleted field grows lower-quality crops even under perfect
  /// weather. Floor never hits `0` — the lowest practical value
  /// passes a minimum of `0.3` to keep the game playable.
  double _fertility = 1.0;

  /// Family of the most recently harvested crop on this field, or
  /// `null` if nothing has ever been harvested. Used to detect
  /// mono-culture: replanting the same family in a row degrades
  /// fertility faster than rotating between families.
  CropFamily? _lastHarvestedFamily;

  /// How many planted crops in a row have shared `_lastHarvestedFamily`.
  /// `0` after a rotation, `1` for two-in-a-row of the same family,
  /// and so on. Higher values multiply harvest-time degradation.
  int _consecutiveSameFamily = 0;

  /// Public read-only view of the planted crop.
  Crop? get crop => _crop;

  /// Public read-only view of how many turns the current crop has been growing.
  int get turnsGrown => _turnsGrown;

  /// Public read-only view of accumulated quality (0.0 worst, 1.0 best).
  double get quality => _quality;

  /// Public read-only view of soil fertility (0.0 dust, 1.0 virgin).
  double get fertility => _fertility;

  /// Family of the last harvested crop, or `null` if never harvested.
  CropFamily? get lastHarvestedFamily => _lastHarvestedFamily;

  /// How many same-family plantings have stacked on this field.
  /// Reset on rotation or on harvesting a nitrogen-fixing crop.
  int get consecutiveSameFamily => _consecutiveSameFamily;

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
  ///
  /// Records whether the new crop's family matches the previously
  /// harvested one so harvest-time degradation can scale with the
  /// length of a mono-culture streak.
  void plant(Crop crop) {
    if (_crop != null) {
      throw StateError(
        'Field "$id" already has a crop ($_crop). Harvest before planting.',
      );
    }
    if (_lastHarvestedFamily == null ||
        crop.family == CropFamily.other ||
        _lastHarvestedFamily != crop.family) {
      // Rotation (or unclassified crop / first planting): reset streak.
      _consecutiveSameFamily = 0;
    } else {
      // Same family back-to-back: extend the streak.
      _consecutiveSameFamily += 1;
    }
    _crop = crop;
    _turnsGrown = 0;
    _quality = 0.0;
  }

  /// Harvest the field. Returns the yield amount (size * quality)
  /// or `0.0` if there was no crop ready. The field is reset.
  ///
  /// Side effects:
  /// - Records the harvested crop's family on the field, so the next
  ///   planting can detect rotation vs mono-culture.
  /// - Adjusts fertility:
  ///   - Nitrogen-fixing crops add fertility (capped at `1.0`).
  ///   - Other crops subtract `nutrientDemand`, scaled up by the
  ///     mono-culture streak (each consecutive same-family planting
  ///     adds `0.5x` extra drain).
  double harvest() {
    if (growthStage != GrowthStage.ready) return 0.0;
    final c = _crop!;
    final yieldAmount = size * _quality;
    // Fertility update.
    if (c.fixesNitrogen) {
      // Treat nutrientDemand as the regeneration magnitude.
      final boost = c.nutrientDemand * 0.5;
      _fertility = (_fertility + boost).clamp(0.0, 1.0);
      // A successful cover-crop harvest also breaks the streak.
      _consecutiveSameFamily = 0;
    } else {
      final streakMul = 1.0 + 0.5 * _consecutiveSameFamily;
      final drain = c.nutrientDemand * streakMul;
      _fertility = (_fertility - drain).clamp(0.0, 1.0);
    }
    _lastHarvestedFamily = c.family;
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
  /// growing stage, weighted by the soil multiplier and the field's
  /// current fertility. An empty field "rests" — it slowly recovers
  /// fertility per fallow turn.
  void advance({required double weatherFactor}) {
    final c = _crop;
    if (c == null) {
      // Fallow recovery: small steady gain. The engine still lets
      // the field tick forward so consumers can render an idle
      // animation or a "resting" badge.
      _fertility = (_fertility + 0.05).clamp(0.0, 1.0);
      return;
    }
    _turnsGrown += 1;
    if (growthStage == GrowthStage.growing || growthStage == GrowthStage.ready) {
      // Running average over the turns spent in active growth.
      final soilMul = soilGrowthMultiplier[soil] ?? 1.0;
      final preferredBonus = c.preferredSoils.contains(soil) ? 1.05 : 0.9;
      // Floor the fertility multiplier at 0.3 so a depleted field is
      // punishing but never literally unworkable — the player can
      // always plant a cover crop to recover.
      final fertilityMul = _fertility.clamp(0.3, 1.0);
      final contribution =
          weatherFactor * soilMul * preferredBonus * fertilityMul;
      // Clamp to [0, 1] before averaging so bonus does not break invariant.
      final clamped = contribution.clamp(0.0, 1.0);
      final n = _turnsGrown.clamp(1, 100);
      _quality = ((_quality * (n - 1)) + clamped) / n;
    }
  }

  /// Internal hook for `Serialization` to rehydrate a field without
  /// going through `plant()`. Not exported in the public barrel.
  void hydrateFromMap({
    Crop? crop,
    int turnsGrown = 0,
    double quality = 0.0,
    double fertility = 1.0,
    CropFamily? lastHarvestedFamily,
    int consecutiveSameFamily = 0,
  }) {
    _crop = crop;
    _turnsGrown = turnsGrown;
    _quality = quality;
    _fertility = fertility;
    _lastHarvestedFamily = lastHarvestedFamily;
    _consecutiveSameFamily = consecutiveSameFamily;
  }
}
