# oksigenia-farmkit 🌾

**Modular farming-game engine for Flutter / Flame.**

Turn-based, weather-driven crop yield, quality-driven economy. Designed to be embedded in any Flutter app that needs a farm-simulation mini-game.

> **Status: `0.7.0-beta.2`** — public API is not yet stable. Expect breaking changes between minor versions until `1.0.0`.

**[▶ Live demo](https://oksigeniasl.github.io/oksigenia-farmkit/)** (Flutter web · auto-deployed from `main`).

---

## Why

The Flutter / Flame ecosystem has plenty of arcade and puzzle game scaffolding, but **no maintained, permissively-licensed farming-simulation kit**. This package fills that gap with three opinionated subsystems:

- **Engine**: weekly turn loop, fields, crops, growth model.
- **Economy**: dynamic pricing where crop quality shifts the sell price.
- **Weather**: pluggable provider — supply real meteorological data or use the built-in deterministic mock.

The kit is **engine-only**. It exposes a pure-Dart API; rendering and assets are the consumer's responsibility. A minimal Flutter + Flame example lives under [`example/`](example/).

---

## At a glance

```dart
import 'package:oksigenia_farmkit/oksigenia_farmkit.dart';

final farm = Farm(
  fields: [
    Field(id: 'a', size: 1.0, soil: SoilType.loam),
    Field(id: 'b', size: 0.5, soil: SoilType.clay),
  ],
  weather: MockWeatherProvider.seasonal(),
);

farm.plant(fieldId: 'a', crop: Crop.tomato);
farm.advanceTurn();           // one in-game week passes
print(farm.field('a').growthStage);   // 'seedling' | 'growing' | 'ready'
print(farm.economy.expectedPrice(Crop.tomato, quality: 0.8));

// Crop rotation matters: heavy feeders drain soil fertility, and
// planting the same family back-to-back drains it faster.
print(farm.field('a').fertility);              // 1.0 on virgin land
farm.harvest('a');                             // tomato → fertility -0.25
farm.plant(fieldId: 'a', crop: Crop.legumeCover); // restorer crop
```

The example app expands this into a full playable loop with Flame rendering, save/load via Hive, and a minimal HUD.

---

## Install

Once published to pub.dev:

```yaml
dependencies:
  oksigenia_farmkit: ^0.7.0-beta.2
```

Until then, depend on the GitHub repo:

```yaml
dependencies:
  oksigenia_farmkit:
    git:
      url: https://github.com/OksigeniaSL/oksigenia-farmkit.git
      ref: main
```

Flutter `>=3.10.0`, Dart `>=3.0.0`. No platform-specific code in the core; runs anywhere Flutter runs.

---

## Architecture

The kit is split into four subsystems behind a single facade (`Farm`). Each subsystem can be replaced or wrapped without forking:

```
oksigenia_farmkit
├── engine/        Turn loop, fields, crops, growth state machine.
├── economy/       Pricing model, market dynamics, quality multipliers.
├── weather/       WeatherProvider interface + MockWeatherProvider.
└── persistence/   Save / load via Dart maps (Hive-friendly, no Hive dependency).
```

The reason for this split: **integration teams replace what they need.** A real-world weather feed plugs into `WeatherProvider`. A custom economy (volume discounts, regional pricing) plugs into `EconomyProvider`. Persistence layer is whatever the host app prefers — the kit emits and consumes plain `Map<String, dynamic>`.

---

## Status & roadmap

This is a **beta**. The data model and public API will move until `1.0.0`. See [CHANGELOG.md](CHANGELOG.md) for breaking changes.

Tracked work lives in the [project board](https://github.com/orgs/OksigeniaSL/projects). Highlights for `0.x`:

- ~~Crop pest / disease subsystem.~~ Shipped in `0.6.0-beta.1`.
- ~~Soil degradation & rotation rewards.~~ Shipped in `0.2.0-beta.1`.
- ~~Multi-region weather (climates).~~ Shipped in `0.3.0-beta.1`.
- Saved-game migration helpers between minor versions.
- Pub.dev publication after `0.4.0`.

---

## Contributing

Bug reports, feature ideas, and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR. For security issues, see [SECURITY.md](SECURITY.md) — please do not file them as public issues.

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).

---

## License

MIT. See [LICENSE](LICENSE).

Copyright © 2026 Oksigenia SL.

---

## Sponsor / Donaciones

This project is developed in the open and offered under MIT. If it saves you time or you want to support continued development, you can chip in:

- **Liberapay** (recurring, no fees): https://liberapay.com/Oksigenia
- **PayPal** (one-off): https://www.paypal.com/donate/?business=paypal@oksigenia.cc&currency_code=EUR

A "Sponsor" button is also enabled at the top of this repository (powered by [`.github/FUNDING.yml`](.github/FUNDING.yml)).

---

## En castellano

`oksigenia-farmkit` es un motor de juego de granja para Flutter / Flame. Turnos semanales, rendimiento de cultivos según clima real o simulado, economía sensible a la calidad. Embebible en cualquier app Flutter como minijuego.

**Estado: beta**. La API pública puede cambiar hasta la versión `1.0.0`.

Para integradores en LATAM: el kit es agnóstico de cultivos — los productos del catálogo del host se mapean a la abstracción `Crop`. Un `WeatherProvider` real (por ejemplo Open-Meteo) se conecta sustituyendo el mock por defecto.

PRs y issues bienvenidos. Antes de abrir un PR, leer [CONTRIBUTING.md](CONTRIBUTING.md).
