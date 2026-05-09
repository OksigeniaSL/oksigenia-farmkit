import '../economy/pricing.dart';
import '../weather/weather_provider.dart';
import 'crop.dart';
import 'crop_family.dart';
import 'farm_event.dart';
import 'field.dart';

/// Top-level facade. Host apps interact with this class; the
/// individual subsystems are exposed as properties for advanced
/// callers that need direct access.
///
/// A `Farm` is mutable. The kit does not impose any concurrency
/// model; callers that need thread safety wrap operations on the
/// host side.
///
/// ## Events
///
/// The farm accumulates `FarmEvent` instances as actions happen
/// (turn advances, plantings, harvests). Hosts pull them with
/// `drainEvents()` after each call. The engine never decides how
/// events are presented; that's the host's responsibility.
class Farm {
  /// Fields managed by this farm. Order is stable after construction.
  final List<Field> fields;

  /// Weather data source consumed each turn.
  final WeatherProvider weather;

  /// Economy strategy. Defaults to `LinearQualityPricing`.
  final EconomyProvider economy;

  /// Total turns elapsed since the farm started. Increments on every
  /// successful `advanceTurn()` call.
  int _turn = 0;

  /// Public read-only view of the elapsed turn count.
  int get turn => _turn;

  /// Cumulative count of harvests across all fields. Drives
  /// `harvestMilestone` events.
  int _totalHarvests = 0;
  int get totalHarvests => _totalHarvests;

  /// Whether the farm has ever harvested a nitrogen-fixing crop.
  /// First-time event uses this flag.
  bool _firstNitrogenFixerSeen = false;

  /// Internal: tracks the longest running rotation streak per field
  /// so we can emit `rotationStreak` only when the streak grows.
  final Map<String, int> _rotationLength = {};

  /// Internal: tracks the most recently emitted fertility band per
  /// field, so warning / critical / restored events fire exactly
  /// once on transition instead of every turn.
  final Map<String, _FertilityBand> _lastFertilityBand = {};

  /// Internal: tracks the most recently emitted pest band per field,
  /// for the same single-fire reason as the fertility band.
  final Map<String, _PestBand> _lastPestBand = {};

  /// Buffered events. Hosts pull and clear with `drainEvents()`.
  final List<FarmEvent> _events = [];

  Farm({
    required this.fields,
    required this.weather,
    EconomyProvider? economy,
  }) : economy = economy ?? const LinearQualityPricing() {
    for (final f in fields) {
      _lastFertilityBand[f.id] = _bandOf(f.fertility);
      _lastPestBand[f.id] = _pestBandOf(f.pestPressure);
    }
  }

  /// Look up a field by id. Throws `StateError` if no such field
  /// exists — consumers expected to know which ids are present.
  Field field(String id) {
    return fields.firstWhere(
      (f) => f.id == id,
      orElse: () => throw StateError('No field with id "$id".'),
    );
  }

  /// Plant a crop on a specific field. Convenience method that
  /// delegates to `Field.plant`. Emits `monoCultureWarning` /
  /// `monoCultureCritical` if the same family piles up on the field.
  void plant({required String fieldId, required Crop crop}) {
    final f = field(fieldId);
    f.plant(crop);
    final streak = f.consecutiveSameFamily;
    if (streak == 1) {
      _events.add(FarmEvent(
        kind: FarmEventKind.monoCultureWarning,
        fieldId: fieldId,
        crop: crop,
        family: crop.family,
        metadata: {'streak': streak + 1},
      ));
    } else if (streak >= 2) {
      _events.add(FarmEvent(
        kind: FarmEventKind.monoCultureCritical,
        fieldId: fieldId,
        crop: crop,
        family: crop.family,
        metadata: {'streak': streak + 1},
      ));
    }

    // Detect rotation streaks: count fields where the planted crop
    // family differs from `lastHarvestedFamily`. Pure rotation
    // increments the per-field counter; mono-culture resets it.
    final lastFam = f.lastHarvestedFamily;
    if (lastFam != null && lastFam != crop.family && crop.family != CropFamily.other) {
      final newLen = (_rotationLength[fieldId] ?? 0) + 1;
      _rotationLength[fieldId] = newLen;
      if (newLen >= 3) {
        _events.add(FarmEvent(
          kind: FarmEventKind.rotationStreak,
          fieldId: fieldId,
          crop: crop,
          family: crop.family,
          metadata: {'length': newLen},
        ));
      }
    } else {
      _rotationLength[fieldId] = 0;
    }
  }

  /// Advance the simulation by one turn. Pulls a fresh weather
  /// sample and applies it uniformly to every planted field. Returns
  /// the weather factor used so callers can display it.
  ///
  /// After advancing, scans every field for fertility-band crossings
  /// and emits the corresponding events.
  double advanceTurn() {
    _turn += 1;
    final w = weather.sample(turn: _turn);
    for (final f in fields) {
      f.advance(weatherFactor: w.growthFactor, pestRisk: w.pestRisk);
      _checkFertilityBand(f);
      _checkPestBand(f);
    }
    return w.growthFactor;
  }

  /// Harvest a single field. See `Field.harvest`. Emits
  /// `perfectQuality`, `firstNitrogenFixerHarvested`, and
  /// `harvestMilestone` events as applicable.
  double harvest(String fieldId) {
    final f = field(fieldId);
    final crop = f.crop;
    final qualityBefore = f.quality;
    final yieldAmount = f.harvest();
    if (yieldAmount <= 0 || crop == null) return yieldAmount;

    _totalHarvests += 1;

    if (qualityBefore > 0.95) {
      _events.add(FarmEvent(
        kind: FarmEventKind.perfectQuality,
        fieldId: fieldId,
        crop: crop,
        family: crop.family,
        metadata: {
          'quality': qualityBefore,
          'yield': yieldAmount,
        },
      ));
    }

    if (crop.fixesNitrogen && !_firstNitrogenFixerSeen) {
      _firstNitrogenFixerSeen = true;
      _events.add(FarmEvent(
        kind: FarmEventKind.firstNitrogenFixerHarvested,
        fieldId: fieldId,
        crop: crop,
        family: crop.family,
      ));
    }

    if (_totalHarvests == 5 ||
        _totalHarvests == 25 ||
        _totalHarvests == 100 ||
        (_totalHarvests > 100 && _totalHarvests % 100 == 0)) {
      _events.add(FarmEvent(
        kind: FarmEventKind.harvestMilestone,
        metadata: {'total': _totalHarvests},
      ));
    }

    // Harvest may also push fertility above the restored threshold
    // (legume covers add fertility). Re-check the band.
    _checkFertilityBand(f);
    // Cosechar rompe el ciclo de plagas — el pestPressure cae al 30%.
    // Re-emitir el band check para que `pestCleared` se dispare si
    // cruza hacia abajo de 0.1.
    _checkPestBand(f);
    return yieldAmount;
  }

  /// Apply a pest treatment to a single field. Reduces the field's
  /// `pestPressure` by `reduction` (default `0.5`, clamped at 0).
  /// Emits `pestCleared` if the pressure crosses below the healthy
  /// threshold. Does NOT consume a turn — host apps that want to
  /// charge an action cost can wrap this method.
  void treat(String fieldId, {double reduction = 0.5}) {
    final f = field(fieldId);
    f.applyTreatment(reduction: reduction);
    _checkPestBand(f);
  }

  /// Pull every event accumulated since the last call. Returns an
  /// immutable copy and clears the internal buffer. Hosts call this
  /// after each engine action and route the events to whatever UI
  /// surface they want.
  List<FarmEvent> drainEvents() {
    if (_events.isEmpty) return const [];
    final copy = List<FarmEvent>.unmodifiable(_events);
    _events.clear();
    return copy;
  }

  /// Internal hook for serialization. Sets the turn counter without
  /// running the loop. Not part of the public API.
  void hydrateTurn(int turn) {
    _turn = turn;
  }

  /// Internal hook for serialization to seed the harvest counter and
  /// nitrogen-fixer flag from persisted state. Not part of the public API.
  void hydrateCounters({required int totalHarvests, required bool firstNitrogenFixerSeen}) {
    _totalHarvests = totalHarvests;
    _firstNitrogenFixerSeen = firstNitrogenFixerSeen;
  }

  // ── Fertility band tracking ──────────────────────────────────────
  void _checkFertilityBand(Field f) {
    final newBand = _bandOf(f.fertility);
    final oldBand = _lastFertilityBand[f.id] ?? _FertilityBand.healthy;
    if (newBand == oldBand) return;
    _lastFertilityBand[f.id] = newBand;
    switch (newBand) {
      case _FertilityBand.warning:
        if (oldBand == _FertilityBand.healthy) {
          _events.add(FarmEvent(
            kind: FarmEventKind.fertilityWarning,
            fieldId: f.id,
            metadata: {'fertility': f.fertility},
          ));
        }
        break;
      case _FertilityBand.critical:
        _events.add(FarmEvent(
          kind: FarmEventKind.fertilityCritical,
          fieldId: f.id,
          metadata: {'fertility': f.fertility},
        ));
        break;
      case _FertilityBand.healthy:
        if (oldBand != _FertilityBand.healthy) {
          _events.add(FarmEvent(
            kind: FarmEventKind.fertilityRestored,
            fieldId: f.id,
            metadata: {'fertility': f.fertility},
          ));
        }
        break;
    }
  }

  static _FertilityBand _bandOf(double fertility) {
    if (fertility < 0.3) return _FertilityBand.critical;
    if (fertility < 0.5) return _FertilityBand.warning;
    return _FertilityBand.healthy;
  }

  // ── Pest band tracking ──────────────────────────────────────────
  void _checkPestBand(Field f) {
    final newBand = _pestBandOf(f.pestPressure);
    final oldBand = _lastPestBand[f.id] ?? _PestBand.healthy;
    if (newBand == oldBand) return;
    _lastPestBand[f.id] = newBand;
    switch (newBand) {
      case _PestBand.outbreak:
        if (oldBand == _PestBand.healthy) {
          _events.add(FarmEvent(
            kind: FarmEventKind.pestOutbreak,
            fieldId: f.id,
            crop: f.crop,
            family: f.crop?.family,
            metadata: {'pestPressure': f.pestPressure},
          ));
        }
        break;
      case _PestBand.critical:
        _events.add(FarmEvent(
          kind: FarmEventKind.pestCritical,
          fieldId: f.id,
          crop: f.crop,
          family: f.crop?.family,
          metadata: {'pestPressure': f.pestPressure},
        ));
        break;
      case _PestBand.healthy:
        if (oldBand != _PestBand.healthy) {
          _events.add(FarmEvent(
            kind: FarmEventKind.pestCleared,
            fieldId: f.id,
            crop: f.crop,
            family: f.crop?.family,
            metadata: {'pestPressure': f.pestPressure},
          ));
        }
        break;
    }
  }

  static _PestBand _pestBandOf(double pestPressure) {
    if (pestPressure > 0.7) return _PestBand.critical;
    if (pestPressure > 0.3) return _PestBand.outbreak;
    return _PestBand.healthy;
  }
}

enum _FertilityBand { healthy, warning, critical }
enum _PestBand { healthy, outbreak, critical }
