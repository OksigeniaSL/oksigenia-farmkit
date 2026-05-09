import '../engine/crop.dart';

/// Strategy interface for the economy subsystem. The kit ships with
/// `LinearQualityPricing` as default; integration teams can provide
/// custom curves, regional pricing, or volume discounts by
/// implementing this interface.
abstract class EconomyProvider {
  /// Sell price for a single unit of `crop` at the given `quality`
  /// (clamped to 0..1 by the implementation). The result is in
  /// abstract currency units; the host app converts to its own
  /// monetary system.
  double expectedPrice(Crop crop, {required double quality});

  /// Required so const subclasses keep `const` capability.
  const EconomyProvider();
}

/// Default pricing strategy. Quality 0 yields the floor price (40%
/// of base), quality 1 yields the ceiling price (140% of base). The
/// curve is a straight line, intentionally readable: a player who
/// improves quality by 10 points sees a predictable 10% bump.
///
/// Curve: `price(q) = base * (0.4 + q)` where `q` is clamped to 0..1.
class LinearQualityPricing extends EconomyProvider {
  /// Multiplier applied at quality 0. Default `0.4` = a poor harvest
  /// still sells, just below cost.
  final double floor;

  /// Multiplier added when going from quality 0 to quality 1. Default
  /// `1.0` so the ceiling is `floor + 1.0 = 1.4 * base`.
  final double slope;

  const LinearQualityPricing({this.floor = 0.4, this.slope = 1.0});

  @override
  double expectedPrice(Crop crop, {required double quality}) {
    final q = quality.clamp(0.0, 1.0);
    return crop.basePrice * (floor + slope * q);
  }
}
