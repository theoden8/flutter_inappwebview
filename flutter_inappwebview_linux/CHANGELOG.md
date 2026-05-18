## 0.1.0-beta.2

- Implemented `PlatformContainerController` (`getAllContainerNames`, `hasContainer`, `deleteContainer`, `clearContainerData`) backed by `<XDG_DATA_HOME>/flutter_inappwebview/containers/` and `<XDG_CACHE_HOME>/flutter_inappwebview/containers/`. `clearContainerData` calls `webkit_website_data_manager_clear(WEBKIT_WEBSITE_DATA_ALL, 0, …)` on the container's cached `WebKitNetworkSession`; returns false when the container hasn't been joined yet this process (no live session to clear — use `deleteContainer` for that case).
- Implemented per-WebView container join via `InAppWebViewSettings.containerId`. Wires a process-wide cached `WebKitNetworkSession` with the container's data and cache directories at `webkit_web_view_new` time. Multiple WebViews joining the same container share storage. Honored on WPE WebKit 2.40+.

## 0.1.0-beta.1

- Initial release.
