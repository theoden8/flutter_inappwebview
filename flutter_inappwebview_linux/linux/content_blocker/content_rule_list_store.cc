#include "content_rule_list_store.h"

#include <cstring>
#include <filesystem>
#include <string>
#include <system_error>

#include "../plugin_instance.h"
#include "../utils/flutter.h"
#include "../utils/log.h"
#include "../utils/util.h"

namespace flutter_inappwebview_plugin {

WebKitUserContentFilterStore* content_rule_list_store() {
  static WebKitUserContentFilterStore* store = [] {
    const auto path = std::filesystem::path(g_get_user_data_dir()) /
                      "flutter_inappwebview" /
                      resolve_application_id_sanitized() / "content_rule_lists";
    std::error_code ec;
    std::filesystem::create_directories(path, ec);
    if (ec) {
      errorLog("ContentRuleListStore: cannot create " + path.string() + ": " +
               ec.message());
      return static_cast<WebKitUserContentFilterStore*>(nullptr);
    }
    return webkit_user_content_filter_store_new(path.c_str());
  }();
  return store;
}

namespace {

void respond_store_error(FlMethodCall* call, const char* code, GError* error) {
  fl_method_call_respond_error(call, code, error->message, nullptr, nullptr);
  g_error_free(error);
}

void on_identifiers(GObject* source, GAsyncResult* result, gpointer user_data) {
  auto* call = static_cast<FlMethodCall*>(user_data);
  gchar** identifiers = webkit_user_content_filter_store_fetch_identifiers_finish(
      WEBKIT_USER_CONTENT_FILTER_STORE(source), result);
  g_autoptr(FlValue) list = fl_value_new_list();
  for (gchar** it = identifiers; it != nullptr && *it != nullptr; ++it) {
    fl_value_append_take(list, fl_value_new_string(*it));
  }
  g_strfreev(identifiers);
  fl_method_call_respond_success(call, list, nullptr);
  g_object_unref(call);
}

void on_compiled(GObject* source, GAsyncResult* result, gpointer user_data) {
  auto* call = static_cast<FlMethodCall*>(user_data);
  GError* error = nullptr;
  WebKitUserContentFilter* filter = webkit_user_content_filter_store_save_finish(
      WEBKIT_USER_CONTENT_FILTER_STORE(source), result, &error);
  if (filter != nullptr) {
    webkit_user_content_filter_unref(filter);
  }
  if (error != nullptr) {
    respond_store_error(call, "compile_failed", error);
  } else {
    fl_method_call_respond_success(call, nullptr, nullptr);
  }
  g_object_unref(call);
}

void on_removed(GObject* source, GAsyncResult* result, gpointer user_data) {
  auto* call = static_cast<FlMethodCall*>(user_data);
  GError* error = nullptr;
  webkit_user_content_filter_store_remove_finish(
      WEBKIT_USER_CONTENT_FILTER_STORE(source), result, &error);
  if (error != nullptr) {
    respond_store_error(call, "remove_failed", error);
  } else {
    fl_method_call_respond_success(call, nullptr, nullptr);
  }
  g_object_unref(call);
}

}  // namespace

ContentRuleListStoreChannel::ContentRuleListStoreChannel(PluginInstance* plugin)
    : ChannelDelegate(plugin->messenger(), METHOD_CHANNEL_NAME) {}

ContentRuleListStoreChannel::~ContentRuleListStoreChannel() {
  debugLog("dealloc ContentRuleListStoreChannel");
}

void ContentRuleListStoreChannel::HandleMethodCall(FlMethodCall* method_call) {
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);
  WebKitUserContentFilterStore* store = content_rule_list_store();
  if (store == nullptr) {
    fl_method_call_respond_error(method_call, "store_unavailable",
                                 "the content rule list store could not be opened",
                                 nullptr, nullptr);
    return;
  }

  if (strcmp(method, "identifiers") == 0) {
    webkit_user_content_filter_store_fetch_identifiers(
        store, nullptr, on_identifiers, g_object_ref(method_call));
    return;
  }

  if (strcmp(method, "compile") == 0) {
    std::string identifier = get_fl_map_value<std::string>(args, "identifier", "");
    std::string json = get_fl_map_value<std::string>(args, "json", "");
    if (identifier.empty() || json.empty()) {
      fl_method_call_respond_error(method_call, "bad_arguments",
                                   "compile is missing an argument", nullptr, nullptr);
      return;
    }
    g_autoptr(GBytes) source = g_bytes_new(json.data(), json.size());
    webkit_user_content_filter_store_save(store, identifier.c_str(), source, nullptr,
                                          on_compiled, g_object_ref(method_call));
    return;
  }

  if (strcmp(method, "remove") == 0) {
    std::string identifier = get_fl_map_value<std::string>(args, "identifier", "");
    if (identifier.empty()) {
      fl_method_call_respond_error(method_call, "bad_arguments",
                                   "remove is missing an argument", nullptr, nullptr);
      return;
    }
    webkit_user_content_filter_store_remove(store, identifier.c_str(), nullptr,
                                            on_removed, g_object_ref(method_call));
    return;
  }

  fl_method_call_respond_not_implemented(method_call, nullptr);
}

}  // namespace flutter_inappwebview_plugin
