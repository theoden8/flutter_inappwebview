import 'package:flutter_inappwebview_internal_annotations/flutter_inappwebview_internal_annotations.dart';

import 'enum_method.dart';

part 'web_extension_problem.g.dart';

///[WebSpace fork patch] Something that went wrong running a web extension,
///reported as it happens: it did not load, a page or popup of it could not
///be shown, a page of it failed to load, or it asked for a tab or window
///that was refused.
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
class WebExtensionProblem_ {
  ///The extension's identity, as [WebExtensionContextSpec_.id] names it.
  String extensionId;

  ///What went wrong, in English, with the engine's own words where it gave
  ///any.
  String message;

  WebExtensionProblem_({required this.extensionId, required this.message});
}
