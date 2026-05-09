import 'dart:math';

/// A bundled set of seasonal parameters representing the climate of
/// a region. Plugged into `MockWeatherProvider` to swap the default
/// generic temperate climate for something locale-appropriate.
///
/// The parameters are intentionally compact — five numbers and a
/// hemisphere flag — so a host app can ship a couple of canned
/// presets without carrying a full meteorology dataset. Hosts that
/// want richer climate behaviour should still implement their own
/// `WeatherProvider` against real data; this file is for demos,
/// teaching, and tests.
class ClimatePreset {
  /// Human-readable identifier. Display only.
  final String name;

  /// Average annual temperature in Celsius.
  final double baselineTempC;

  /// Peak-to-peak temperature swing through the seasonal cycle.
  /// `0` produces a flat tropical year; `30` a continental one.
  final double seasonalTempSwing;

  /// Average precipitation per week, mm. Used as the centre of the
  /// pseudo-random precipitation distribution.
  final double basePrecipMm;

  /// Peak-to-peak precipitation swing. Higher values create wet
  /// summers / dry winters (or the opposite, depending on phase).
  final double precipSwing;

  /// Phase offset, in weeks, of the temperature peak within the 52
  /// week cycle. `0` puts the warm peak at week 13 (mid-spring in
  /// the northern convention the kit started from). Use this to
  /// shift the curve for the southern hemisphere or for any region
  /// whose seasons do not align with a temperate-northern default.
  final double phaseOffsetWeeks;

  /// `true` for southern-hemisphere climates: precipitation peaks
  /// half a year off from the northern default. The temperature
  /// phase is controlled separately by `phaseOffsetWeeks`.
  final bool southernHemisphere;

  const ClimatePreset({
    required this.name,
    required this.baselineTempC,
    required this.seasonalTempSwing,
    required this.basePrecipMm,
    required this.precipSwing,
    this.phaseOffsetWeeks = 0,
    this.southernHemisphere = false,
  });

  /// The kit's neutral temperate baseline. Matches the pre-0.2
  /// behaviour of `MockWeatherProvider` so callers that swap in
  /// this preset see no change.
  static const ClimatePreset temperate = ClimatePreset(
    name: 'temperate',
    baselineTempC: 20.0,
    seasonalTempSwing: 15.0,
    basePrecipMm: 15.0,
    precipSwing: 10.0,
  );

  /// Hot, humid, low-swing — equatorial / tropical lowland.
  static const ClimatePreset tropical = ClimatePreset(
    name: 'tropical',
    baselineTempC: 26.0,
    seasonalTempSwing: 6.0,
    basePrecipMm: 35.0,
    precipSwing: 25.0,
  );

  /// Mediterranean: warm dry summers, mild wet winters. Achieved by
  /// flipping the precipitation phase relative to temperature so
  /// rainfall peaks out-of-season.
  static const ClimatePreset mediterranean = ClimatePreset(
    name: 'mediterranean',
    baselineTempC: 17.0,
    seasonalTempSwing: 18.0,
    basePrecipMm: 12.0,
    precipSwing: 15.0,
    phaseOffsetWeeks: 0,
    southernHemisphere: true, // precip peaks opposite the warm side
  );

  /// Continental: cold winters, warm summers, dry-ish.
  static const ClimatePreset continental = ClimatePreset(
    name: 'continental',
    baselineTempC: 10.0,
    seasonalTempSwing: 30.0,
    basePrecipMm: 10.0,
    precipSwing: 8.0,
  );

  /// Subtropical southern South America (Paraguay, north Argentina,
  /// south Brazil). Hot wet summers, cool drier winters, southern
  /// hemisphere phase.
  static const ClimatePreset subtropicalSouthernCone = ClimatePreset(
    name: 'subtropical-southern-cone',
    baselineTempC: 22.0,
    seasonalTempSwing: 14.0,
    basePrecipMm: 25.0,
    precipSwing: 18.0,
    phaseOffsetWeeks: 26, // flip the warm peak to week 39 (Dec/Jan)
    southernHemisphere: true,
  );

  /// All bundled presets. Hosts that want to expose a "pick a
  /// climate" UI can iterate this list directly.
  static const List<ClimatePreset> bundled = [
    temperate,
    tropical,
    mediterranean,
    continental,
    subtropicalSouthernCone,
  ];

  /// Sample the seasonal curve at a given turn. Returns a record
  /// with the modelled temperature and precipitation for that week.
  /// Pure: same input always returns the same output. Used by
  /// `MockWeatherProvider`; rarely called directly by host code.
  ({double tempC, double precipMm}) sample(int turn) {
    final tempPhase = (2 * pi * ((turn + phaseOffsetWeeks) % 52)) / 52;
    final precipPhase = southernHemisphere
        ? (2 * pi * ((turn + phaseOffsetWeeks + 26) % 52)) / 52
        : tempPhase;
    final temp = baselineTempC + (seasonalTempSwing / 2) * sin(tempPhase);
    final precip = basePrecipMm + (precipSwing / 2) * sin(precipPhase);
    return (tempC: temp, precipMm: precip < 0 ? 0 : precip);
  }
}
