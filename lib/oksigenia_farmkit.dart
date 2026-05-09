/// Public entrypoint of the kit. Host apps import only this file:
///
///     import 'package:oksigenia_farmkit/oksigenia_farmkit.dart';
///
/// Anything under `lib/src/` is private and can change without notice.
library;

export 'src/engine/crop.dart';
export 'src/engine/farm.dart';
export 'src/engine/field.dart';
export 'src/engine/growth_stage.dart';
export 'src/engine/soil.dart';
export 'src/economy/pricing.dart';
export 'src/weather/mock_weather_provider.dart';
export 'src/weather/weather_provider.dart';
export 'src/weather/weekly_weather.dart';
export 'src/persistence/serialization.dart';
