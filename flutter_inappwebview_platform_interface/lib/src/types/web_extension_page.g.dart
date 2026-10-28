// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_extension_page.dart';

// **************************************************************************
// ExchangeableEnumGenerator
// **************************************************************************

///[WebSpace fork patch] A page of a web extension the host app asks to show
///over the app.
class WebExtensionPage {
  final String _value;
  final String? _nativeValue;
  const WebExtensionPage._internal(this._value, this._nativeValue);
  // ignore: unused_element
  factory WebExtensionPage._internalMultiPlatform(
    String value,
    Function nativeValue,
  ) => WebExtensionPage._internal(value, nativeValue());

  ///The extension's action: its popup, or its click event when it has no
  ///popup.
  static const ACTION = WebExtensionPage._internal('action', 'action');

  ///The extension's options page.
  static const OPTIONS = WebExtensionPage._internal('options', 'options');

  ///Set of all values of [WebExtensionPage].
  static final Set<WebExtensionPage> values = [
    WebExtensionPage.ACTION,
    WebExtensionPage.OPTIONS,
  ].toSet();

  ///Gets a possible [WebExtensionPage] instance from [String] value.
  static WebExtensionPage? fromValue(String? value) {
    if (value != null) {
      try {
        return WebExtensionPage.values.firstWhere(
          (element) => element.toValue() == value,
        );
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  ///Gets a possible [WebExtensionPage] instance from a native value.
  static WebExtensionPage? fromNativeValue(String? value) {
    if (value != null) {
      try {
        return WebExtensionPage.values.firstWhere(
          (element) => element.toNativeValue() == value,
        );
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Gets a possible [WebExtensionPage] instance value with name [name].
  ///
  /// Goes through [WebExtensionPage.values] looking for a value with
  /// name [name], as reported by [WebExtensionPage.name].
  /// Returns the first value with the given name, otherwise `null`.
  static WebExtensionPage? byName(String? name) {
    if (name != null) {
      try {
        return WebExtensionPage.values.firstWhere(
          (element) => element.name() == name,
        );
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Creates a map from the names of [WebExtensionPage] values to the values.
  ///
  /// The collection that this method is called on is expected to have
  /// values with distinct names, like the `values` list of an enum class.
  /// Only one value for each name can occur in the created map,
  /// so if two or more values have the same name (either being the
  /// same value, or being values of different enum type), at most one of
  /// them will be represented in the returned map.
  static Map<String, WebExtensionPage> asNameMap() =>
      <String, WebExtensionPage>{
        for (final value in WebExtensionPage.values) value.name(): value,
      };

  ///Gets [String] value.
  String toValue() => _value;

  ///Gets [String] native value if supported by the current platform, otherwise `null`.
  String? toNativeValue() => _nativeValue;

  ///Gets the name of the value.
  String name() {
    switch (_value) {
      case 'action':
        return 'ACTION';
      case 'options':
        return 'OPTIONS';
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
    return _value;
  }
}
