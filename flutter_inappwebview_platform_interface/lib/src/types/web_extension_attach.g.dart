// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_extension_attach.dart';

// **************************************************************************
// ExchangeableObjectGenerator
// **************************************************************************

///[WebSpace fork patch] The web extensions a WebView runs, as the host app
///decided them. The WebView's container names the extension controller, so
///an extension's storage and cookie access follow the container: two
///WebViews in one container share it, two containers never do.
///
///The host decides which hosts and permissions each extension holds; the
///native side only applies [contexts] and answers every request for more
///with what they already grant.
///
///**Officially Supported Platforms/Implementations**:
///- iOS WKWebView 18.4+ ([Official API - WKWebExtensionController](https://developer.apple.com/documentation/webkit/wkwebextensioncontroller))
///- macOS WKWebView 15.4+ ([Official API - WKWebExtensionController](https://developer.apple.com/documentation/webkit/wkwebextensioncontroller))
class WebExtensionAttach {
  ///The extensions to load, each once per controller.
  List<WebExtensionContextSpec> contexts;

  ///Whether the extensions keep their data across launches. `false` gives
  ///the WebView a controller of its own that writes nothing to disk, as an
  ///incognito WebView needs.
  bool persistent;

  ///
  ///**Officially Supported Platforms/Implementations**:
  ///- iOS WKWebView 18.4+ ([Official API - WKWebExtensionController](https://developer.apple.com/documentation/webkit/wkwebextensioncontroller))
  ///- macOS WKWebView 15.4+ ([Official API - WKWebExtensionController](https://developer.apple.com/documentation/webkit/wkwebextensioncontroller))
  WebExtensionAttach({this.contexts = const [], this.persistent = true});

  ///Gets a possible [WebExtensionAttach] instance from a [Map] value.
  static WebExtensionAttach? fromMap(
    Map<String, dynamic>? map, {
    EnumMethod? enumMethod,
  }) {
    if (map == null) {
      return null;
    }
    final instance = WebExtensionAttach();
    if (map['contexts'] != null) {
      instance.contexts = List<WebExtensionContextSpec>.from(
        map['contexts'].map(
          (e) => WebExtensionContextSpec.fromMap(
            e?.cast<String, dynamic>(),
            enumMethod: enumMethod,
          )!,
        ),
      );
    }
    if (map['persistent'] != null) {
      instance.persistent = map['persistent'];
    }
    return instance;
  }

  ///Converts instance to a map.
  Map<String, dynamic> toMap({EnumMethod? enumMethod}) {
    return {
      "contexts": contexts.map((e) => e.toMap(enumMethod: enumMethod)).toList(),
      "persistent": persistent,
    };
  }

  ///Converts instance to a map.
  Map<String, dynamic> toJson() {
    return toMap();
  }

  @override
  String toString() {
    return 'WebExtensionAttach{contexts: $contexts, persistent: $persistent}';
  }
}
