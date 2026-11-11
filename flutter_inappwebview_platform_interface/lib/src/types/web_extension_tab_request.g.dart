// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_extension_tab_request.dart';

// **************************************************************************
// ExchangeableObjectGenerator
// **************************************************************************

///[WebSpace fork patch] A web extension asking for a tab at a web page,
///which the host app answers: it opens the page as it chooses, or refuses.
///A tab at one of the extension's own pages never reaches the app; it opens
///over the app as the extension's other pages do.
///
///**Officially Supported Platforms/Implementations**:
///- iOS WKWebView 18.4+ ([Official API - WKWebExtensionControllerDelegate.webExtensionController(_:openNewTabUsing:for:completionHandler:)](https://developer.apple.com/documentation/webkit/wkwebextensioncontrollerdelegate))
///- macOS WKWebView 15.4+ ([Official API - WKWebExtensionControllerDelegate.webExtensionController(_:openNewTabUsing:for:completionHandler:)](https://developer.apple.com/documentation/webkit/wkwebextensioncontrollerdelegate))
class WebExtensionTabRequest {
  ///The container whose WebViews the extension runs in.
  String containerId;

  ///The extension's identity, as [WebExtensionContextSpec.id] names it.
  String extensionId;

  ///The page the tab is asked for.
  String url;

  ///
  ///**Officially Supported Platforms/Implementations**:
  ///- iOS WKWebView 18.4+ ([Official API - WKWebExtensionControllerDelegate.webExtensionController(_:openNewTabUsing:for:completionHandler:)](https://developer.apple.com/documentation/webkit/wkwebextensioncontrollerdelegate))
  ///- macOS WKWebView 15.4+ ([Official API - WKWebExtensionControllerDelegate.webExtensionController(_:openNewTabUsing:for:completionHandler:)](https://developer.apple.com/documentation/webkit/wkwebextensioncontrollerdelegate))
  WebExtensionTabRequest({
    required this.containerId,
    required this.extensionId,
    required this.url,
  });

  ///Gets a possible [WebExtensionTabRequest] instance from a [Map] value.
  static WebExtensionTabRequest? fromMap(
    Map<String, dynamic>? map, {
    EnumMethod? enumMethod,
  }) {
    if (map == null) {
      return null;
    }
    final instance = WebExtensionTabRequest(
      containerId: map['containerId'],
      extensionId: map['extensionId'],
      url: map['url'],
    );
    return instance;
  }

  ///Converts instance to a map.
  Map<String, dynamic> toMap({EnumMethod? enumMethod}) {
    return {"containerId": containerId, "extensionId": extensionId, "url": url};
  }

  ///Converts instance to a map.
  Map<String, dynamic> toJson() {
    return toMap();
  }

  @override
  String toString() {
    return 'WebExtensionTabRequest{containerId: $containerId, extensionId: $extensionId, url: $url}';
  }
}
