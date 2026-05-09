import '../economy/pricing.dart';
import '../weather/weather_provider.dart';
import 'crop.dart';
import 'field.dart';

/// Top-level facade. Host apps interact with this class; the
/// individual subsystems are exposed as properties for advanced
/// callers that need direct access.
///
/// A `Farm` is mutable. The kit does not impose any concurrency
/// model; callers that need thread safety wrap operations on the
/// host side.
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

  Farm({
    required this.fields,
    required this.weather,
    EconomyProvider? economy,
  }) : economy = economy ?? const LinearQualityPricing();

  /// Look up a field by id. Throws `StateError` if no such field
  /// exists — consumers expected to know which ids are present.
  Field field(String id) {
    return fields.firstWhere(
      (f) => f.id == id,
      orElse: () => throw StateError('No field with id "$id".'),
    );
  }

  /// Plant a crop on a specific field. Convenience method that
  /// delegates to `Field.plant`.
  void plant({required String fieldId, required Crop crop}) {
    field(fieldId).plant(crop);
  }

  /// Advance the simulation by one turn. Pulls a fresh weather
  /// sample and applies it uniformly to every planted field. Returns
  /// the weather factor used so callers can display it.
  double advanceTurn() {
    _turn += 1;
    final w = weather.sample(turn: _turn);
    for (final f in fields) {
      f.advance(weatherFactor: w.growthFactor);
    }
    return w.growthFactor;
  }

  /// Harvest a single field. See `Field.harvest`.
  double harvest(String fieldId) => field(fieldId).harvest();

  /// Internal hook for serialization. Sets the turn counter without
  /// running the loop. Not part of the public API.
  void hydrateTurn(int turn) {
    _turn = turn;
  }
}
