#include "container_manager.h"

#include <cstring>
#include <filesystem>
#include <string>
#include <system_error>

#include "container_session_cache.h"
#include "plugin_instance.h"
#include "utils/flutter.h"
#include "utils/log.h"

namespace flutter_inappwebview_plugin {

namespace {

bool string_equals(const gchar* a, const char* b) {
  return strcmp(a, b) == 0;
}

}  // namespace

ContainerManager::ContainerManager(PluginInstance* plugin)
    : ChannelDelegate(plugin->messenger(), METHOD_CHANNEL_NAME),
      plugin_(plugin) {}

ContainerManager::~ContainerManager() {
  debugLog("dealloc ContainerManager");
  plugin_ = nullptr;
}

void ContainerManager::HandleMethodCall(FlMethodCall* method_call) {
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (string_equals(method, "getAllContainerNames")) {
    g_autoptr(FlValue) result = fl_value_new_list();
    std::error_code ec;
    const auto root = container_data_root();
    if (std::filesystem::exists(root, ec)) {
      for (const auto& entry : std::filesystem::directory_iterator(root, ec)) {
        if (entry.is_directory(ec)) {
          fl_value_append_take(
              result, fl_value_new_string(entry.path().filename().c_str()));
        }
      }
    }
    fl_method_call_respond_success(method_call, result, nullptr);
    return;
  }

  if (string_equals(method, "hasContainer")) {
    std::string id = get_fl_map_value<std::string>(args, "containerId", "");
    std::error_code ec;
    bool exists = !id.empty() &&
                  std::filesystem::is_directory(container_data_root() / id, ec);
    g_autoptr(FlValue) result = fl_value_new_bool(exists);
    fl_method_call_respond_success(method_call, result, nullptr);
    return;
  }

  if (string_equals(method, "deleteContainer")) {
    std::string id = get_fl_map_value<std::string>(args, "containerId", "");
    if (id.empty()) {
      g_autoptr(FlValue) result = fl_value_new_bool(false);
      fl_method_call_respond_success(method_call, result, nullptr);
      return;
    }
    std::error_code ec1, ec2;
    const auto data_dir = container_data_root() / id;
    const auto cache_dir = container_cache_root() / id;
    bool data_existed = std::filesystem::exists(data_dir, ec1);
    bool cache_existed = std::filesystem::exists(cache_dir, ec1);
    std::filesystem::remove_all(data_dir, ec1);
    std::filesystem::remove_all(cache_dir, ec2);
    bool deleted = (data_existed || cache_existed) && !ec1 && !ec2;
    g_autoptr(FlValue) result = fl_value_new_bool(deleted);
    fl_method_call_respond_success(method_call, result, nullptr);
    return;
  }

  fl_method_call_respond_not_implemented(method_call, nullptr);
}

}  // namespace flutter_inappwebview_plugin
