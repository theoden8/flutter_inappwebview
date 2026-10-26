import 'package:flutter_inappwebview_internal_annotations/flutter_inappwebview_internal_annotations.dart';

import 'enum_method.dart';

part 'web_extension_context_spec.g.dart';

///[WebSpace fork patch] One web extension of a [WebExtensionAttach_]: where
///its unpacked files are and what it may reach.
@SupportedPlatforms(
  platforms: [
    IOSPlatform(
      available: '18.4',
      apiName: 'WKWebExtensionContext',
      apiUrl:
          'https://developer.apple.com/documentation/webkit/wkwebextensioncontext',
    ),
    MacOSPlatform(
      available: '15.4',
      apiName: 'WKWebExtensionContext',
      apiUrl:
          'https://developer.apple.com/documentation/webkit/wkwebextensioncontext',
    ),
  ],
)
@ExchangeableObject()
class WebExtensionContextSpec_ {
  ///The extension's identity, kept across launches so its stored data is
  ///found again: the context's `uniqueIdentifier` and the host of its
  ///`webkit-extension://` base URL. Lower-case letters, digits and `-`.
  String id;

  ///Absolute path of the folder holding the extension's `manifest.json`.
  String path;

  ///Match patterns granted before the extension loads. Every other host is
  ///refused, including on a request made at run time.
  List<String> grantedMatchPatterns;

  ///API permissions granted before the extension loads (`storage`, `tabs`).
  ///Every other permission is refused.
  List<String> grantedPermissions;

  WebExtensionContextSpec_({
    required this.id,
    required this.path,
    this.grantedMatchPatterns = const [],
    this.grantedPermissions = const [],
  });
}
