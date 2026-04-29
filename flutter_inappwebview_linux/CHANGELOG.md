## 0.1.0-beta.2

- Implemented `PlatformContainerController` (`getAllContainerNames`, `hasContainer`, `deleteContainer`) backed by `<XDG_DATA_HOME>/flutter_inappwebview/containers/` and `<XDG_CACHE_HOME>/flutter_inappwebview/containers/`.
- Implemented per-WebView container join via `InAppWebViewSettings.containerId`. Wires a process-wide cached `WebKitNetworkSession` with the container's data and cache directories at `webkit_web_view_new` time. Multiple WebViews joining the same container share storage. Honored on WPE WebKit 2.40+.

## 0.1.0-beta.1

- Initial release.
