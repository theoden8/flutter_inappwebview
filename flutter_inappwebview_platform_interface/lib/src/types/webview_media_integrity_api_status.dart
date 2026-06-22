import 'package:flutter_inappwebview_internal_annotations/flutter_inappwebview_internal_annotations.dart';

part 'webview_media_integrity_api_status.g.dart';

///Class used to indicate the default status of the
///[WebView Media Integrity API](https://developer.android.com/privacy-and-security/webview-media-integrity-api).
@ExchangeableEnum()
class WebViewMediaIntegrityApiStatus_ {
  // ignore: unused_field
  final int _value;
  const WebViewMediaIntegrityApiStatus_._internal(this._value);

  ///The WebView Media Integrity API is disabled.
  static const DISABLED = const WebViewMediaIntegrityApiStatus_._internal(0);

  ///The WebView Media Integrity API is enabled, but the integrity token does
  ///not include the embedding app's package name and signing identity.
  static const ENABLED_WITHOUT_APP_IDENTITY =
      const WebViewMediaIntegrityApiStatus_._internal(1);

  ///The WebView Media Integrity API is enabled. This is the default.
  static const ENABLED = const WebViewMediaIntegrityApiStatus_._internal(2);
}
