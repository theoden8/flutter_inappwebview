// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_extension_context_spec.dart';

// **************************************************************************
// ExchangeableObjectGenerator
// **************************************************************************

///[WebSpace fork patch] One web extension of a [WebExtensionAttach_]: where
///its unpacked files are and what it may reach.
///
///**Officially Supported Platforms/Implementations**:
///- iOS WKWebView 18.4+ ([Official API - WKWebExtensionContext](https://developer.apple.com/documentation/webkit/wkwebextensioncontext))
///- macOS WKWebView 15.4+ ([Official API - WKWebExtensionContext](https://developer.apple.com/documentation/webkit/wkwebextensioncontext))
class WebExtensionContextSpec {
  ///Match patterns granted before the extension loads. Every other host is
  ///refused, including on a request made at run time.
  List<String> grantedMatchPatterns;

  ///API permissions granted before the extension loads (`storage`, `tabs`).
  ///Every other permission is refused.
  List<String> grantedPermissions;

  ///The extension's identity, kept across launches so its stored data is
  ///found again: the context's `uniqueIdentifier` and the host of its
  ///`webkit-extension://` base URL. Lower-case letters, digits and `-`.
  String id;

  ///Absolute path of the folder holding the extension's `manifest.json`.
  String path;

  ///
  ///**Officially Supported Platforms/Implementations**:
  ///- iOS WKWebView 18.4+ ([Official API - WKWebExtensionContext](https://developer.apple.com/documentation/webkit/wkwebextensioncontext))
  ///- macOS WKWebView 15.4+ ([Official API - WKWebExtensionContext](https://developer.apple.com/documentation/webkit/wkwebextensioncontext))
  WebExtensionContextSpec({
    this.grantedMatchPatterns = const [],
    this.grantedPermissions = const [],
    required this.id,
    required this.path,
  });

  ///Gets a possible [WebExtensionContextSpec] instance from a [Map] value.
  static WebExtensionContextSpec? fromMap(
    Map<String, dynamic>? map, {
    EnumMethod? enumMethod,
  }) {
    if (map == null) {
      return null;
    }
    final instance = WebExtensionContextSpec(id: map['id'], path: map['path']);
    if (map['grantedMatchPatterns'] != null) {
      instance.grantedMatchPatterns = List<String>.from(
        map['grantedMatchPatterns']!.cast<String>(),
      );
    }
    if (map['grantedPermissions'] != null) {
      instance.grantedPermissions = List<String>.from(
        map['grantedPermissions']!.cast<String>(),
      );
    }
    return instance;
  }

  ///Converts instance to a map.
  Map<String, dynamic> toMap({EnumMethod? enumMethod}) {
    return {
      "grantedMatchPatterns": grantedMatchPatterns,
      "grantedPermissions": grantedPermissions,
      "id": id,
      "path": path,
    };
  }

  ///Converts instance to a map.
  Map<String, dynamic> toJson() {
    return toMap();
  }

  @override
  String toString() {
    return 'WebExtensionContextSpec{grantedMatchPatterns: $grantedMatchPatterns, grantedPermissions: $grantedPermissions, id: $id, path: $path}';
  }
}
