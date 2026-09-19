#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_PROXY_MANAGER_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_PROXY_MANAGER_H_

#include <flutter_linux/flutter_linux.h>
#include <wpe/webkit.h>

#include <memory>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

#include "types/channel_delegate.h"

namespace flutter_inappwebview_plugin {

class PluginInstance;

/**
 * Represents a proxy rule with URL and optional scheme filter.
 */
struct ProxyRule {
  std::string url;
  std::optional<std::string> schemeFilter;  // "HTTP", "HTTPS", or nullopt for all

  ProxyRule() = default;
  ProxyRule(const std::string& url, std::optional<std::string> schemeFilter = std::nullopt)
      : url(url), schemeFilter(schemeFilter) {}
  ProxyRule(FlValue* map);
};

/**
 * Represents proxy settings configuration.
 */
struct ProxySettings {
  std::vector<std::string> bypassRules;
  std::vector<ProxyRule> proxyRules;

  ProxySettings() = default;
  ProxySettings(FlValue* map);
};

/**
 * Manages proxy settings for WPE WebKit.
 * Uses WebKitNetworkProxySettings and WebKitNetworkSession for proxy configuration.
 */
class ProxyManager : public ChannelDelegate {
 public:
  static constexpr const char* METHOD_CHANNEL_NAME =
      "com.pichillilorenzo/flutter_inappwebview_proxycontroller";

  ProxyManager(PluginInstance* plugin);
  ~ProxyManager() override;

  /// Get the plugin instance
  PluginInstance* plugin() const { return plugin_; }

  void HandleMethodCall(FlMethodCall* method_call) override;

  /**
   * Set proxy override with the given settings.
   * This applies proxy settings to the default network session.
   */
  void setProxyOverride(const ProxySettings& settings);

  /**
   * Clear proxy override and revert to system defaults.
   */
  void clearProxyOverride();

 private:
  PluginInstance* plugin_ = nullptr;
};

/**
 * Applies the active process-wide proxy override, if any, to a single
 * network session.
 *
 * setProxyOverride can only reach the sessions that exist when it runs, but
 * a container session is created lazily, the first time a WebView joins
 * that container. A session created afterwards starts in
 * WEBKIT_NETWORK_PROXY_MODE_DEFAULT (system proxy), so without this hook the
 * contained WebView would silently bypass the proxy the caller asked the
 * platform to apply process-wide. Called by get_or_create_container_session.
 */
void apply_active_proxy_override(WebKitNetworkSession* session);

/**
 * Per-container proxy pins, keyed by containerId.
 *
 * WPE applies a proxy to one `WebKitNetworkSession`, and every container owns
 * one, so unlike Apple's `WKWebsiteDataStore.proxyConfigurations` two
 * containers really can hold two different proxies at the same time
 * (BUG-014). A pin records that a container's proxy is the site's own choice
 * rather than the process-wide override, so the fan-out below leaves it
 * alone.
 */
std::unordered_map<std::string, ProxySettings>& container_proxy_pins();

/**
 * Pin `id`'s session to `settings` and apply it if that session already
 * exists. Called at WebView construction, before the session is created, so
 * the proxy is in place before the container's first request.
 */
void pin_container_proxy(const std::string& id, const ProxySettings& settings);

/**
 * Apply whichever proxy `id` should be on: its own pin if it has one, else
 * the process-wide override. Called by get_or_create_container_session.
 */
void apply_container_proxy(const std::string& id,
                           WebKitNetworkSession* session);

}  // namespace flutter_inappwebview_plugin

#endif  // FLUTTER_INAPPWEBVIEW_PLUGIN_PROXY_MANAGER_H_
