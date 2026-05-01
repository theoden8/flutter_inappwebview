## Unreleased (WebSpace fork)

- [WebSpace fork patch] Added `UserAgentMetadata` and `BrandVersion` types and the `InAppWebViewSettings.userAgentMetadata` setting. Maps to `androidx.webkit.WebSettingsCompat.setUserAgentMetadata` on Android. Setting only `userAgent` does not suppress `Sec-CH-UA*` headers or `navigator.userAgentData` — `userAgentMetadata` is required for that. Serialized but ignored on iOS/macOS/Linux.

## 1.4.0-beta.3

- Added `PlatformContainerController` class with `getAllContainerNames`, `hasContainer`, `deleteContainer`, `clearContainerData` methods for enumerating, clearing and deleting persistent named storage containers (supported on Android, iOS 17+, macOS 14+, Linux WPE WebKit 2.40+)
- Added `clearContainerData(containerId)`: clears the data inside a container without removing the container itself. Works while WebViews are still bound — `deleteContainer`'s in-use silent no-op no longer blocks "clear site data" flows. Apple's `WKWebsiteDataStore.removeData(ofTypes:modifiedSince:)` and Linux's `webkit_website_data_manager_clear` are single-call comprehensive; Android composes per-subsystem clears on `androidx.webkit.Profile` and is documented as best-effort (HTTP cache + global ServiceWorkerControllerCompat aren't scoped to a profile)
- Added `containerId` property to `InAppWebViewSettings` for joining a named storage container at WebView construction (Android `androidx.webkit.Profile`, iOS 17+ / macOS 14+ `WKWebsiteDataStore(forIdentifier:)`, Linux `WebKitNetworkSession`)
- Added `proxySettings` property to `InAppWebViewSettings` for per-WebView proxy (iOS 17+ / macOS 14+ `WKWebsiteDataStore.proxyConfigurations`)
- Updated `flutter_inappwebview_internal_annotations` dependency from `^1.2.0` to `^1.3.0`
- Added `isClassSupported`, `isPropertySupported`, `isMethodSupported` static methods for all main classes, such as `PlatformInAppWebViewController`, `InAppWebViewSettings`, `PlatformInAppBrowser`, etc., in order to check if a class, property, or method is supported by the platform at runtime
- Added `InAppWebViewSettings.attributionRegistrationBehavior` Android-specific property, the `AttributionBehavior` type and the `WebViewFeature.ATTRIBUTION_REGISTRATION_BEHAVIOR` feature
- Added `InAppWebViewSettings.webViewMediaIntegrityApiStatus` Android-specific property, the `WebViewMediaIntegrityApiStatus` type and the `WebViewFeature.WEBVIEW_MEDIA_INTEGRITY_API_STATUS` feature
- Added `InAppWebViewSettings.backForwardCacheEnabled` Android-specific property and the `WebViewFeature.BACK_FORWARD_CACHE` feature
- Added `isSupported` method to all custom enum classes
- Added `saveState`, `restoreState`, `requestEnterFullscreen`, `requestExitFullscreen`, `setVisible`, `setTargetRefreshRate`, `getTargetRefreshRate`, `requestPointerLock`, `requestPointerUnlock`, `getScreenScale`, `setScreenScale`, `isVisible`, `getFrameId`, `getFavicon`, `showSaveAsUI`, `getMemoryUsageTargetLevel`, `setMemoryUsageTargetLevel` methods to `PlatformInAppWebViewController` class
- Added `useOnAjaxReadyStateChange`, `useOnAjaxProgress`, `useOnShowFileChooser`, `corsAllowlist`, `itpEnabled`, `darkMode`, `disableAnimations`, `fontAntialias`, `fontHintingStyle`, `fontSubpixelLayout`, `fontDPI`, `cursorBlinkTime`, `doubleClickDistance`, `doubleClickTime`, `dragThreshold`, `keyRepeatDelay`, `keyRepeatInterval`, `disableWebSecurity`, `enableWebRTC`, `webRTCUdpPortsRange`, `javaScriptCanAccessClipboard`, `allowModalDialogs`, `enableMedia`, `enableEncryptedMedia`, `enableMediaCapabilities`, `enableMockCaptureDevices`, `mediaContentTypesRequiringHardwareSupport`, `enableJavaScriptMarkup`, `enable2DCanvasAcceleration`, `allowTopNavigationToDataUrls` properties to `InAppWebViewSettings`
- Added `onShowFileChooser`, `onContentLoading`, `onDOMContentLoaded`,  `onLaunchingExternalUriScheme`, `onFaviconChanged`, `onNotificationReceived`, `onSaveAsUIShowing`, `onSaveFileSecurityCheckStarting`, `onScreenCaptureStarting` WebView events
- Added `PlatformWebNotificationController` class
- Update code documentation
- Deprecated `onReceivedIcon` in favor of `onFaviconChanged`

## 1.4.0-beta.2

- Updated `flutter_inappwebview_internal_annotations` dependency from `^1.1.1` to `^1.2.0`
- Updated `fromMap` static method and `toMap` method implementations
- Updated all WebView events with return type `Future` to type `FutureOr` in order to not force the usage of `async` keyword
- Added `byName`, `name`, `asNameMap` custom enum classes methods
- Added `statusBarEnabled`, `browserAcceleratorKeysEnabled`, `generalAutofillEnabled`, `passwordAutosaveEnabled`, `isPinchZoomEnabled`, `hiddenPdfToolbarItems`, `reputationCheckingRequired`, `nonClientRegionSupportEnabled`, `alpha`, `isUserInteractionEnabled`, `handleAcceleratorKeyPressed` properties to `InAppWebViewSettings`
- Added `isInterfaceSupported`, `getProcessInfos`, `getFailureReportFolderPath` methods to `PlatformWebViewEnvironment` class
- Added `isInterfaceSupported`, `setInputMethodEnabled`, `hideInputMethod`, `showInputMethod` methods to `PlatformInAppWebViewController` class
- Added `exclusiveUserDataFolderAccess`, `isCustomCrashReportingEnabled`, `enableTrackingPrevention`, `areBrowserExtensionsEnabled`, `channelSearchKind`, `releaseChannels`, `scrollbarStyle` properties to `WebViewEnvironmentSettings`
- Added `onDownloadStarting` WebView event and deprecated `onDownloadStartRequest` event
- Added `onNewBrowserVersionAvailable`, `onBrowserProcessExited`, `onProcessInfosChanged` events to `PlatformWebViewEnvironment` class
- Added `onAcceleratorKeyPressed` WebView event
- Fixed missing PrintJobOrientation android values

## 1.4.0-beta.1

- Updated static `fromMap` implementation for some classes
- Updated `kJavaScriptHandlerForbiddenNames` list
- Added `PlatformInAppLocalhostServer.onData` parameter to set a custom on data server callback
- Added `javaScriptBridgeEnabled`, `javaScriptBridgeOriginAllowList`, `javaScriptBridgeForMainFrameOnly`, `pluginScriptsOriginAllowList`, `pluginScriptsForMainFrameOnly`, `javaScriptHandlersOriginAllowList`, `javaScriptHandlersForMainFrameOnly`, `scrollMultiplier` InAppWebViewSettings parameters
- Added `setJavaScriptBridgeName`, `getJavaScriptBridgeName` static WebView controller methods
- Added `onProcessFailed` WebView event
- Added `regexToAllowSyncUrlLoading` Android-specific property to `InAppWebViewSettings`
- Added `JavaScriptHandlerFunctionData` type
- Deprecated `JavaScriptHandlerCallback` type in favor of `JavaScriptHandlerFunction` type
- Deprecated `InAppWebViewSettings.forceDark` and `InAppWebViewSettings.forceDarkStrategy` Android-only properties in favor of `InAppWebViewSettings.algorithmicDarkeningAllowed`
- Fixed X509Certificate PEM base64 decoding

## 1.3.0+1

- Fixed `X509Certificate.toMap` method

## 1.3.0

- Added `WebViewEnvironment.customSchemeRegistrations` parameter for Windows
- Added `CustomSchemeRegistration` type
- Updated docs

## 1.2.0

- Updated `Uint8List` conversion inside `fromMap` methods

## 1.1.1

- Updated permission models for Windows platform

## 1.1.0+1

- Updated docs and pubspec.yaml

## 1.1.0

- Added `PlatformWebViewEnvironment` class
- Updates minimum supported SDK version to Flutter 3.24/Dart 3.5.
- Removed unsupported feature `WebViewFeature.SUPPRESS_ERROR_PAGE`

## 1.0.10

- Merged "Added == operator and hashCode to WebUri" [#1941](https://github.com/pichillilorenzo/flutter_inappwebview/pull/1941) (thanks to [daisukeueta](https://github.com/daisukeueta))

## 1.0.9

- Fix typos (thanks to [michalsrutek](https://github.com/michalsrutek))

## 1.0.8

- Added `PlatformCustomPathHandler` class to be able to implement custom path handlers for `WebViewAssetLoader`

## 1.0.7

- Added `InAppBrowser.onMainWindowWillClose` event
- Added `WindowType.WINDOW` for `InAppBrowserSettings.windowType`

## 1.0.6

- Added `InAppWebViewSettings.interceptOnlyAsyncAjaxRequests` [#1905](https://github.com/pichillilorenzo/flutter_inappwebview/issues/1905)
- Added `PlatformInAppWebViewController.clearFormData` method
- Added `PlatformCookieManager.removeSessionCookies` method
- Updated `InAppWebViewSettings.useShouldInterceptAjaxRequest` docs
- Updated `PlatformCookieManager` methods return value

## 1.0.5

- Must call super `dispose` method for `PlatformInAppBrowser` and `PlatformChromeSafariBrowser` 

## 1.0.4

- Expose missing `InAppBrowserSettings.menuButtonColor` option

## 1.0.3

- Expose missing old `AndroidInAppWebViewOptions` and `IOSInAppWebViewOptions` classes

## 1.0.2

- Added `PlatformPrintJobController.onComplete` setter

## 1.0.1

- Updated README 

## 1.0.0

Initial release.
