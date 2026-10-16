#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_CONTENT_RULE_LIST_STORE_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_CONTENT_RULE_LIST_STORE_H_

#include <flutter_linux/flutter_linux.h>
#include <wpe/webkit.h>

#include "../types/channel_delegate.h"

namespace flutter_inappwebview_plugin {

class PluginInstance;

/**
 * [WebSpace fork patch] The store of content rule lists a host app compiles
 * once and every WebView attaches by identifier (the
 * `contentRuleListIdentifiers` setting). WPE has no default store like
 * `WKContentRuleListStore.default()`, so this is the one every WebView and
 * the channel below read; null when its directory could not be opened.
 */
WebKitUserContentFilterStore* content_rule_list_store();

/**
 * [WebSpace fork patch] What the host app compiles into, lists and removes
 * from content_rule_list_store(): `identifiers`, `compile` {identifier, json}
 * and `remove` {identifier}, answered as the Apple hosts answer the same
 * calls against `WKContentRuleListStore.default()`.
 */
class ContentRuleListStoreChannel : public ChannelDelegate {
 public:
  static constexpr const char* METHOD_CHANNEL_NAME =
      "com.pichillilorenzo/flutter_inappwebview_content_rule_list_store";

  explicit ContentRuleListStoreChannel(PluginInstance* plugin);
  ~ContentRuleListStoreChannel() override;

  void HandleMethodCall(FlMethodCall* method_call) override;
};

}  // namespace flutter_inappwebview_plugin

#endif  // FLUTTER_INAPPWEBVIEW_PLUGIN_CONTENT_RULE_LIST_STORE_H_
