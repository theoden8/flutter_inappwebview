// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_extension_report.dart';

// **************************************************************************
// ExchangeableObjectGenerator
// **************************************************************************

///[WebSpace fork patch] What the engine reports reading an unpacked web
///extension, before any WebView runs it.
///
///**Officially Supported Platforms/Implementations**:
///- iOS WKWebView 18.4+ ([Official API - WKWebExtension](https://developer.apple.com/documentation/webkit/wkwebextension))
///- macOS WKWebView 15.4+ ([Official API - WKWebExtension](https://developer.apple.com/documentation/webkit/wkwebextension))
class WebExtensionReport {
  ///The engine's errors and warnings reading the extension, in its own
  ///words. Empty when it reads cleanly; an extension it cannot read at all
  ///has that error alone.
  List<String> errors;

  ///Whether the extension declares an action (`action`, `browser_action`
  ///or `page_action`).
  bool hasAction;

  ///Whether the extension has an options page to open.
  bool hasOptionsPage;

  ///Whether the engine loads the extension on this device. On iOS and
  ///visionOS WebKit refuses one whose background stays loaded (a Manifest
  ///V2 background without `"persistent": false`), and runs none of it.
  bool loadsHere;

  ///
  ///**Officially Supported Platforms/Implementations**:
  ///- iOS WKWebView 18.4+ ([Official API - WKWebExtension](https://developer.apple.com/documentation/webkit/wkwebextension))
  ///- macOS WKWebView 15.4+ ([Official API - WKWebExtension](https://developer.apple.com/documentation/webkit/wkwebextension))
  WebExtensionReport({
    this.errors = const [],
    this.hasAction = false,
    this.hasOptionsPage = false,
    this.loadsHere = true,
  });

  ///Gets a possible [WebExtensionReport] instance from a [Map] value.
  static WebExtensionReport? fromMap(
    Map<String, dynamic>? map, {
    EnumMethod? enumMethod,
  }) {
    if (map == null) {
      return null;
    }
    final instance = WebExtensionReport();
    if (map['errors'] != null) {
      instance.errors = List<String>.from(map['errors']!.cast<String>());
    }
    if (map['hasAction'] != null) {
      instance.hasAction = map['hasAction'];
    }
    if (map['hasOptionsPage'] != null) {
      instance.hasOptionsPage = map['hasOptionsPage'];
    }
    if (map['loadsHere'] != null) {
      instance.loadsHere = map['loadsHere'];
    }
    return instance;
  }

  ///Converts instance to a map.
  Map<String, dynamic> toMap({EnumMethod? enumMethod}) {
    return {
      "errors": errors,
      "hasAction": hasAction,
      "hasOptionsPage": hasOptionsPage,
      "loadsHere": loadsHere,
    };
  }

  ///Converts instance to a map.
  Map<String, dynamic> toJson() {
    return toMap();
  }

  @override
  String toString() {
    return 'WebExtensionReport{errors: $errors, hasAction: $hasAction, hasOptionsPage: $hasOptionsPage, loadsHere: $loadsHere}';
  }
}
