// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webview_media_integrity_api_status.dart';

// **************************************************************************
// ExchangeableEnumGenerator
// **************************************************************************

///Class used to indicate the default status of the
///[WebView Media Integrity API](https://developer.android.com/privacy-and-security/webview-media-integrity-api).
class WebViewMediaIntegrityApiStatus {
  final int _value;
  final int? _nativeValue;
  const WebViewMediaIntegrityApiStatus._internal(
    this._value,
    this._nativeValue,
  );
  // ignore: unused_element
  factory WebViewMediaIntegrityApiStatus._internalMultiPlatform(
    int value,
    Function nativeValue,
  ) => WebViewMediaIntegrityApiStatus._internal(value, nativeValue());

  ///The WebView Media Integrity API is disabled.
  static const DISABLED = WebViewMediaIntegrityApiStatus._internal(0, 0);

  ///The WebView Media Integrity API is enabled. This is the default.
  static const ENABLED = WebViewMediaIntegrityApiStatus._internal(2, 2);

  ///The WebView Media Integrity API is enabled, but the integrity token does
  ///not include the embedding app's package name and signing identity.
  static const ENABLED_WITHOUT_APP_IDENTITY =
      WebViewMediaIntegrityApiStatus._internal(1, 1);

  ///Set of all values of [WebViewMediaIntegrityApiStatus].
  static final Set<WebViewMediaIntegrityApiStatus> values = [
    WebViewMediaIntegrityApiStatus.DISABLED,
    WebViewMediaIntegrityApiStatus.ENABLED,
    WebViewMediaIntegrityApiStatus.ENABLED_WITHOUT_APP_IDENTITY,
  ].toSet();

  ///Gets a possible [WebViewMediaIntegrityApiStatus] instance from [int] value.
  static WebViewMediaIntegrityApiStatus? fromValue(int? value) {
    if (value != null) {
      try {
        return WebViewMediaIntegrityApiStatus.values.firstWhere(
          (element) => element.toValue() == value,
        );
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  ///Gets a possible [WebViewMediaIntegrityApiStatus] instance from a native value.
  static WebViewMediaIntegrityApiStatus? fromNativeValue(int? value) {
    if (value != null) {
      try {
        return WebViewMediaIntegrityApiStatus.values.firstWhere(
          (element) => element.toNativeValue() == value,
        );
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Gets a possible [WebViewMediaIntegrityApiStatus] instance value with name [name].
  ///
  /// Goes through [WebViewMediaIntegrityApiStatus.values] looking for a value with
  /// name [name], as reported by [WebViewMediaIntegrityApiStatus.name].
  /// Returns the first value with the given name, otherwise `null`.
  static WebViewMediaIntegrityApiStatus? byName(String? name) {
    if (name != null) {
      try {
        return WebViewMediaIntegrityApiStatus.values.firstWhere(
          (element) => element.name() == name,
        );
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Creates a map from the names of [WebViewMediaIntegrityApiStatus] values to the values.
  ///
  /// The collection that this method is called on is expected to have
  /// values with distinct names, like the `values` list of an enum class.
  /// Only one value for each name can occur in the created map,
  /// so if two or more values have the same name (either being the
  /// same value, or being values of different enum type), at most one of
  /// them will be represented in the returned map.
  static Map<String, WebViewMediaIntegrityApiStatus> asNameMap() =>
      <String, WebViewMediaIntegrityApiStatus>{
        for (final value in WebViewMediaIntegrityApiStatus.values)
          value.name(): value,
      };

  ///Gets [int] value.
  int toValue() => _value;

  ///Gets [int] native value if supported by the current platform, otherwise `null`.
  int? toNativeValue() => _nativeValue;

  ///Gets the name of the value.
  String name() {
    switch (_value) {
      case 0:
        return 'DISABLED';
      case 2:
        return 'ENABLED';
      case 1:
        return 'ENABLED_WITHOUT_APP_IDENTITY';
    }
    return _value.toString();
  }

  @override
  int get hashCode => _value.hashCode;

  @override
  bool operator ==(value) => value == _value;

  ///Checks if the value is supported by the [defaultTargetPlatform].
  bool isSupported() {
    return _nativeValue != null;
  }

  @override
  String toString() {
    return name();
  }
}
