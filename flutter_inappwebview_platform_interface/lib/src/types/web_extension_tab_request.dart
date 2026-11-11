import 'package:flutter_inappwebview_internal_annotations/flutter_inappwebview_internal_annotations.dart';

import 'enum_method.dart';

part 'web_extension_tab_request.g.dart';

///[WebSpace fork patch] A web extension asking for a tab at a web page,
///which the host app answers: it opens the page as it chooses, or refuses.
///A tab at one of the extension's own pages never reaches the app; it opens
///over the app as the extension's other pages do.
@SupportedPlatforms(
  platforms: [
    IOSPlatform(
      available: '18.4',
      apiName: 'WKWebExtensionControllerDelegate.webExtensionController(_:openNewTabUsing:for:completionHandler:)',
      apiUrl:
          'https://developer.apple.com/documentation/webkit/wkwebextensioncontrollerdelegate',
    ),
    MacOSPlatform(
      available: '15.4',
      apiName: 'WKWebExtensionControllerDelegate.webExtensionController(_:openNewTabUsing:for:completionHandler:)',
      apiUrl:
          'https://developer.apple.com/documentation/webkit/wkwebextensioncontrollerdelegate',
    ),
  ],
)
@ExchangeableObject()
class WebExtensionTabRequest_ {
  ///The container whose WebViews the extension runs in.
  String containerId;

  ///The extension's identity, as [WebExtensionContextSpec_.id] names it.
  String extensionId;

  ///The page the tab is asked for.
  String url;

  WebExtensionTabRequest_({
    required this.containerId,
    required this.extensionId,
    required this.url,
  });
}
