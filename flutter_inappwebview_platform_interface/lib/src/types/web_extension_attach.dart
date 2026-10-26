import 'package:flutter_inappwebview_internal_annotations/flutter_inappwebview_internal_annotations.dart';

import 'enum_method.dart';
import 'web_extension_context_spec.dart';

part 'web_extension_attach.g.dart';

///[WebSpace fork patch] The web extensions a WebView runs, as the host app
///decided them. The WebView's container names the extension controller, so
///an extension's storage and cookie access follow the container: two
///WebViews in one container share it, two containers never do.
///
///The host decides which hosts and permissions each extension holds; the
///native side only applies [contexts] and answers every request for more
///with what they already grant.
@SupportedPlatforms(
  platforms: [
    IOSPlatform(
      available: '18.4',
      apiName: 'WKWebExtensionController',
      apiUrl:
          'https://developer.apple.com/documentation/webkit/wkwebextensioncontroller',
    ),
    MacOSPlatform(
      available: '15.4',
      apiName: 'WKWebExtensionController',
      apiUrl:
          'https://developer.apple.com/documentation/webkit/wkwebextensioncontroller',
    ),
  ],
)
@ExchangeableObject()
class WebExtensionAttach_ {
  ///Whether the extensions keep their data across launches. `false` gives
  ///the WebView a controller of its own that writes nothing to disk, as an
  ///incognito WebView needs.
  bool persistent;

  ///The extensions to load, each once per controller.
  List<WebExtensionContextSpec_> contexts;

  WebExtensionAttach_({this.persistent = true, this.contexts = const []});
}
