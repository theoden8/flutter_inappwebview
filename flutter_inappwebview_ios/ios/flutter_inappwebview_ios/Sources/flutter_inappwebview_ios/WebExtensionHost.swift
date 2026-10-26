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

import Foundation
import WebKit

/// One extension of `InAppWebViewSettings.webExtensions`.
struct WebExtensionContextSpec: Equatable {
    let id: String
    let path: String
    let grantedMatchPatterns: [String]
    let grantedPermissions: [String]

    init?(map: [String: Any?]) {
        guard let id = map["id"] as? String, !id.isEmpty,
              let path = map["path"] as? String, !path.isEmpty else {
            return nil
        }
        self.id = id
        self.path = path
        grantedMatchPatterns = map["grantedMatchPatterns"] as? [String] ?? []
        grantedPermissions = map["grantedPermissions"] as? [String] ?? []
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

#if compiler(>=6.1)
@available(iOS 18.4, macOS 15.4, *)
@MainActor
final class WebExtensionHost: NSObject, WKWebExtensionControllerDelegate {
    static let shared = WebExtensionHost()

    /// Persistent controllers, by container id.
    private var controllers: [String: WKWebExtensionController] = [:]
    /// Each extension read from disk once, by path.
    private var extensions: [String: WKWebExtension] = [:]
    /// What each loaded context was granted.
    private var grants: [ObjectIdentifier: WebExtensionContextSpec] = [:]

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
            webExtension = try await extensionAt(path: spec.path)
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

    private func extensionAt(path: String) async throws -> WKWebExtension {
        if let cached = extensions[path] {
            return cached
        }
        let webExtension = try await WKWebExtension(
            resourceBaseURL: URL(fileURLWithPath: path, isDirectory: true))
        extensions[path] = webExtension
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
                                openNewTabUsing configuration: WKWebExtension.TabConfiguration,
                                for extensionContext: WKWebExtensionContext,
                                completionHandler: @escaping ((any WKWebExtensionTab)?, (any Error)?) -> Void) {
        completionHandler(nil, WebExtensionHost.refusal("This browser does not open tabs for extensions"))
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
#endif
