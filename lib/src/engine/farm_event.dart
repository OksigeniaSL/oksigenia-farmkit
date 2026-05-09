import 'crop.dart';
import 'crop_family.dart';

/// Categories of in-game events the engine can emit. Host apps map
/// each category to whatever surface they want — a banner, a dialog
/// from a narrator character, a log entry, a sound effect.
///
/// The engine never decides how an event is presented or whether the
/// player even sees it. It only describes "something interesting
/// happened on this turn / this harvest" so consumer code can react.
enum FarmEventKind {
  /// Same family planted twice in a row on a field. Mild advice.
  monoCultureWarning,

  /// Same family planted three or more times in a row. Severe.
  monoCultureCritical,

  /// A field's fertility dropped below a comfortable threshold (0.5).
  fertilityWarning,

  /// A field's fertility is critical (< 0.3) — yields will suffer.
  fertilityCritical,

  /// A field that was depleted is now back above 0.9 fertility,
  /// usually after fallow turns or a nitrogen-fixing cover crop.
  fertilityRestored,

  /// Player just harvested a nitrogen-fixing crop for the first time
  /// on this farm. Good moment for an educational beat.
  firstNitrogenFixerHarvested,

  /// Harvest with quality > 0.95. Brag-worthy.
  perfectQuality,

  /// Player rotated to a different family for the Nth consecutive
  /// time without repeating any. Rewards good planning.
  rotationStreak,

  /// Total accumulated harvests reached a milestone (5 / 25 / 100).
  harvestMilestone,

  /// Field's pestPressure crossed above 0.3 — first sign of trouble.
  pestOutbreak,

  /// Field's pestPressure crossed above 0.7 — yields will suffer hard.
  pestCritical,

  /// Pest pressure returned below 0.1 after treatment / harvest /
  /// fallow decay. Lets the host reassure the player.
  pestCleared,
}

/// A single event emitted by the engine. Immutable record-style.
///
/// Hosts read these from `Farm.drainEvents()` after every action
/// (advance / plant / harvest) and decide whether to surface them.
/// The engine fills `metadata` with whatever context the kind
/// implies — a host showing the event in a tooltip can pick the
/// fields it wants without the engine having to pre-format strings.
class FarmEvent {
  final FarmEventKind kind;
  final String? fieldId;
  final Crop? crop;
  final CropFamily? family;
  final Map<String, dynamic> metadata;

  const FarmEvent({
    required this.kind,
    this.fieldId,
    this.crop,
    this.family,
    this.metadata = const {},
  });

  @override
  String toString() => 'FarmEvent(${kind.name}'
      '${fieldId != null ? ', field=$fieldId' : ''}'
      '${crop != null ? ', crop=${crop!.id}' : ''}'
      ')';
}
