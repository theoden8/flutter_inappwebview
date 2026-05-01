// [WebSpace fork patch] User-Agent Client Hints metadata wrapper.
// Wires through to androidx.webkit's WebSettingsCompat.setUserAgentMetadata
// on Android. No-op on iOS/macOS/Linux for now (no equivalent native API exists).
// Mirrors androidx.webkit.UserAgentMetadata 1:1 so the platform-channel payload
// can be consumed by buildUserAgentMetadata in InAppWebView.java.

import 'enum_method.dart';

///[WebSpace fork patch] Per-brand User-Agent Client Hints entry.
///
///Backs the `Sec-CH-UA`, `Sec-CH-UA-Full-Version-List` HTTP request headers
///and the `navigator.userAgentData.brands` JS array.
class BrandVersion {
  ///The brand name, e.g. `"Chromium"` or `"Google Chrome"`.
  String brand;

  ///The brand's major version, e.g. `"133"`. Sent in `Sec-CH-UA`.
  String majorVersion;

  ///The brand's full version, e.g. `"133.0.6943.137"`.
  ///Sent in `Sec-CH-UA-Full-Version-List`.
  String fullVersion;

  BrandVersion({
    required this.brand,
    required this.majorVersion,
    required this.fullVersion,
  });

  ///Gets a possible [BrandVersion] instance from a [Map] value.
  static BrandVersion? fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return null;
    }
    return BrandVersion(
      brand: map['brand'] as String,
      majorVersion: map['majorVersion'] as String,
      fullVersion: map['fullVersion'] as String,
    );
  }

  ///Converts instance to a map.
  Map<String, dynamic> toMap() {
    return {
      'brand': brand,
      'majorVersion': majorVersion,
      'fullVersion': fullVersion,
    };
  }

  ///Converts instance to a map.
  Map<String, dynamic> toJson() => toMap();

  @override
  String toString() {
    return 'BrandVersion{brand: $brand, majorVersion: $majorVersion, fullVersion: $fullVersion}';
  }
}

///[WebSpace fork patch] User-Agent Client Hints metadata.
///
///Maps to `androidx.webkit.UserAgentMetadata` (added in androidx.webkit 1.8.0,
///gated by `WebViewFeature.USER_AGENT_METADATA`). Setting this is the only
///supported way to override `Sec-CH-UA*` HTTP request headers and the
///`navigator.userAgentData` JS surface on Android WebView. Setting only
///`InAppWebViewSettings.userAgent` does NOT suppress these — Chromium still
///emits the real engine + OS values via UA-CH.
///
///No-op on iOS/macOS/Linux: WKWebView has no equivalent API and WPE has no
///UA-CH plumbing. The setting is still serialized so backup JSON stays
///portable across platforms.
class UserAgentMetadata {
  ///List of [BrandVersion] entries. Backs `Sec-CH-UA`,
  ///`Sec-CH-UA-Full-Version-List`, and `navigator.userAgentData.brands`.
  List<BrandVersion>? brandVersionList;

  ///Full version string. Backs `Sec-CH-UA-Full-Version`.
  String? fullVersion;

  ///Platform name, e.g. `"Windows"`, `"Android"`, `"macOS"`.
  ///Backs `Sec-CH-UA-Platform` and `navigator.userAgentData.platform`.
  String? platform;

  ///Platform version, e.g. `"15.0.0"`. Backs `Sec-CH-UA-Platform-Version`.
  String? platformVersion;

  ///CPU architecture, e.g. `"x86"`, `"arm"`. Backs `Sec-CH-UA-Arch`.
  String? architecture;

  ///Device model. Backs `Sec-CH-UA-Model`.
  String? model;

  ///Whether the device is mobile. Backs `Sec-CH-UA-Mobile` and
  ///`navigator.userAgentData.mobile`. Defaults to `true` on Android.
  bool? mobile;

  ///Architecture bitness, e.g. `64`. Backs `Sec-CH-UA-Bitness`.
  ///`0` means platform default.
  int? bitness;

  ///Whether the device is running 32-bit Windows on 64-bit hardware.
  ///Backs `Sec-CH-UA-Wow64`.
  bool? wow64;

  ///Form-factor list, e.g. `["Desktop"]`, `["Mobile"]`, `["Tablet"]`.
  ///Allowed values: `Desktop`, `Automotive`, `Mobile`, `Tablet`, `XR`,
  ///`EInk`, `Watch`. Backs `Sec-CH-UA-Form-Factors`.
  List<String>? formFactors;

  UserAgentMetadata({
    this.brandVersionList,
    this.fullVersion,
    this.platform,
    this.platformVersion,
    this.architecture,
    this.model,
    this.mobile,
    this.bitness,
    this.wow64,
    this.formFactors,
  });

  ///Gets a possible [UserAgentMetadata] instance from a [Map] value.
  static UserAgentMetadata? fromMap(Map<String, dynamic>? map,
      {EnumMethod? enumMethod}) {
    if (map == null) {
      return null;
    }
    return UserAgentMetadata(
      brandVersionList: map['brandVersionList'] != null
          ? List<BrandVersion>.from(
              (map['brandVersionList'] as List)
                  .map((e) => BrandVersion.fromMap(
                      (e as Map).cast<String, dynamic>()))
                  .whereType<BrandVersion>(),
            )
          : null,
      fullVersion: map['fullVersion'] as String?,
      platform: map['platform'] as String?,
      platformVersion: map['platformVersion'] as String?,
      architecture: map['architecture'] as String?,
      model: map['model'] as String?,
      mobile: map['mobile'] as bool?,
      bitness: map['bitness'] as int?,
      wow64: map['wow64'] as bool?,
      formFactors: map['formFactors'] != null
          ? List<String>.from((map['formFactors'] as List).cast<String>())
          : null,
    );
  }

  ///Converts instance to a map.
  Map<String, dynamic> toMap({EnumMethod? enumMethod}) {
    return {
      'brandVersionList':
          brandVersionList?.map((e) => e.toMap()).toList(growable: false),
      'fullVersion': fullVersion,
      'platform': platform,
      'platformVersion': platformVersion,
      'architecture': architecture,
      'model': model,
      'mobile': mobile,
      'bitness': bitness,
      'wow64': wow64,
      'formFactors': formFactors,
    };
  }

  ///Converts instance to a map.
  Map<String, dynamic> toJson() => toMap();

  @override
  String toString() {
    return 'UserAgentMetadata{brandVersionList: $brandVersionList, fullVersion: $fullVersion, platform: $platform, platformVersion: $platformVersion, architecture: $architecture, model: $model, mobile: $mobile, bitness: $bitness, wow64: $wow64, formFactors: $formFactors}';
  }
}
