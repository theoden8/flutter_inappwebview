## 0.1.0-beta.2

- Implemented `PlatformContainerController` (`getAllContainerNames`, `hasContainer`, `deleteContainer`, `clearContainerData`) and `InAppWebViewSettings.containerId` via per-container `WebKitNetworkSession`s (WPE WebKit 2.40+)
- Implemented `InAppWebViewSettings.proxySettings` for WebViews with a `containerId`
- `ProxyController.setProxyOverride` and `clearProxyOverride` also apply to container sessions; a rule set with no usable proxy is refused

## 0.1.0-beta.1

- Initial release.
