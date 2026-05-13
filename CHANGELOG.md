# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

While the version number is `0.x`, **breaking changes can land in any release**.
The first stable API will be tagged as `1.0.0`.

## [Unreleased]

## [0.7.0-beta.2] — 2026-05-13

### Changed
- **Demo web** (`example/lib/main.dart`) — visual upgrade: hero card,
  feature pills, stat bars, brand colors. Surfacing the features
  shipped in 0.4-0.7 (narrative events, seasonal pricing + weather
  shock, pest subsystem, per-turn action budget) in a single screen
  that auto-deploys to GitHub Pages from `main`.
- **README** — surface 0.4-0.7 features and add donation links
  (Liberapay + PayPal).

### Added
- `.github/FUNDING.yml` — Liberapay + PayPal sponsorship buttons.

### Notes
- Pure docs / demo release. Public API and tests unchanged from
  0.7.0-beta.1. Consumers of the lib don't need to update unless
  they want the refreshed example.

## [0.7.0-beta.1] — 2026-05-09

### Added
- `Farm(actionsPerTurn: int)` optional constructor parameter. When
  set, every call to `plant`, `harvest` or `treat` consumes one
  action from a per-turn budget. `advanceTurn` refills it. Hosts
  catch `OutOfActionsError` to nudge the player.
- `Farm.actionsRemaining` getter for HUDs.
- `OutOfActionsError` (extends StateError) thrown when an action
  runs while the budget is at zero. Message is in Spanish for the
  default flavour but hosts can override per-throw if needed.
- 8 new tests under `test/actions_budget_test.dart`. 80 total.

### Notes
- Pure additive. Default `actionsPerTurn = null` preserves the
  pre-0.7 behaviour: no budget, infinite actions per turn. Hosts
  opt in by passing a positive integer.

## [0.6.0-beta.1] — 2026-05-09

### Added
- `WeeklyWeather.pestRisk` (default `0.0`) — likelihood of a pest /
  disease outbreak this week, in `[0, 1]`. Hot+humid weeks push it
  up. `MockWeatherProvider` now computes it from the actual temp +
  precipitation (so tropical climates rate higher than continental).
- `Crop.pestSusceptibility` (default `0.5`) — vulnerability to pests
  per crop. Multiplied with `pestRisk` to drive `Field.pestPressure`
  accumulation.
- `Field.pestPressure` getter and accumulation logic during
  `advance(weatherFactor, pestRisk)`. Pressure persists across turns,
  decays during fallow (`-0.10/turn`), and is reset partially on
  harvest (`× 0.3`).
- `Field.advance` now penalises quality by up to 50% when
  `pestPressure` is at 1.0, scaling linearly. Sick fields still grow
  but yield mediocre crops.
- `Field.applyTreatment(reduction)` to manually clear pressure.
- `Farm.treat(fieldId, reduction)` — host-side action to apply a
  treatment. Emits `pestCleared` if pressure crosses below 0.1.
- `FarmEventKind.pestOutbreak` (>0.3), `pestCritical` (>0.7),
  `pestCleared` (<0.1).
- `Farm` constructor seeds the per-field pest band tracker.
- 12 new tests under `test/pest_test.dart`. 72 total.

### Changed
- `Field.advance` signature now accepts `pestRisk` (default `0.0`).
  Existing callers without pests see no change.

### Notes
- Backwards compatible. Hosts whose `WeatherProvider` does not set
  `pestRisk` get the default `0.0` and pests never appear. Hosts
  whose `Crop` definitions do not set `pestSusceptibility` get the
  default `0.5` (medium); to opt out of the pest subsystem entirely,
  set it to `0.0` per crop.

## [0.5.0-beta.1] — 2026-05-09

### Added
- `Season` enum (summer, autumn, winter, spring) and `seasonForTurn`
  helper that maps a turn number to its season, with a
  `southernHemisphere` flag that shifts the calendar 6 months for
  hosts whose farm sits south of the equator.
- `SeasonalDynamicPricing` extends `LinearQualityPricing` with two
  modulators:
  - **Seasonal demand** per `CropFamily`: nightshade and grass peak in
    winter; leafy greens command a premium in summer; root crops shine
    in winter; brassicas peak in winter; legumes are stable.
  - **Weather shock**: drought weeks (precip < 2 mm) lift price by
    `droughtShock` (default 1.18), flood weeks (precip > 60 mm) by
    `floodShock` (default 1.12). Moderate weather is neutral.
- `dynamicPrice(crop, quality, turn, currentWeather)` returns the
  modulated value. `seasonalTrend(crop, turn)` returns just the
  seasonal multiplier so hosts can render UI trend indicators.
- 11 new tests under `test/dynamic_pricing_test.dart`. 60 passing.

### Notes
- Pure additive change. Hosts using `LinearQualityPricing` see no
  difference. Hosts that adopt `SeasonalDynamicPricing` and call
  `expectedPrice` (the inherited method) keep getting the legacy
  quality-only price; only `dynamicPrice` activates the modulators.

## [0.4.0-beta.1] — 2026-05-09

### Added
- `FarmEvent` and `FarmEventKind` — narrative-grade events the engine
  emits as the simulation evolves. Hosts pull them with
  `Farm.drainEvents()` after each action and decide how to surface
  them (banners, narrator dialogs, sound effects, log entries).
- Event kinds shipped: `monoCultureWarning`, `monoCultureCritical`,
  `fertilityWarning`, `fertilityCritical`, `fertilityRestored`,
  `firstNitrogenFixerHarvested`, `perfectQuality`, `rotationStreak`,
  `harvestMilestone`.
- `Farm.totalHarvests` cumulative counter (drives milestones).
- `Farm.drainEvents()` returns the buffered events and clears the
  internal queue.
- `Farm.hydrateCounters(...)` internal hook for serialization to
  preserve the milestone counter and "first nitrogen fixer seen"
  flag across saves (host wiring optional).
- 11 new tests under `test/events_test.dart` covering mono-culture
  threshold transitions, single-fire fertility band crossings,
  legume restoration, first-nitrogen-fixer once-only, milestones
  exact at 5/25/100/+100k.

### Notes
- Pure additive change. Pre-existing host code keeps working;
  consumers that ignore `drainEvents()` simply do not see the new
  events.

## [0.3.0-beta.1] — 2026-05-09

### Added
- `ClimatePreset` value object: a compact bundle of seasonal
  parameters (baseline temperature, swing, precipitation, hemisphere
  flag, phase offset). Pluggable into `MockWeatherProvider`.
- Five bundled presets: `temperate`, `tropical`, `mediterranean`,
  `continental`, `subtropicalSouthernCone`.
- `MockWeatherProvider.forClimate(preset)` named constructor.
- `ClimatePreset.bundled` exposes all five for "pick a climate" UIs.
- Test suite extended with 8 new tests covering seasonal averages,
  swing comparisons, southern-hemisphere phase, precipitation
  non-negativity and per-preset determinism.

### Changed
- `MockWeatherProvider` now takes a `ClimatePreset` instead of the
  ad-hoc `baselineTempC` / `seasonalTempSwing` parameters. The default
  preset (`temperate`) reproduces the pre-0.3 behaviour, so callers
  using `MockWeatherProvider.seasonal()` see no change. Callers that
  passed the old named arguments must migrate to a preset.

### Migration notes
- If you instantiated `MockWeatherProvider(baselineTempC: …,
  seasonalTempSwing: …)`, declare a custom `ClimatePreset` with those
  values and pass it via `climate:`.

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
