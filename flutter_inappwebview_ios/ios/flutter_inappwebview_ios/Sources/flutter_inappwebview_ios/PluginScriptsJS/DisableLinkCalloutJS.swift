//
//  DisableLinkCalloutJS.swift
//  flutter_inappwebview
//

import Foundation

// [WebSpace fork patch] `disableLongPressContextMenuOnLinks` on iOS 13+.
// WebKit's link menu is a UIContextMenuInteraction that claims the long press
// before the plugin's recognizers, and cycling the loupe gesture does not
// stop it; a nil configuration from the UI delegate makes WebKit build its
// default menu instead. WebKit offers no menu for an element whose
// -webkit-touch-callout is none (WKContentView continueContextMenuInteraction),
// so links get that and the long press reaches onLongPressHitTestResult.
// An image keeps its menu: FindElementsAtPointJS reports a linked image only
// when the link is its parent, and then with the image's src, not the link.
public class DisableLinkCalloutJS {

    public static let DISABLE_LINK_CALLOUT_JS_PLUGIN_SCRIPT_GROUP_NAME = "IN_APP_WEBVIEW_DISABLE_LINK_CALLOUT_JS_PLUGIN_SCRIPT"

    private static let STYLE_ID = "_flutter_inappwebview_disable_link_callout"

    // Main frame only, as the hit test that replaces the menu reads only the
    // main frame (FindElementsAtPointJS).
    public static func DISABLE_LINK_CALLOUT_JS_PLUGIN_SCRIPT(allowedOriginRules: [String]?) -> PluginScript {
        return PluginScript(
            groupName: DISABLE_LINK_CALLOUT_JS_PLUGIN_SCRIPT_GROUP_NAME,
            source: DISABLE_LINK_CALLOUT_JS_SOURCE,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true,
            allowedOriginRules: allowedOriginRules,
            requiredInAllContentWorlds: false,
            messageHandlerNames: [])
    }

    // Waits for the root element: a node appended to a document that has none
    // yet becomes its root, and the parser then drops the page.
    public static let DISABLE_LINK_CALLOUT_JS_SOURCE = """
    (function() {
        var id = '\(STYLE_ID)';
        if (document.getElementById(id)) return;
        var style = document.createElement('style');
        style.id = id;
        style.textContent = 'a[href],a[href] *{-webkit-touch-callout:none!important}' +
            'a[href] img{-webkit-touch-callout:default!important}';
        function put() { (document.head || document.documentElement).appendChild(style); }
        if (document.documentElement) { put(); return; }
        new MutationObserver(function(_, observer) {
            if (!document.documentElement) return;
            observer.disconnect();
            if (!document.getElementById(id)) put();
        }).observe(document, { childList: true });
    })();
    """

    public static let ENABLE_LINK_CALLOUT_JS_SOURCE = """
    (function() {
        var style = document.getElementById('\(STYLE_ID)');
        if (style) style.remove();
    })();
    """
}
