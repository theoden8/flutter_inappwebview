## Unreleased (WebSpace fork)

- [WebSpace fork patch] `InAppWebViewSettings.userAgentMetadata` is serialized through to native but WPE has no UA-CH plumbing and the setting is silently ignored. Kept so backup JSON stays portable across platforms.
- [WebSpace fork patch] `InAppWebViewSettings.disableAnimations` now resolves its WPEPlatform key at compile time: WPE 2.54 renamed `WPE_SETTING_DISABLE_ANIMATIONS` to `WPE_SETTING_REDUCED_MOTION` and dropped the old macro, which broke the build on any WPEPlatform-enabled 2.54 toolchain (Debian sid's wpewebkit 2.54.0-1 is the first to ship `wpe-platform-2.0.pc`). Headers defining neither key skip the setting instead of failing to build.

## 0.1.0-beta.2

- Implemented `PlatformContainerController` (`getAllContainerNames`, `hasContainer`, `deleteContainer`, `clearContainerData`) and `InAppWebViewSettings.containerId` via per-container `WebKitNetworkSession`s (WPE WebKit 2.40+)
- Implemented `InAppWebViewSettings.proxySettings` for WebViews with a `containerId`
- `ProxyController.setProxyOverride` and `clearProxyOverride` also apply to container sessions; a rule set with no usable proxy is refused
- Proxy rule URLs without a scheme are treated as `http://`, as on Android, instead of leaving requests unproxied
- Fixed `onReceivedHttpAuthRequest` never reaching the app: the challenge's `previousFailureCount` was `null`. It is now `0` for a first challenge and `1` for a retry, as WPE WebKit only reports whether a request is a retry
- Fixed HTTP auth responses always cancelling the request: `HttpAuthResponseAction` had no Linux values, so `PROCEED` and `USE_SAVED_HTTP_AUTH_CREDENTIALS` were sent as `null` (fixed in flutter_inappwebview_platform_interface)
- Fixed `onReceivedServerTrustAuthRequest` never reaching the app: `SslError.code` was sent as a string. It is now the `GTlsCertificateFlags` value that `SslErrorType` maps on Linux
- Fixed `ServerTrustAuthResponseAction.PROCEED` not retrying the load that failed the server trust check, and a use-after-free of its URL

## 0.1.0-beta.1

- Initial release.
