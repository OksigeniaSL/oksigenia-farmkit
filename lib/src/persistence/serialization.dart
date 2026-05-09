import '../engine/crop.dart';
import '../engine/crop_family.dart';
import '../engine/farm.dart';
import '../engine/field.dart';
import '../engine/soil.dart';

/// Serialization helpers. The kit emits and consumes `Map<String,
/// dynamic>` so host apps are free to persist via Hive, shared_prefs,
/// JSON files, or any other mechanism.
///
/// The format is versioned (`schema`). Loaders should refuse unknown
/// schema versions rather than silently mis-interpret data; older
/// known versions are migrated forward in-place by `applyFarmFromMap`.
class Serialization {
  /// Current schema version. Bumped on any breaking change.
  ///
  /// History:
  /// - `1`: initial release.
  /// - `2`: adds `fertility`, `lastHarvestedFamily`, `consecutiveSameFamily`
  ///   per field for soil degradation + crop rotation.
  static const int schemaVersion = 2;

  /// Convert a `Farm` snapshot to a serializable map.
  static Map<String, dynamic> farmToMap(Farm farm) {
    return {
      'schema': schemaVersion,
      'turn': farm.turn,
      'fields': farm.fields.map(_fieldToMap).toList(),
    };
  }

  /// Re-hydrate field state from a map. Does NOT reconstruct the
  /// weather provider or the economy strategy — those are passed in
  /// from the host app along with the rest of the `Farm`. This keeps
  /// the persistence layer free of strategy serialization concerns.
  ///
  /// Schema `1` saves are migrated to schema `2` defaults: fertility
  /// jumps to `1.0` (virgin land) and rotation history starts empty.
  /// Saves at any other version throw `StateError` — the host app is
  /// expected to run its own migration before loading.
  static void applyFarmFromMap(Farm farm, Map<String, dynamic> data) {
    final schema = data['schema'] as int?;
    if (schema != schemaVersion && schema != 1) {
      throw StateError(
        'Unsupported save schema $schema (expected $schemaVersion). '
        'Run a migration before loading.',
      );
    }
    final turn = (data['turn'] as int?) ?? 0;
    farm.hydrateTurn(turn);

    final fieldEntries = (data['fields'] as List<dynamic>? ?? <dynamic>[]);
    for (final raw in fieldEntries) {
      final m = raw as Map<String, dynamic>;
      final id = m['id'] as String;
      final field = farm.fields.firstWhere(
        (f) => f.id == id,
        orElse: () => throw StateError(
          'Save references field "$id" but the loaded farm does not have it.',
        ),
      );
      _applyFieldFromMap(field, m);
    }
  }

  static Map<String, dynamic> _fieldToMap(Field f) {
    return {
      'id': f.id,
      'size': f.size,
      'soil': f.soil.name,
      if (f.crop != null) 'cropId': f.crop!.id,
      'turnsGrown': f.turnsGrown,
      'quality': f.quality,
      'fertility': f.fertility,
      if (f.lastHarvestedFamily != null)
        'lastHarvestedFamily': f.lastHarvestedFamily!.name,
      'consecutiveSameFamily': f.consecutiveSameFamily,
    };
  }

  static void _applyFieldFromMap(Field f, Map<String, dynamic> m) {
    final cropId = m['cropId'] as String?;
    final crop = cropId == null ? null : _resolveCrop(cropId);
    final familyName = m['lastHarvestedFamily'] as String?;
    final family = familyName == null
        ? null
        : CropFamily.values.firstWhere(
            (e) => e.name == familyName,
            orElse: () => throw StateError(
              'Unknown crop family "$familyName" in save data.',
            ),
          );
    f.hydrateFromMap(
      crop: crop,
      turnsGrown: (m['turnsGrown'] as int?) ?? 0,
      quality: ((m['quality'] as num?) ?? 0).toDouble(),
      fertility: ((m['fertility'] as num?) ?? 1.0).toDouble(),
      lastHarvestedFamily: family,
      consecutiveSameFamily: (m['consecutiveSameFamily'] as int?) ?? 0,
    );
  }

  /// Resolves a crop id back to a `Crop` instance using the default
  /// library shipped with the kit. Host apps with a richer catalog
  /// should pre-process the save data to substitute ids before
  /// calling `applyFarmFromMap` — or fork this helper.
  static Crop _resolveCrop(String id) {
    return Crop.defaultLibrary.firstWhere(
      (c) => c.id == id,
      orElse: () => throw StateError(
        'Unknown crop id "$id" in save data. '
        'If using a custom catalog, substitute ids before loading.',
      ),
    );
  }

  /// Re-export so host apps can validate soil names without
  /// importing `soil.dart` directly.
  static SoilType parseSoil(String name) {
    return SoilType.values.firstWhere(
      (s) => s.name == name,
      orElse: () => throw StateError('Unknown soil type "$name".'),
    );
  }
}
