// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_extension_problem.dart';

// **************************************************************************
// ExchangeableObjectGenerator
// **************************************************************************

///[WebSpace fork patch] Something that went wrong running a web extension,
///reported as it happens: it did not load, a page or popup of it could not
///be shown, a page of it failed to load, or it asked for a tab or window
///that was refused.
///
///**Officially Supported Platforms/Implementations**:
///- iOS WKWebView 18.4+ ([Official API - WKWebExtensionContext](https://developer.apple.com/documentation/webkit/wkwebextensioncontext))
///- macOS WKWebView 15.4+ ([Official API - WKWebExtensionContext](https://developer.apple.com/documentation/webkit/wkwebextensioncontext))
class WebExtensionProblem {
  ///The extension's identity, as [WebExtensionContextSpec.id] names it.
  String extensionId;

  ///What went wrong, in English, with the engine's own words where it gave
  ///any.
  String message;

  ///
  ///**Officially Supported Platforms/Implementations**:
  ///- iOS WKWebView 18.4+ ([Official API - WKWebExtensionContext](https://developer.apple.com/documentation/webkit/wkwebextensioncontext))
  ///- macOS WKWebView 15.4+ ([Official API - WKWebExtensionContext](https://developer.apple.com/documentation/webkit/wkwebextensioncontext))
  WebExtensionProblem({required this.extensionId, required this.message});

  ///Gets a possible [WebExtensionProblem] instance from a [Map] value.
  static WebExtensionProblem? fromMap(
    Map<String, dynamic>? map, {
    EnumMethod? enumMethod,
  }) {
    if (map == null) {
      return null;
    }
    final instance = WebExtensionProblem(
      extensionId: map['extensionId'],
      message: map['message'],
    );
    return instance;
  }

  ///Converts instance to a map.
  Map<String, dynamic> toMap({EnumMethod? enumMethod}) {
    return {"extensionId": extensionId, "message": message};
  }

  ///Converts instance to a map.
  Map<String, dynamic> toJson() {
    return toMap();
  }

  @override
  String toString() {
    return 'WebExtensionProblem{extensionId: $extensionId, message: $message}';
  }
}
