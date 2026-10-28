import 'package:flutter_inappwebview_internal_annotations/flutter_inappwebview_internal_annotations.dart';

part 'web_extension_page.g.dart';

///[WebSpace fork patch] A page of a web extension the host app asks to show
///over the app.
@ExchangeableEnum()
class WebExtensionPage_ {
  // ignore: unused_field
  final String _value;
  const WebExtensionPage_._internal(this._value);

  ///The extension's options page.
  static const OPTIONS = const WebExtensionPage_._internal('options');

  ///The extension's action: its popup, or its click event when it has no
  ///popup.
  static const ACTION = const WebExtensionPage_._internal('action');
}
