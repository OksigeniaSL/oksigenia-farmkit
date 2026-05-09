import '../engine/crop.dart';
import '../engine/crop_family.dart';
import '../weather/weekly_weather.dart';
import 'pricing.dart';
import 'season.dart';

/// Dynamic pricing on top of `LinearQualityPricing`. Multiplies the
/// quality-driven base price by two modulators:
///
/// 1. **Seasonal demand**: each crop family has a preferred season
///    where its price commands a premium (off-season scarcity), and
///    a "low" season where prices dip. The default mapping reflects
///    the rough commercial reality of a temperate or sub-tropical
///    farming calendar; hosts can override via the `seasonalCurve`
///    parameter.
/// 2. **Weather shock**: extreme weather the past week (drought or
///    flood) lifts prices because the regional supply tightens.
///
/// Backwards compatibility: `expectedPrice` (no turn / no weather)
/// behaves identically to `LinearQualityPricing`. New consumers call
/// `dynamicPrice` to pull the modulated value. Hosts using the kit's
/// older API path see no behaviour change unless they migrate.
class SeasonalDynamicPricing extends LinearQualityPricing {
  /// Per-family seasonal multiplier table. Default is reasonable for
  /// a mixed market; override by passing your own map.
  final Map<CropFamily, Map<Season, double>> seasonalCurve;

  /// Multiplier applied during a drought-week harvest (precipitation
  /// below `2 mm`). Default `1.18` (+18% on scarcity).
  final double droughtShock;

  /// Multiplier applied during a flood-week harvest (precipitation
  /// above `60 mm`). Default `1.12` (+12% on scarcity, less than
  /// drought because flooding affects fewer crops fatally).
  final double floodShock;

  /// Hemisphere the farm sits in. Drives `seasonForTurn`.
  final bool southernHemisphere;

  const SeasonalDynamicPricing({
    super.floor = 0.4,
    super.slope = 1.0,
    this.seasonalCurve = _defaultSeasonalCurve,
    this.droughtShock = 1.18,
    this.floodShock = 1.12,
    this.southernHemisphere = false,
  });

  /// Price including seasonal modulation and weather shock. Mirrors
  /// the signature of `expectedPrice` plus the contextual inputs.
  double dynamicPrice(
    Crop crop, {
    required double quality,
    required int turn,
    WeeklyWeather? currentWeather,
  }) {
    final base = expectedPrice(crop, quality: quality);
    final season = seasonForTurn(turn, southernHemisphere: southernHemisphere);
    final seasonMul = _seasonalMultiplier(crop.family, season);
    final shockMul = _weatherShock(currentWeather);
    return base * seasonMul * shockMul;
  }

  /// Pure access to the seasonal multiplier without quality / weather
  /// noise. Hosts use this to render trend indicators in the UI
  /// ("up arrow", "down arrow") without computing the full price.
  double seasonalTrend(Crop crop, {required int turn}) {
    final season = seasonForTurn(turn, southernHemisphere: southernHemisphere);
    return _seasonalMultiplier(crop.family, season);
  }

  double _seasonalMultiplier(CropFamily family, Season season) {
    final curve = seasonalCurve[family];
    if (curve == null) return 1.0;
    return curve[season] ?? 1.0;
  }

  double _weatherShock(WeeklyWeather? w) {
    if (w == null) return 1.0;
    if (w.precipitationMm < 2) return droughtShock;
    if (w.precipitationMm > 60) return floodShock;
    return 1.0;
  }
}

/// Default seasonal multipliers per family. Reflects rough
/// agricultural intuition for a mixed market:
///
/// - Heavy summer feeders (nightshade, grass) command a premium when
///   their season is over and supply tightens.
/// - Leafy greens dip in summer (heat stress, less consumption) and
///   peak in cooler quarters.
/// - Root crops shine in winter (storage staple).
/// - Brassicas peak in winter (frost-sweetened brassicas like cabbage).
/// - Legumes are stable; small premium in winter.
const _defaultSeasonalCurve = <CropFamily, Map<Season, double>>{
  CropFamily.nightshade: {
    Season.summer: 0.85,
    Season.autumn: 1.05,
    Season.winter: 1.30,
    Season.spring: 1.10,
  },
  CropFamily.grass: {
    Season.summer: 0.90,
    Season.autumn: 0.85,
    Season.winter: 1.25,
    Season.spring: 1.15,
  },
  CropFamily.leafy: {
    Season.summer: 1.20,
    Season.autumn: 0.95,
    Season.winter: 0.90,
    Season.spring: 1.00,
  },
  CropFamily.root: {
    Season.summer: 0.95,
    Season.autumn: 1.05,
    Season.winter: 1.20,
    Season.spring: 0.95,
  },
  CropFamily.brassica: {
    Season.summer: 1.10,
    Season.autumn: 0.95,
    Season.winter: 1.25,
    Season.spring: 0.95,
  },
  CropFamily.legume: {
    Season.summer: 1.00,
    Season.autumn: 1.00,
    Season.winter: 1.10,
    Season.spring: 0.95,
  },
  CropFamily.other: {
    Season.summer: 1.00,
    Season.autumn: 1.00,
    Season.winter: 1.00,
    Season.spring: 1.00,
  },
};
