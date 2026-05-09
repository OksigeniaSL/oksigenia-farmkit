# oksigenia-farmkit · example

Minimal demo app driving the kit through a plain Flutter Material UI: two fields, plant / advance / harvest, current weather, per-field state including fertility and family rotation.

Used as:
- Sanity check that the kit's public API can be driven from a stock Flutter app.
- Source for the live web demo published via GitHub Pages.

## Run locally

```bash
cd example
flutter pub get
flutter run -d chrome   # or any device
```

## Build the web bundle by hand

```bash
flutter build web --release --base-href '/oksigenia-farmkit/'
```

The CI workflow at `.github/workflows/pages.yml` performs the same build on every push to `main` and deploys to GitHub Pages.

## Why no Flame here

The example is intentionally Flame-free — it documents what the kit looks like through a vanilla widget tree. A separate Flame-rendered example will land alongside the kit's `1.0.0` API freeze.
