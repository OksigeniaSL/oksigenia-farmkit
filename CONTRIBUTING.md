# Contributing to oksigenia-farmkit

Thanks for considering a contribution. This document covers what is and is not in scope, the local development workflow, and the quality bar for pull requests.

## Scope

In scope:

- Improvements to the four core subsystems (`engine`, `economy`, `weather`, `persistence`).
- New crop types, soil types, weather conditions — provided they are generic enough to be useful outside any single host app.
- Tests, documentation, examples.
- Performance fixes.

Out of scope:

- Rendering primitives. The kit is engine-only. Visual polish belongs in the host app, not here.
- Asset packs (sprites, audio). The kit is data-driven; sprites are the consumer's responsibility.
- Region-specific cultural integrations (e.g. mapping crops to a specific country's catalog). Those belong in the host app's wrapper layer.

If unsure, open an issue first to discuss.

## Local setup

```sh
git clone https://github.com/OksigeniaSL/oksigenia-farmkit.git
cd oksigenia-farmkit
flutter pub get
flutter analyze
flutter test
```

To run the example:

```sh
cd example
flutter pub get
flutter run
```

The example uses a relative path dependency on the parent package, so changes to the kit are picked up immediately.

## Quality bar for PRs

- `flutter analyze` clean. The repo enforces strict lints (`analysis_options.yaml`).
- `flutter test` green. New behaviour ships with new tests.
- Public API changes touch `CHANGELOG.md` under `[Unreleased]`.
- Commit messages: imperative present tense ("Add soil rotation bonus", not "Added").
- Comments in code are neutral and explain the why. They describe the constraint or invariant, not who wrote them.

## Reviewing your own PR before submitting

- [ ] No `print` / `debugPrint` left in `lib/`.
- [ ] No `TODO` without a tracking issue link.
- [ ] No imports from `dart:io` or `dart:html` in `lib/src/` (kit must stay platform-agnostic).
- [ ] Public API additions are documented with `///` triple-slash doc comments.
- [ ] Tests added for new public behaviour.

## Versioning

The project follows SemVer once it reaches `1.0.0`. Until then, **any release can break the API**. Breaking changes are documented in `CHANGELOG.md`.

## License

By contributing, you agree that your contributions are licensed under the MIT License.
