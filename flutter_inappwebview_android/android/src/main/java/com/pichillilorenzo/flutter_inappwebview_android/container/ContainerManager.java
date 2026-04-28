package com.pichillilorenzo.flutter_inappwebview_android.container;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.webkit.Profile;
import androidx.webkit.ProfileStore;
import androidx.webkit.WebViewFeature;

import com.pichillilorenzo.flutter_inappwebview_android.InAppWebViewFlutterPlugin;
import com.pichillilorenzo.flutter_inappwebview_android.types.ChannelDelegateImpl;

import java.util.Collections;
import java.util.List;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

// MethodChannel handler for the per-WebView profile controller. Wraps
// androidx.webkit.ProfileStore — gated on WebViewFeature.MULTI_PROFILE
// (System WebView 110+). On unsupported devices every method returns
// the empty/false fallback so callers get a consistent answer rather
// than an exception.
public class ContainerManager extends ChannelDelegateImpl {
  protected static final String LOG_TAG = "ContainerManager";
  public static final String METHOD_CHANNEL_NAME =
      "com.pichillilorenzo/flutter_inappwebview_containercontroller";

  @Nullable
  public InAppWebViewFlutterPlugin plugin;

  public ContainerManager(@NonNull final InAppWebViewFlutterPlugin plugin) {
    super(new MethodChannel(plugin.messenger, METHOD_CHANNEL_NAME));
    this.plugin = plugin;
  }

  private static boolean isMultiProfileSupported() {
    return WebViewFeature.isFeatureSupported(WebViewFeature.MULTI_PROFILE);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    switch (call.method) {
      case "getAllContainerNames":
        if (!isMultiProfileSupported()) {
          result.success(Collections.emptyList());
          return;
        }
        try {
          List<String> names = ProfileStore.getInstance().getAllProfileNames();
          result.success(names != null ? names : Collections.emptyList());
        } catch (Throwable t) {
          result.error("CONTAINER_LIST_FAILED", t.getMessage(), null);
        }
        break;
      case "hasContainer": {
        String containerId = (String) call.argument("containerId");
        if (containerId == null || containerId.isEmpty() || !isMultiProfileSupported()) {
          result.success(false);
          return;
        }
        try {
          List<String> names = ProfileStore.getInstance().getAllProfileNames();
          result.success(names != null && names.contains(containerId));
        } catch (Throwable t) {
          result.error("CONTAINER_HAS_FAILED", t.getMessage(), null);
        }
        break;
      }
      case "deleteContainer": {
        String containerId = (String) call.argument("containerId");
        if (containerId == null || containerId.isEmpty() || !isMultiProfileSupported()) {
          result.success(false);
          return;
        }
        // The default profile cannot be deleted; deleting a profile in
        // use by a live WebView throws IllegalStateException. We surface
        // those as success(false) rather than an error — the contract
        // of deleteProfile is "true when it actually deleted something".
        if (Profile.DEFAULT_PROFILE_NAME.equals(containerId)) {
          result.success(false);
          return;
        }
        try {
          boolean deleted = ProfileStore.getInstance().deleteProfile(containerId);
          result.success(deleted);
        } catch (IllegalStateException inUse) {
          result.success(false);
        } catch (Throwable t) {
          result.error("CONTAINER_DELETE_FAILED", t.getMessage(), null);
        }
        break;
      }
      default:
        result.notImplemented();
    }
  }

  @Override
  public void dispose() {
    super.dispose();
    plugin = null;
  }
}
