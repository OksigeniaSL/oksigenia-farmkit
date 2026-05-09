# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

While the version number is `0.x`, **breaking changes can land in any release**.
The first stable API will be tagged as `1.0.0`.

## [Unreleased]

## [0.2.0-beta.1] — 2026-05-09

### Added
- `CropFamily` enum classifying crops botanically (nightshade, brassica,
  legume, root, leafy, grass, other). Drives crop-rotation mechanics.
- `Crop.family`, `Crop.nutrientDemand`, `Crop.fixesNitrogen` fields with
  backwards-compatible defaults (`other`, `0.1`, `false`).
- `Crop.legumeCover` archetype: nitrogen-fixing cover crop that *adds*
  fertility instead of draining it.
- `Field.fertility`, `Field.lastHarvestedFamily`, `Field.consecutiveSameFamily`
  observable properties.
- Soil degradation model: each harvest deducts `nutrientDemand` from the
  field's fertility, scaled up by a mono-culture streak multiplier
  (`1.0 + 0.5 * streak`).
- Fallow recovery: empty fields gain `+0.05` fertility per turn.
- Schema version `2` for save data, with seamless migration from
  schema `1` (legacy saves load with `fertility = 1.0`).
- Test suite extended with 13 new tests covering fertility, rotation,
  cover crops, depletion-driven quality and serialization migration.

### Changed
- `Field.advance` now multiplies the effective weather factor by the
  field's current fertility (floored at `0.3` so the game never gets
  stuck on dust). Mature fields with depleted soil grow lower-quality
  crops than virgin land under identical weather.
- `Field.harvest` now records the harvested crop's family and adjusts
  fertility per the rules above.
- `Field.plant` now updates the same-family streak based on the new
  crop's family vs the last harvested one.

### Migration notes
- Hosts using the kit do not need to change anything: `CropFamily.other`
  and the default `nutrientDemand` keep the pre-0.2 behaviour. Hosts
  that *want* the new mechanics should classify their crops by family
  and tune `nutrientDemand` per crop.
- Schema-1 saves load without intervention. Schema-2 saves are not
  readable by 0.1.x.

## [0.1.0-beta.1] — 2026-05-09

### Added
- Initial public scaffold.
- `Farm` facade aggregating the four subsystems.
- `engine/`: turn-based loop, `Field`, `Crop`, `SoilType`, growth state machine.
- `economy/`: quality-multiplier pricing model.
- `weather/`: `WeatherProvider` interface + `MockWeatherProvider` (deterministic seasonal).
- `persistence/`: serialization helpers to plain `Map<String, dynamic>`.
- Minimal example under `example/` (Flutter + Flame).
- CI: `flutter analyze` + `flutter test` on every push.

### Notes
- Public API marked beta. Expect breaking changes until `1.0.0`.
- Not yet published to pub.dev. Use git dependency.
