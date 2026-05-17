#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_NAVIGATION_ACTION_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_NAVIGATION_ACTION_H_

#include <flutter_linux/flutter_linux.h>

#include <memory>
#include <optional>

#include "url_request.h"

namespace flutter_inappwebview_plugin {

// Values must match NavigationType native values in
// flutter_inappwebview_platform_interface/lib/src/types/navigation_type.g.dart
// (TargetPlatform.linux branch). The scheme mirrors WKNavigationType
// (Apple WebKit), so OTHER is -1 not 5 as WebKitGTK uses.
enum class NavigationActionType {
  linkActivated = 0,
  formSubmitted = 1,
  backForward = 2,
  reload = 3,
  formResubmitted = 4,
  other = -1
};

inline std::optional<int64_t> NavigationActionTypeToInteger(
    const std::optional<NavigationActionType>& action) {
  return action.has_value() ? static_cast<int64_t>(action.value()) : std::optional<int64_t>{};
}

class NavigationAction {
 public:
  const std::shared_ptr<URLRequest> request;
  const bool isForMainFrame;
  const std::optional<bool> isRedirect;
  const std::optional<NavigationActionType> navigationType;
  const bool hasGesture;

  NavigationAction(std::shared_ptr<URLRequest> request, bool isForMainFrame,
                   const std::optional<bool>& isRedirect,
                   const std::optional<NavigationActionType>& navigationType,
                   bool hasGesture);
  ~NavigationAction() = default;

  FlValue* toFlValue() const;
};

}  // namespace flutter_inappwebview_plugin

#endif  // FLUTTER_INAPPWEBVIEW_PLUGIN_NAVIGATION_ACTION_H_
