// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_container_controller.dart';

// **************************************************************************
// SupportedPlatformsGenerator
// **************************************************************************

extension _PlatformContainerControllerCreationParamsClassSupported
    on PlatformContainerControllerCreationParams {
  ///{@template flutter_inappwebview_platform_interface.PlatformContainerControllerCreationParams.supported_platforms}
  ///
  ///**Officially Supported Platforms/Implementations**:
  ///- Android WebView
  ///- iOS WKWebView 17.0+
  ///- macOS WKWebView 14.0+
  ///- Linux WPE WebKit
  ///
  ///Use the [PlatformContainerControllerCreationParams.isClassSupported] method to check if this class is supported at runtime.
  ///{@endtemplate}
  static bool isClassSupported({TargetPlatform? platform}) {
    return ((kIsWeb && platform != null) || !kIsWeb) &&
        [
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
          TargetPlatform.linux,
        ].contains(platform ?? defaultTargetPlatform);
  }
}

extension _PlatformContainerControllerClassSupported
    on PlatformContainerController {
  ///{@template flutter_inappwebview_platform_interface.PlatformContainerController.supported_platforms}
  ///
  ///**Officially Supported Platforms/Implementations**:
  ///- Android WebView ([Official API - ProfileStore](https://developer.android.com/reference/androidx/webkit/ProfileStore)):
  ///    - Honored only when WebViewFeature.MULTI_PROFILE is supported (System WebView 110+).
  ///- iOS WKWebView 17.0+ ([Official API - WKWebsiteDataStore.allDataStoreIdentifiers](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/4188695-alldatastoreidentifiers))
  ///- macOS WKWebView 14.0+ ([Official API - WKWebsiteDataStore.allDataStoreIdentifiers](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/4188695-alldatastoreidentifiers))
  ///
  ///Use the [PlatformContainerController.isClassSupported] method to check if this class is supported at runtime.
  ///{@endtemplate}
  static bool isClassSupported({TargetPlatform? platform}) {
    return ((kIsWeb && platform != null) || !kIsWeb) &&
        [
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        ].contains(platform ?? defaultTargetPlatform);
  }
}

///List of [PlatformContainerController]'s methods that can be used to check if they are supported or not by the current platform.
enum PlatformContainerControllerMethod {
  ///Can be used to check if the [PlatformContainerController.deleteContainer] method is supported at runtime.
  ///
  ///{@template flutter_inappwebview_platform_interface.PlatformContainerController.deleteContainer.supported_platforms}
  ///
  ///**Officially Supported Platforms/Implementations**:
  ///- Android WebView ([Official API - ProfileStore.deleteProfile](https://developer.android.com/reference/androidx/webkit/ProfileStore#deleteProfile(java.lang.String)))
  ///- iOS WKWebView 17.0+ ([Official API - WKWebsiteDataStore.remove(forIdentifier:)](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/4188696-remove))
  ///- macOS WKWebView 14.0+ ([Official API - WKWebsiteDataStore.remove(forIdentifier:)](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/4188696-remove))
  ///- Linux WPE WebKit:
  ///    - Recursively removes both `<XDG_DATA_HOME>/flutter_inappwebview/containers/<id>/` and `<XDG_CACHE_HOME>/flutter_inappwebview/containers/<id>/`. The container's data is gone after the next process restart; if any WebView is still attached to its `WebKitNetworkSession` the in-memory state of that session is unaffected — dispose those WebViews first.
  ///
  ///**Parameters - Officially Supported Platforms/Implementations**:
  ///- [containerId]: all platforms
  ///
  ///Use the [PlatformContainerController.isMethodSupported] method to check if this method is supported at runtime.
  ///{@endtemplate}
  deleteContainer,

  ///Can be used to check if the [PlatformContainerController.getAllContainerNames] method is supported at runtime.
  ///
  ///{@template flutter_inappwebview_platform_interface.PlatformContainerController.getAllContainerNames.supported_platforms}
  ///
  ///**Officially Supported Platforms/Implementations**:
  ///- Android WebView ([Official API - ProfileStore.getAllProfileNames](https://developer.android.com/reference/androidx/webkit/ProfileStore#getAllProfileNames()))
  ///- iOS WKWebView 17.0+ ([Official API - WKWebsiteDataStore.allDataStoreIdentifiers](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/4188695-alldatastoreidentifiers))
  ///- macOS WKWebView 14.0+ ([Official API - WKWebsiteDataStore.allDataStoreIdentifiers](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/4188695-alldatastoreidentifiers))
  ///- Linux WPE WebKit:
  ///    - Returns the names of subdirectories under `<XDG_DATA_HOME>/flutter_inappwebview/containers/`. Empty when the directory does not exist.
  ///
  ///Use the [PlatformContainerController.isMethodSupported] method to check if this method is supported at runtime.
  ///{@endtemplate}
  getAllContainerNames,

  ///Can be used to check if the [PlatformContainerController.hasContainer] method is supported at runtime.
  ///
  ///{@template flutter_inappwebview_platform_interface.PlatformContainerController.hasContainer.supported_platforms}
  ///
  ///**Officially Supported Platforms/Implementations**:
  ///- Android WebView ([Official API - ProfileStore.getAllProfileNames](https://developer.android.com/reference/androidx/webkit/ProfileStore#getAllProfileNames()))
  ///- iOS WKWebView 17.0+ ([Official API - WKWebsiteDataStore.allDataStoreIdentifiers](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/4188695-alldatastoreidentifiers))
  ///- macOS WKWebView 14.0+ ([Official API - WKWebsiteDataStore.allDataStoreIdentifiers](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/4188695-alldatastoreidentifiers))
  ///- Linux WPE WebKit:
  ///    - Checks for `<XDG_DATA_HOME>/flutter_inappwebview/containers/<id>/`.
  ///
  ///**Parameters - Officially Supported Platforms/Implementations**:
  ///- [containerId]: all platforms
  ///
  ///Use the [PlatformContainerController.isMethodSupported] method to check if this method is supported at runtime.
  ///{@endtemplate}
  hasContainer,
}

extension _PlatformContainerControllerMethodSupported
    on PlatformContainerController {
  static bool isMethodSupported(
    PlatformContainerControllerMethod method, {
    TargetPlatform? platform,
  }) {
    switch (method) {
      case PlatformContainerControllerMethod.deleteContainer:
        return ((kIsWeb && platform != null) || !kIsWeb) &&
            [
              TargetPlatform.android,
              TargetPlatform.iOS,
              TargetPlatform.macOS,
              TargetPlatform.linux,
            ].contains(platform ?? defaultTargetPlatform);
      case PlatformContainerControllerMethod.getAllContainerNames:
        return ((kIsWeb && platform != null) || !kIsWeb) &&
            [
              TargetPlatform.android,
              TargetPlatform.iOS,
              TargetPlatform.macOS,
              TargetPlatform.linux,
            ].contains(platform ?? defaultTargetPlatform);
      case PlatformContainerControllerMethod.hasContainer:
        return ((kIsWeb && platform != null) || !kIsWeb) &&
            [
              TargetPlatform.android,
              TargetPlatform.iOS,
              TargetPlatform.macOS,
              TargetPlatform.linux,
            ].contains(platform ?? defaultTargetPlatform);
    }
  }
}
