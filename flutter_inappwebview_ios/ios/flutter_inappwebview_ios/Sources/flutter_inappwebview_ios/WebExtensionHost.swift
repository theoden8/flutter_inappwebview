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
//  the pages of its own it opens as tabs are shown natively, over the app:
//  a page as a sheet, the popup as WebKit's popover.
//  What goes wrong running one is reported to the host app as it happens.
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
    /// Whether Web Inspector may inspect the extensions' background, popups
    /// and pages.
    let inspectable: Bool

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
        self.inspectable = map["inspectable"] as? Bool ?? false
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
    /// The extension each page shown over the app belongs to, while it shows.
    private let pages = NSMapTable<WKWebView, NSString>.weakToStrongObjects()

    /// Where the host app hears what goes wrong: an extension that did not
    /// load, a page or popup that could not be shown, a page that failed to
    /// load, a tab or window an extension asked for and was refused. The
    /// container channel sends each to Dart.
    var onProblem: ((_ extensionId: String, _ message: String) -> Void)?

    /// Where the host app answers an extension's request for a tab at a web
    /// page: the container channel asks Dart, which opens the page as it
    /// chooses and answers whether it did. Unset, every such request is
    /// refused.
    var onTabRequest: ((_ request: [String: Any], _ answer: @escaping (Bool) -> Void) -> Void)?

    private func report(_ extensionId: String, _ message: String) {
        print("[WebSpace] web extension \(extensionId) \(message)")
        onProblem?(extensionId, message)
    }

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
            // WebKit passes it on to the background, popups and tab pages.
            for context in controller.extensionContexts {
                context.isInspectable = spec.inspectable
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
            report(spec.id, "could not be read from \(spec.path): \(error.localizedDescription)")
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
            report(spec.id, "did not load: \(error.localizedDescription)")
        }
    }

    private func unload(_ context: WKWebExtensionContext, from controller: WKWebExtensionController) {
        grants[ObjectIdentifier(context)] = nil
        do {
            try controller.unload(context)
        } catch {
            report(context.uniqueIdentifier, "did not unload: \(error.localizedDescription)")
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

    /// Lets go of [containerId]'s controller, its contexts unloaded, so
    /// nothing of the host keeps the container's store in use while the
    /// container is deleted; its next WebView makes a new one. Kept while a
    /// WebView of the container is still one of its tabs.
    func release(container containerId: String) {
        guard let controller = controllers[containerId],
              windows[ObjectIdentifier(controller)]?.members.isEmpty ?? true else {
            return
        }
        controllers.removeValue(forKey: containerId)
        windows[ObjectIdentifier(controller)] = nil
        for context in controller.extensionContexts {
            unload(context, from: controller)
        }
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
            // WebKit's NSErrors read as Objective-C objects: converting each
            // to Swift's `any Error` ended the app on a 2014 Intel Mac
            // (macOS 15.7 through OpenCore), messaging the error's code.
            let errors = (webExtension.value(forKey: "errors") as? [NSError] ?? [])
                .map { $0.localizedDescription }
            return [
                "errors": errors,
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
    /// extension is not loaded there or has no such page, and for its
    /// action when no WebView of the container is open to act on.
    func openPage(_ page: WebExtensionPage, extensionId: String, spec: WebExtensionAttachSpec,
                  containerId: String, completion: @escaping (Bool) -> Void) {
        guard spec.persistent,
              let controller = controller(
                for: spec, containerId: containerId,
                dataStore: ContainerManager.getOrCreateDataStore(forContainer: containerId)) else {
            report(extensionId, "has no container to open its \(page.rawValue) page in")
            completion(false)
            return
        }
        load(spec, into: controller) { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }
            guard let context = controller.extensionContexts.first(where: { $0.uniqueIdentifier == extensionId }) else {
                self.report(extensionId, "is not loaded, so its \(page.rawValue) page cannot open")
                completion(false)
                return
            }
            switch page {
            case .options:
                completion(self.presentOptions(of: context))
            case .action:
                // An action acts on the active tab, as a toolbar button does;
                // with none, an extension asking which tab it is on gets
                // nothing, and some then never answer their own popup.
                guard let tab = self.windows[ObjectIdentifier(controller)]?.active else {
                    self.report(extensionId, "has no open tab of its site to act on")
                    completion(false)
                    return
                }
                context.performAction(for: tab)
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
            report(context.uniqueIdentifier, "has no options page")
            return false
        }
        return presentPage(url, of: context)
    }

    /// An extension page loads only in a WebView configured for its context.
    private func presentPage(_ url: URL, of context: WKWebExtensionContext) -> Bool {
        guard let configuration = context.webViewConfiguration else {
            report(context.uniqueIdentifier, "is not loaded, so \(url.absoluteString) cannot open")
            return false
        }
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isInspectable = context.isInspectable
        webView.navigationDelegate = self
        pages.setObject(context.uniqueIdentifier as NSString, forKey: webView)
        webView.load(URLRequest(url: url))
        guard WebExtensionPresenter.present(webView, title: context.webExtension.displayName ?? "") else {
            report(context.uniqueIdentifier, "page \(url.absoluteString) has nowhere to show")
            return false
        }
        return true
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

    /// A page of the extension's own opens as its options page is. A web
    /// page goes to the host app, which opens it only as a page of the site
    /// whose container the extension runs in; a tab anywhere else would run
    /// outside the host app's sites.
    func webExtensionController(_ controller: WKWebExtensionController,
                                openNewTabUsing configuration: WKWebExtension.TabConfiguration,
                                for extensionContext: WKWebExtensionContext,
                                completionHandler: @escaping ((any WKWebExtensionTab)?, (any Error)?) -> Void) {
        let extensionId = extensionContext.uniqueIdentifier
        let refused = WebExtensionHost.refusal("This browser does not open tabs for extensions")
        guard let url = configuration.url else {
            report(extensionId, "asked for a tab at no address")
            completionHandler(nil, refused)
            return
        }
        if isPage(url, of: extensionContext) {
            completionHandler(nil, presentPage(url, of: extensionContext) ? nil : refused)
            return
        }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let containerId = controllers.first(where: { $0.value === controller })?.key,
              let ask = onTabRequest else {
            report(extensionId, "asked for a tab at \(url.absoluteString), which only opens for its own pages and its site's")
            completionHandler(nil, refused)
            return
        }
        ask(["containerId": containerId, "extensionId": extensionId, "url": url.absoluteString]) { [weak self] opened in
            if !opened {
                self?.report(extensionId, "asked for a tab at \(url.absoluteString), which is not a page of its site")
            }
            completionHandler(nil, opened ? nil : refused)
        }
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
        if WebExtensionPresenter.presentPopup(of: action) {
            completionHandler(nil)
            return
        }
        report(context.uniqueIdentifier, "popup could not be shown")
        completionHandler(WebExtensionHost.refusal("The popup could not be shown"))
    }

    func webExtensionController(_ controller: WKWebExtensionController,
                                openNewWindowUsing configuration: WKWebExtension.WindowConfiguration,
                                for extensionContext: WKWebExtensionContext,
                                completionHandler: @escaping ((any WKWebExtensionWindow)?, (any Error)?) -> Void) {
        report(extensionContext.uniqueIdentifier, "asked for a window, which this browser does not open")
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

// MARK: WKNavigationDelegate
//
// Of the pages shown over the app only: one that fails to load is reported,
// since the host app sees nothing of it otherwise.

@available(iOS 18.4, macOS 15.4, *)
extension WebExtensionHost: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: any Error) {
        pageFailed(webView, error: error as NSError)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        pageFailed(webView, error: error as NSError)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard let extensionId = pages.object(forKey: webView) as String? else {
            return
        }
        report(extensionId, "page \(webView.url?.absoluteString ?? "") stopped: its web content process ended")
    }

    private func pageFailed(_ webView: WKWebView, error: NSError) {
        // A load another one replaced did not fail.
        guard error.code != NSURLErrorCancelled,
              let extensionId = pages.object(forKey: webView) as String? else {
            return
        }
        let url = error.userInfo[NSURLErrorFailingURLStringErrorKey] as? String
            ?? webView.url?.absoluteString ?? ""
        report(extensionId, "page \(url) failed to load: \(error.localizedDescription)")
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
    /// As a sheet over the app's window, as iOS presents it over the app.
    static func present(_ webView: WKWebView, title: String) -> Bool {
        guard var host = NSApp.mainWindow ?? NSApp.keyWindow else {
            return false
        }
        // A page an extension opens from one of its pages goes over that one.
        while let sheet = host.attachedSheet {
            host = sheet
        }
        let sheet = NSWindow(contentViewController: PageSheet(webView: webView, title: title))
        sheet.isReleasedWhenClosed = false
        let room = host.contentLayoutRect.size
        sheet.setContentSize(NSSize(width: min(720, room.width - 40), height: min(560, room.height - 20)))
        host.beginSheet(sheet)
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
/// An extension page in a sheet: a bar with the window close button, whose
/// look and spoken name are the system's, and the extension's name; the
/// page fills the rest. The close button answers Escape too.
@MainActor
private final class PageSheet: NSViewController {
    private let webView: WKWebView
    private let pageTitle: String

    init(webView: WKWebView, title: String) {
        self.webView = webView
        self.pageTitle = title
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func loadView() {
        let close = NSWindow.standardWindowButton(.closeButton, for: [.titled, .closable]) ?? NSButton()
        close.target = self
        close.action = #selector(done)
        close.keyEquivalent = "\u{1b}"
        let name = NSTextField(labelWithString: pageTitle)
        name.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        name.lineBreakMode = .byTruncatingTail
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let line = NSBox()
        line.boxType = .separator
        let root = NSView()
        for part in [close, name, line, webView] as [NSView] {
            part.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(part)
        }
        let centered = name.centerXAnchor.constraint(equalTo: root.centerXAnchor)
        centered.priority = .defaultHigh
        NSLayoutConstraint.activate([
            close.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            close.centerYAnchor.constraint(equalTo: root.topAnchor, constant: 18),
            centered,
            name.centerYAnchor.constraint(equalTo: close.centerYAnchor),
            name.leadingAnchor.constraint(greaterThanOrEqualTo: close.trailingAnchor, constant: 8),
            name.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -12),
            line.topAnchor.constraint(equalTo: root.topAnchor, constant: 36),
            line.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            webView.topAnchor.constraint(equalTo: line.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        view = root
    }

    @objc private func done() {
        guard let sheet = view.window, let parent = sheet.sheetParent else {
            return
        }
        parent.endSheet(sheet)
    }
}
#endif
#endif
