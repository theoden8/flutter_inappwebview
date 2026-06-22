// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attribution_behavior.dart';

// **************************************************************************
// ExchangeableEnumGenerator
// **************************************************************************

///Class used to indicate how a WebView handles the registration of
///[Attribution Reporting API](https://developer.android.com/design-for-safety/privacy-sandbox/attribution) sources and triggers.
class AttributionBehavior {
  final int _value;
  final int? _nativeValue;
  const AttributionBehavior._internal(this._value, this._nativeValue);
  // ignore: unused_element
  factory AttributionBehavior._internalMultiPlatform(
    int value,
    Function nativeValue,
  ) => AttributionBehavior._internal(value, nativeValue());

  ///The WebView will register attribution sources and triggers as if they came
  ///from the app.
  static const APP_SOURCE_AND_APP_TRIGGER = AttributionBehavior._internal(3, 3);

  ///The WebView will register attribution sources as if they came from the app
  ///and attribution triggers as if they came from the web. This is the default.
  static const APP_SOURCE_AND_WEB_TRIGGER = AttributionBehavior._internal(1, 1);

  ///The WebView will not register any attribution sources or triggers.
  static const DISABLED = AttributionBehavior._internal(0, 0);

  ///The WebView will register attribution sources and triggers as if they came
  ///from the web.
  static const WEB_SOURCE_AND_WEB_TRIGGER = AttributionBehavior._internal(2, 2);

  ///Set of all values of [AttributionBehavior].
  static final Set<AttributionBehavior> values = [
    AttributionBehavior.APP_SOURCE_AND_APP_TRIGGER,
    AttributionBehavior.APP_SOURCE_AND_WEB_TRIGGER,
    AttributionBehavior.DISABLED,
    AttributionBehavior.WEB_SOURCE_AND_WEB_TRIGGER,
  ].toSet();

  ///Gets a possible [AttributionBehavior] instance from [int] value.
  static AttributionBehavior? fromValue(int? value) {
    if (value != null) {
      try {
        return AttributionBehavior.values.firstWhere(
          (element) => element.toValue() == value,
        );
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  ///Gets a possible [AttributionBehavior] instance from a native value.
  static AttributionBehavior? fromNativeValue(int? value) {
    if (value != null) {
      try {
        return AttributionBehavior.values.firstWhere(
          (element) => element.toNativeValue() == value,
        );
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Gets a possible [AttributionBehavior] instance value with name [name].
  ///
  /// Goes through [AttributionBehavior.values] looking for a value with
  /// name [name], as reported by [AttributionBehavior.name].
  /// Returns the first value with the given name, otherwise `null`.
  static AttributionBehavior? byName(String? name) {
    if (name != null) {
      try {
        return AttributionBehavior.values.firstWhere(
          (element) => element.name() == name,
        );
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Creates a map from the names of [AttributionBehavior] values to the values.
  ///
  /// The collection that this method is called on is expected to have
  /// values with distinct names, like the `values` list of an enum class.
  /// Only one value for each name can occur in the created map,
  /// so if two or more values have the same name (either being the
  /// same value, or being values of different enum type), at most one of
  /// them will be represented in the returned map.
  static Map<String, AttributionBehavior> asNameMap() =>
      <String, AttributionBehavior>{
        for (final value in AttributionBehavior.values) value.name(): value,
      };

  ///Gets [int] value.
  int toValue() => _value;

  ///Gets [int] native value if supported by the current platform, otherwise `null`.
  int? toNativeValue() => _nativeValue;

  ///Gets the name of the value.
  String name() {
    switch (_value) {
      case 3:
        return 'APP_SOURCE_AND_APP_TRIGGER';
      case 1:
        return 'APP_SOURCE_AND_WEB_TRIGGER';
      case 0:
        return 'DISABLED';
      case 2:
        return 'WEB_SOURCE_AND_WEB_TRIGGER';
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
