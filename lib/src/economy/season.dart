/// Seasons of the year. The simulation works on 52 weekly turns per
/// year, divided into 4 seasons of 13 weeks each. Seasons drive the
/// `SeasonalDynamicPricing` modulator and are exposed for hosts that
/// want to render seasonal art, soundtracks, or events.
enum Season {
  /// Mid-summer: hot, peak growing season for tomato-like crops.
  summer,

  /// Autumn: cooling, harvest of grass crops, leafy greens take over.
  autumn,

  /// Winter: cold, root storage shines, fewer fresh greens.
  winter,

  /// Spring: warming, planting season, all crops compete.
  spring,
}

/// Resolves the season for a given turn number.
///
/// `southernHemisphere`: if `true`, the seasonal calendar is shifted
/// 6 months (26 weeks) so summer in the southern hemisphere matches
/// the December-February window typical of Paraguay, Argentina and
/// southern Brazil. Defaults to `false`.
///
/// The mapping is deterministic and stable across saves: a save
/// restored at turn `N` always lands in the same season.
Season seasonForTurn(int turn, {bool southernHemisphere = false}) {
  // Each season spans 13 turns. The "anchor" puts week 0 at the
  // start of summer in the northern hemisphere convention.
  final shifted = southernHemisphere ? turn + 26 : turn;
  final modulo = shifted % 52;
  final positive = modulo < 0 ? modulo + 52 : modulo;
  return Season.values[(positive ~/ 13) % 4];
}
