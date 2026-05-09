# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

While the version number is `0.x`, **breaking changes can land in any release**.
The first stable API will be tagged as `1.0.0`.

## [Unreleased]

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
