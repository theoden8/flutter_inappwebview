import 'package:flutter_inappwebview_internal_annotations/flutter_inappwebview_internal_annotations.dart';

part 'attribution_behavior.g.dart';

///Class used to indicate how a WebView handles the registration of
///[Attribution Reporting API](https://developer.android.com/design-for-safety/privacy-sandbox/attribution) sources and triggers.
@ExchangeableEnum()
class AttributionBehavior_ {
  // ignore: unused_field
  final int _value;
  const AttributionBehavior_._internal(this._value);

  ///The WebView will not register any attribution sources or triggers.
  static const DISABLED = const AttributionBehavior_._internal(0);

  ///The WebView will register attribution sources as if they came from the app
  ///and attribution triggers as if they came from the web. This is the default.
  static const APP_SOURCE_AND_WEB_TRIGGER = const AttributionBehavior_._internal(
    1,
  );

  ///The WebView will register attribution sources and triggers as if they came
  ///from the web.
  static const WEB_SOURCE_AND_WEB_TRIGGER = const AttributionBehavior_._internal(
    2,
  );

  ///The WebView will register attribution sources and triggers as if they came
  ///from the app.
  static const APP_SOURCE_AND_APP_TRIGGER = const AttributionBehavior_._internal(
    3,
  );
}
