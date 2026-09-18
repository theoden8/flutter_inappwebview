## Unreleased (WebSpace fork)

- [WebSpace fork patch] `InAppWebViewSettings.userAgentMetadata` is serialized through to native but WPE has no UA-CH plumbing and the setting is silently ignored. Kept so backup JSON stays portable across platforms.
- [WebSpace fork patch] `InAppWebViewSettings.disableAnimations` now resolves its WPEPlatform key at compile time: WPE 2.54 renamed `WPE_SETTING_DISABLE_ANIMATIONS` to `WPE_SETTING_REDUCED_MOTION` and dropped the old macro, which broke the build on any WPEPlatform-enabled 2.54 toolchain (Debian sid's wpewebkit 2.54.0-1 is the first to ship `wpe-platform-2.0.pc`).

## 0.1.0-beta.2

- Implemented `PlatformContainerController` (`getAllContainerNames`, `hasContainer`, `deleteContainer`, `clearContainerData`) backed by `<XDG_DATA_HOME>/flutter_inappwebview/containers/` and `<XDG_CACHE_HOME>/flutter_inappwebview/containers/`. `clearContainerData` calls `webkit_website_data_manager_clear(WEBKIT_WEBSITE_DATA_ALL, 0, …)` on the container's cached `WebKitNetworkSession`; returns false when the container hasn't been joined yet this process (no live session to clear — use `deleteContainer` for that case).
- Implemented per-WebView container join via `InAppWebViewSettings.containerId`. Wires a process-wide cached `WebKitNetworkSession` with the container's data and cache directories at `webkit_web_view_new` time. Multiple WebViews joining the same container share storage. Honored on WPE WebKit 2.40+.
- Implemented per-container proxy via `InAppWebViewSettings.proxySettings`. The proxy is pinned to the container before its `WebKitNetworkSession` is created, so it is in place before the container's first request, and a pinned container is excluded from `ProxyController.setProxyOverride`'s fan-out — two containers can hold two different proxies at once. Requires a `containerId`: a WebView without one shares the default session, where a per-WebView proxy would change every other WebView, so it is ignored there. Honored on WPE WebKit 2.40+.
- `ProxyController.setProxyOverride` / `clearProxyOverride` apply to every container `WebKitNetworkSession` as well as the default one, including containers joined after the override was set, so a contained WebView can't silently bypass a process-wide proxy.

## 0.1.0-beta.1

- Initial release.
