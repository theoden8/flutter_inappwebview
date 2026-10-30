//
//  WebExtensionHost.swift
//  flutter_inappwebview
//
//  [WebSpace fork patch] The web extensions `InAppWebViewSettings.webExtensions`
//  names. One controller per container, so an extension's storage and
//  cookie access follow the container: WebViews of one container share
//  them, two containers never do. Each extension is loaded into a
//  controller once, with the hosts and permissions the host app granted,
//  and every request for more is answered with those grants and nothing
//  else. Which hosts an extension may reach is the host app's decision;
//  nothing here widens it.
//
//  An extension sees its container's WebViews as the tabs of one window,
//  the last one attached active. Its options page, its action popup and
//  the pages of its own it opens as tabs are shown natively, over the app.
//

import Foundation
import WebKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// One extension of `InAppWebViewSettings.webExtensions`.
struct WebExtensionContextSpec: Equatable {
    let id: String
    let path: String
    let grantedMatchPatterns: [String]
    let grantedPermissions: [String]
    /// What the folder holds now; a new one is read again from disk.
    let revision: String

    init?(map: [String: Any?]) {
        guard let id = map["id"] as? String, !id.isEmpty,
              let path = map["path"] as? String, !path.isEmpty else {
            return nil
        }
        self.id = id
        self.path = path
        grantedMatchPatterns = map["grantedMatchPatterns"] as? [String] ?? []
        grantedPermissions = map["grantedPermissions"] as? [String] ?? []
        revision = map["revision"] as? String ?? ""
    }
}

/// `InAppWebViewSettings.webExtensions`, parsed. Nil when it names no
/// extension, so a WebView without any gets no controller at all.
struct WebExtensionAttachSpec {
    let persistent: Bool
    let contexts: [WebExtensionContextSpec]

    init?(map: [String: Any?]?) {
        guard let map = map else {
            return nil
        }
        let contexts = (map["contexts"] as? [[String: Any?]] ?? [])
            .compactMap { WebExtensionContextSpec(map: $0) }
        if contexts.isEmpty {
            return nil
        }
        self.persistent = map["persistent"] as? Bool ?? true
        self.contexts = contexts
    }
}

/// A page of an extension the host app asks to show.
enum WebExtensionPage: String {
    /// The extension's options page.
    case options
    /// The extension's action: its popup, or its click event when it has
    /// no popup.
    case action
}

#if compiler(>=6.1)
@available(iOS 18.4, macOS 15.4, *)
@MainActor
final class WebExtensionHost: NSObject, WKWebExtensionControllerDelegate {
    static let shared = WebExtensionHost()

    /// Persistent controllers, by container id.
    private var controllers: [String: WKWebExtensionController] = [:]
    /// Each extension read from disk once, by path and revision.
    private var extensions: [String: WKWebExtension] = [:]
    /// What each loaded context was granted.
    private var grants: [ObjectIdentifier: WebExtensionContextSpec] = [:]
    /// The window each controller's extensions see, by controller.
    private var windows: [ObjectIdentifier: WebExtensionWindowRef] = [:]
    /// The tab each WebView running extensions is shown as, by WebView.
    private var tabs: [ObjectIdentifier: WebExtensionTabRef] = [:]
    /// Every controller made, persistent or not, while it lives.
    private let live = NSHashTable<WKWebExtensionController>.weakObjects()

    /// The controller a WebView takes: its container's when [spec] is
    /// persistent, one of its own otherwise. Nil for a persistent spec
    /// without a container, which has nowhere to keep the data.
    func controller(for spec: WebExtensionAttachSpec, containerId: String?,
                    dataStore: WKWebsiteDataStore) -> WKWebExtensionController? {
        if !spec.persistent {
            return makeController(configuration: .nonPersistent(), dataStore: dataStore)
        }
        guard let containerId = containerId else {
            return nil
        }
        if let existing = controllers[containerId] {
            return existing
        }
        let controller = makeController(
            configuration: WKWebExtensionController.Configuration(
                identifier: containerIdToUUID(containerId)),
            dataStore: dataStore)
        controllers[containerId] = controller
        return controller
    }

    private func makeController(configuration: WKWebExtensionController.Configuration,
                                dataStore: WKWebsiteDataStore) -> WKWebExtensionController {
        configuration.defaultWebsiteDataStore = dataStore
        let controller = WKWebExtensionController(configuration: configuration)
        controller.delegate = self
        live.add(controller)
        return controller
    }

    /// Loads [spec]'s extensions into [controller], then calls [completion].
    /// A context loaded with other grants is replaced, and one [spec] no
    /// longer names is unloaded. An extension that fails to load is left
    /// out; the others still load.
    func load(_ spec: WebExtensionAttachSpec, into controller: WKWebExtensionController,
              completion: @escaping () -> Void) {
        Task { @MainActor in
            let wanted = Set(spec.contexts.map { $0.id })
            for context in controller.extensionContexts where !wanted.contains(context.uniqueIdentifier) {
                unload(context, from: controller)
            }
            for contextSpec in spec.contexts {
                await load(contextSpec, into: controller)
            }
            completion()
        }
    }

    private func load(_ spec: WebExtensionContextSpec, into controller: WKWebExtensionController) async {
        if let loaded = controller.extensionContexts.first(where: { $0.uniqueIdentifier == spec.id }) {
            if grants[ObjectIdentifier(loaded)] == spec {
                return
            }
            unload(loaded, from: controller)
        }
        let webExtension: WKWebExtension
        do {
            webExtension = try await extensionAt(path: spec.path, revision: spec.revision)
        } catch {
            print("[WebSpace] web extension \(spec.id) did not load from \(spec.path): \(error)")
            return
        }
        let context = WKWebExtensionContext(for: webExtension)
        // A stable identity keeps the extension's data across launches: its
        // storage is keyed by the base URL's host.
        context.uniqueIdentifier = spec.id
        if let baseURL = URL(string: "webkit-extension://\(spec.id)/") {
            context.baseURL = baseURL
        }
        for pattern in spec.grantedMatchPatterns {
            if let matchPattern = try? WKWebExtension.MatchPattern(string: pattern) {
                context.setPermissionStatus(.grantedExplicitly, for: matchPattern)
            }
        }
        for permission in spec.grantedPermissions {
            context.setPermissionStatus(.grantedExplicitly, for: WKWebExtension.Permission(rawValue: permission))
        }
        do {
            try controller.load(context)
            grants[ObjectIdentifier(context)] = spec
        } catch {
            print("[WebSpace] web extension \(spec.id) did not load into its controller: \(error)")
        }
    }

    private func unload(_ context: WKWebExtensionContext, from controller: WKWebExtensionController) {
        grants[ObjectIdentifier(context)] = nil
        do {
            try controller.unload(context)
        } catch {
            print("[WebSpace] web extension \(context.uniqueIdentifier) did not unload: \(error)")
        }
    }

    private func extensionAt(path: String, revision: String) async throws -> WKWebExtension {
        let key = path + "\u{0}" + revision
        if let cached = extensions[key] {
            return cached
        }
        let webExtension = try await WKWebExtension(
            resourceBaseURL: URL(fileURLWithPath: path, isDirectory: true))
        extensions = extensions.filter { !$0.key.hasPrefix(path + "\u{0}") }
        extensions[key] = webExtension
        return webExtension
    }

    /// Removes what every extension stored for [containerId], as deleting
    /// the container removes the site's own data.
    func removeData(forContainer containerId: String) {
        let controller = controllers.removeValue(forKey: containerId)
            ?? WKWebExtensionController(configuration: WKWebExtensionController.Configuration(
                identifier: containerIdToUUID(containerId)))
        let types = WKWebExtensionController.allExtensionDataTypes
        controller.fetchDataRecords(ofTypes: types) { records in
            controller.removeData(ofTypes: types, from: records) {}
        }
    }

    /// Unloads extension [extensionId] wherever it runs and removes what it
    /// stored in each of [containerIds], as removing it from the host app's
    /// library removes its files.
    func removeData(ofExtension extensionId: String, inContainers containerIds: [String]) async {
        for controller in live.allObjects {
            if let context = controller.extensionContexts.first(where: { $0.uniqueIdentifier == extensionId }) {
                unload(context, from: controller)
            }
        }
        let types = WKWebExtensionController.allExtensionDataTypes
        for containerId in containerIds {
            let controller = controllers[containerId]
                ?? WKWebExtensionController(configuration: WKWebExtensionController.Configuration(
                    identifier: containerIdToUUID(containerId)))
            let own = await controller.dataRecords(ofTypes: types)
                .filter { $0.uniqueIdentifier == extensionId }
            if !own.isEmpty {
                await controller.removeData(ofTypes: types, from: own)
            }
        }
    }

    /// What WebKit reports reading the extension at [path]: the errors it
    /// found, whether it has an options page and an action, and whether
    /// WebKit loads it on this device. An extension WebKit cannot read at
    /// all has that error alone.
    func inspect(path: String) async -> [String: Any] {
        do {
            let webExtension = try await WKWebExtension(
                resourceBaseURL: URL(fileURLWithPath: path, isDirectory: true))
            let manifest = webExtension.manifest
            let hasAction = ["action", "browser_action", "page_action"]
                .contains { manifest[$0] != nil }
            // WebKit's WebExtensionContext::load refuses, on iOS and visionOS,
            // an extension whose background stays loaded, before running any of it.
            #if os(iOS) || os(visionOS)
            let loadsHere = !webExtension.hasPersistentBackgroundContent
            #else
            let loadsHere = true
            #endif
            return [
                "errors": webExtension.errors.map { $0.localizedDescription },
                "hasOptionsPage": webExtension.hasOptionsPage,
                "hasAction": hasAction,
                "loadsHere": loadsHere,
            ]
        } catch {
            return [
                "errors": [error.localizedDescription],
                "hasOptionsPage": false,
                "hasAction": false,
                "loadsHere": false,
            ]
        }
    }

    /// Shows [page] of extension [extensionId], run as [spec] runs it in
    /// [containerId]. [spec] is the container's whole set, as its WebViews
    /// take it: a context it does not name is unloaded. False when the
    /// extension is not loaded there or has no such page.
    func openPage(_ page: WebExtensionPage, extensionId: String, spec: WebExtensionAttachSpec,
                  containerId: String, completion: @escaping (Bool) -> Void) {
        guard spec.persistent,
              let controller = controller(
                for: spec, containerId: containerId,
                dataStore: ContainerManager.getOrCreateDataStore(forContainer: containerId)) else {
            completion(false)
            return
        }
        load(spec, into: controller) { [weak self] in
            guard let self = self,
                  let context = controller.extensionContexts.first(where: { $0.uniqueIdentifier == extensionId }) else {
                completion(false)
                return
            }
            switch page {
            case .options:
                completion(self.presentOptions(of: context))
            case .action:
                context.performAction(for: self.windows[ObjectIdentifier(controller)]?.active)
                completion(true)
            }
        }
    }

    // MARK: Tabs and windows

    /// [webView] runs [controller]'s extensions: it opens as the active tab
    /// of the controller's window.
    func opened(_ webView: WKWebView, controller: WKWebExtensionController) {
        let key = ObjectIdentifier(webView)
        if tabs[key] != nil {
            return
        }
        let window = windowOf(controller)
        let previous = window.active
        let tab = WebExtensionTabRef(webView: webView, window: window)
        window.members.append(tab)
        tabs[key] = tab
        controller.didOpenTab(tab)
        controller.didActivateTab(tab, previousActiveTab: previous)
    }

    /// [webView] went: its tab closes, and its window with its last tab.
    func closed(_ webView: WKWebView) {
        guard let tab = tabs.removeValue(forKey: ObjectIdentifier(webView)),
              let controller = webView.configuration.webExtensionController else {
            return
        }
        let window = tab.window
        window?.members.removeAll { $0 === tab }
        let windowIsClosing = window?.members.isEmpty ?? false
        controller.didCloseTab(tab, windowIsClosing: windowIsClosing)
        if let window = window, windowIsClosing {
            windows[ObjectIdentifier(controller)] = nil
            controller.didCloseWindow(window)
        }
    }

    private func windowOf(_ controller: WKWebExtensionController) -> WebExtensionWindowRef {
        let key = ObjectIdentifier(controller)
        if let window = windows[key] {
            return window
        }
        let window = WebExtensionWindowRef()
        windows[key] = window
        controller.didOpenWindow(window)
        controller.didFocusWindow(window)
        return window
    }

    // MARK: Pages

    private func presentOptions(of context: WKWebExtensionContext) -> Bool {
        guard let url = context.optionsPageURL else {
            return false
        }
        return presentPage(url, of: context)
    }

    /// An extension page loads only in a WebView configured for its context.
    private func presentPage(_ url: URL, of context: WKWebExtensionContext) -> Bool {
        guard let configuration = context.webViewConfiguration else {
            return false
        }
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.load(URLRequest(url: url))
        return WebExtensionPresenter.present(webView, title: context.webExtension.displayName ?? "")
    }

    private func isPage(_ url: URL, of context: WKWebExtensionContext) -> Bool {
        return url.scheme == context.baseURL.scheme && url.host == context.baseURL.host
    }

    private func grantsOf(_ context: WKWebExtensionContext) -> WebExtensionContextSpec? {
        return grants[ObjectIdentifier(context)]
    }

    private static func refusal(_ reason: String) -> NSError {
        return NSError(domain: "WebSpaceWebExtensions", code: 1,
                       userInfo: [NSLocalizedDescriptionKey: reason])
    }

    // MARK: WKWebExtensionControllerDelegate
    //
    // Every request for more than the grants is answered with the grants:
    // the user consented to them per site, and nothing else is asked.

    func webExtensionController(_ controller: WKWebExtensionController,
                                promptForPermissions permissions: Set<WKWebExtension.Permission>,
                                in tab: (any WKWebExtensionTab)?,
                                for extensionContext: WKWebExtensionContext,
                                completionHandler: @escaping (Set<WKWebExtension.Permission>, Date?) -> Void) {
        let granted = Set((grantsOf(extensionContext)?.grantedPermissions ?? [])
            .map { WKWebExtension.Permission(rawValue: $0) })
        completionHandler(permissions.intersection(granted), nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController,
                                promptForPermissionMatchPatterns matchPatterns: Set<WKWebExtension.MatchPattern>,
                                in tab: (any WKWebExtensionTab)?,
                                for extensionContext: WKWebExtensionContext,
                                completionHandler: @escaping (Set<WKWebExtension.MatchPattern>, Date?) -> Void) {
        let granted = Set(grantsOf(extensionContext)?.grantedMatchPatterns ?? [])
        completionHandler(matchPatterns.filter { granted.contains($0.string) }, nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController,
                                promptForPermissionToAccess urls: Set<URL>,
                                in tab: (any WKWebExtensionTab)?,
                                for extensionContext: WKWebExtensionContext,
                                completionHandler: @escaping (Set<URL>, Date?) -> Void) {
        let patterns = (grantsOf(extensionContext)?.grantedMatchPatterns ?? [])
            .compactMap { try? WKWebExtension.MatchPattern(string: $0) }
        completionHandler(urls.filter { url in patterns.contains { $0.matches(url) } }, nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController,
                                openWindowsFor extensionContext: WKWebExtensionContext) -> [any WKWebExtensionWindow] {
        guard let window = windows[ObjectIdentifier(controller)] else {
            return []
        }
        return [window]
    }

    func webExtensionController(_ controller: WKWebExtensionController,
                                focusedWindowFor extensionContext: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        return windows[ObjectIdentifier(controller)]
    }

    /// Only a page of the extension's own opens, shown as its options page
    /// is; a tab on the web would run outside the host app's sites.
    func webExtensionController(_ controller: WKWebExtensionController,
                                openNewTabUsing configuration: WKWebExtension.TabConfiguration,
                                for extensionContext: WKWebExtensionContext,
                                completionHandler: @escaping ((any WKWebExtensionTab)?, (any Error)?) -> Void) {
        if let url = configuration.url, isPage(url, of: extensionContext),
           presentPage(url, of: extensionContext) {
            completionHandler(nil, nil)
            return
        }
        completionHandler(nil, WebExtensionHost.refusal("This browser does not open tabs for extensions"))
    }

    func webExtensionController(_ controller: WKWebExtensionController,
                                openOptionsPageFor extensionContext: WKWebExtensionContext,
                                completionHandler: @escaping ((any Error)?) -> Void) {
        completionHandler(presentOptions(of: extensionContext)
                          ? nil : WebExtensionHost.refusal("The options page could not be shown"))
    }

    func webExtensionController(_ controller: WKWebExtensionController,
                                presentActionPopup action: WKWebExtension.Action,
                                for context: WKWebExtensionContext,
                                completionHandler: @escaping ((any Error)?) -> Void) {
        completionHandler(WebExtensionPresenter.presentPopup(of: action)
                          ? nil : WebExtensionHost.refusal("The popup could not be shown"))
    }

    func webExtensionController(_ controller: WKWebExtensionController,
                                openNewWindowUsing configuration: WKWebExtension.WindowConfiguration,
                                for extensionContext: WKWebExtensionContext,
                                completionHandler: @escaping ((any WKWebExtensionWindow)?, (any Error)?) -> Void) {
        completionHandler(nil, WebExtensionHost.refusal("This browser does not open windows for extensions"))
    }

    func webExtensionController(_ controller: WKWebExtensionController,
                                sendMessage message: Any,
                                toApplicationWithIdentifier applicationIdentifier: String?,
                                for extensionContext: WKWebExtensionContext,
                                replyHandler: @escaping (Any?, (any Error)?) -> Void) {
        replyHandler(nil, WebExtensionHost.refusal("Native messaging is not available"))
    }

    func webExtensionController(_ controller: WKWebExtensionController,
                                connectUsing port: WKWebExtension.MessagePort,
                                for extensionContext: WKWebExtensionContext,
                                completionHandler: @escaping ((any Error)?) -> Void) {
        completionHandler(WebExtensionHost.refusal("Native messaging is not available"))
    }
}

/// A WebView running a container's extensions, as they see it.
@available(iOS 18.4, macOS 15.4, *)
@MainActor
final class WebExtensionTabRef: NSObject, WKWebExtensionTab {
    weak var webView: WKWebView?
    weak var window: WebExtensionWindowRef?

    init(webView: WKWebView, window: WebExtensionWindowRef) {
        self.webView = webView
        self.window = window
    }

    func window(for context: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        return window
    }

    func webView(for context: WKWebExtensionContext) -> WKWebView? {
        return webView
    }

    func title(for context: WKWebExtensionContext) -> String? {
        return webView?.title
    }

    func url(for context: WKWebExtensionContext) -> URL? {
        return webView?.url
    }

    func isLoadingComplete(for context: WKWebExtensionContext) -> Bool {
        return !(webView?.isLoading ?? false)
    }

    func isSelected(for context: WKWebExtensionContext) -> Bool {
        return window?.active === self
    }
}

/// The one window of a container's tabs.
@available(iOS 18.4, macOS 15.4, *)
@MainActor
final class WebExtensionWindowRef: NSObject, WKWebExtensionWindow {
    var members: [WebExtensionTabRef] = []

    /// The tab attached last.
    var active: WebExtensionTabRef? {
        return members.last
    }

    func tabs(for context: WKWebExtensionContext) -> [any WKWebExtensionTab] {
        return members
    }

    func activeTab(for context: WKWebExtensionContext) -> (any WKWebExtensionTab)? {
        return active
    }
}

/// Shows an extension's pages over the app: a page in a sheet on iOS and
/// a window of its own on macOS, a popup as WebKit prepares it.
@available(iOS 18.4, macOS 15.4, *)
@MainActor
enum WebExtensionPresenter {
    #if os(iOS)
    static func present(_ webView: WKWebView, title: String) -> Bool {
        guard let host = topViewController() else {
            return false
        }
        let page = UIViewController()
        page.view = webView
        page.title = title
        let navigation = UINavigationController(rootViewController: page)
        page.navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak navigation] _ in
                navigation?.dismiss(animated: true)
            })
        host.present(navigation, animated: true)
        return true
    }

    static func presentPopup(of action: WKWebExtension.Action) -> Bool {
        guard let popup = action.popupViewController, let host = topViewController() else {
            return false
        }
        if let anchor = popup.popoverPresentationController {
            anchor.sourceView = host.view
            anchor.sourceRect = CGRect(x: host.view.bounds.maxX - 1, y: host.view.safeAreaInsets.top,
                                       width: 1, height: 1)
        }
        host.present(popup, animated: true)
        return true
    }

    private static func topViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
    #elseif os(macOS)
    static func present(_ webView: WKWebView, title: String) -> Bool {
        let page = NSViewController()
        page.view = webView
        let window = NSWindow(contentViewController: page)
        window.title = title
        window.setContentSize(NSSize(width: 720, height: 560))
        PageWindows.shared.show(window)
        return true
    }

    static func presentPopup(of action: WKWebExtension.Action) -> Bool {
        guard let popover = action.popupPopover, let view = NSApp.keyWindow?.contentView else {
            return false
        }
        let anchor = NSRect(x: view.bounds.maxX - 1, y: view.bounds.maxY - 1, width: 1, height: 1)
        popover.show(relativeTo: anchor, of: view, preferredEdge: .minY)
        return true
    }
    #endif
}

#if os(macOS)
/// Keeps each page window alive while it is open.
@MainActor
private final class PageWindows: NSObject, NSWindowDelegate {
    static let shared = PageWindows()

    private var open: [NSWindow] = []

    func show(_ window: NSWindow) {
        window.isReleasedWhenClosed = false
        window.delegate = self
        open.append(window)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }
        open.removeAll { $0 === window }
    }
}
#endif
#endif
