import 'package:flutter_inappwebview_internal_annotations/flutter_inappwebview_internal_annotations.dart';

import 'enum_method.dart';

part 'web_extension_report.g.dart';

///[WebSpace fork patch] What the engine reports reading an unpacked web
///extension, before any WebView runs it.
@SupportedPlatforms(
  platforms: [
    IOSPlatform(
      available: '18.4',
      apiName: 'WKWebExtension',
      apiUrl: 'https://developer.apple.com/documentation/webkit/wkwebextension',
    ),
    MacOSPlatform(
      available: '15.4',
      apiName: 'WKWebExtension',
      apiUrl: 'https://developer.apple.com/documentation/webkit/wkwebextension',
    ),
  ],
)
@ExchangeableObject()
class WebExtensionReport_ {
  ///The engine's errors and warnings reading the extension, in its own
  ///words. Empty when it reads cleanly; an extension it cannot read at all
  ///has that error alone.
  List<String> errors;

  ///Whether the extension has an options page to open.
  bool hasOptionsPage;

  ///Whether the extension declares an action (`action`, `browser_action`
  ///or `page_action`).
  bool hasAction;

  ///Whether the engine loads the extension on this device. On iOS and
  ///visionOS WebKit refuses one whose background stays loaded (a Manifest
  ///V2 background without `"persistent": false`), and runs none of it.
  bool loadsHere;

  WebExtensionReport_({
    this.errors = const [],
    this.hasOptionsPage = false,
    this.hasAction = false,
    this.loadsHere = true,
  });
}
