//
//  ContainerManager.swift
//  flutter_inappwebview
//
//  MethodChannel handler for the per-WebView profile controller. Wraps
//  WKWebsiteDataStore's identifier-based APIs (iOS 17+ / macOS 14+) and
//  maintains an `containerId → UUID` side-map in UserDefaults so the
//  caller can read profile names back instead of opaque UUIDs.
//
//  The map is updated automatically when a containerId is bound (see
//  InAppWebView.preWKWebViewConfiguration's call to
//  ContainerManager.registerContainerBinding) and when a profile is
//  deleted via this controller. getAllContainerNames intersects the
//  registry with WKWebsiteDataStore.allDataStoreIdentifiers, so stale
//  registry entries (where the underlying store has been removed out
//  of band) are filtered out automatically.
//

import Foundation
import WebKit
import Flutter

@available(iOS 17.0, *)
public class ContainerManager: ChannelDelegate {
    static let METHOD_CHANNEL_NAME = "com.pichillilorenzo/flutter_inappwebview_containercontroller"

    // UserDefaults suite + key for the id ↔ UUID side-map.
    // - Suite name keeps our keys out of the host app's defaults.
    // - The dictionary is `containerId(String) → uuidString(String)`.
    // - Survives app restarts; wiped on app uninstall (which also
    //   wipes the underlying WKWebsiteDataStore data, so the two stay
    //   consistent).
    private static let registrySuiteName =
        "com.pichillilorenzo.flutter_inappwebview.containers"
    private static let registryKey = "id_to_uuid"

    private static func registry() -> UserDefaults {
        return UserDefaults(suiteName: registrySuiteName) ?? UserDefaults.standard
    }

    private static func loadIdMap() -> [String: String] {
        return registry().dictionary(forKey: registryKey) as? [String: String] ?? [:]
    }

    private static func saveIdMap(_ map: [String: String]) {
        registry().set(map, forKey: registryKey)
    }

    // Called from InAppWebView.preWKWebViewConfiguration whenever a
    // containerId is bound to a WKWebsiteDataStore, so getAllContainerNames
    // can later recover the original string from Apple's UUID list.
    public static func registerContainerBinding(_ containerId: String, uuid: UUID) {
        var map = loadIdMap()
        map[containerId] = uuid.uuidString
        saveIdMap(map)
    }

    private var plugin: InAppWebViewFlutterPlugin?

    init(plugin: InAppWebViewFlutterPlugin) {
        super.init(channel: FlutterMethodChannel(
            name: ContainerManager.METHOD_CHANNEL_NAME,
            binaryMessenger: plugin.registrar.messenger()))
        self.plugin = plugin
    }

    public override func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        switch call.method {
        case "getAllContainerNames":
            getAllContainerNames(result: result)
        case "hasContainer":
            guard let containerId = args?["containerId"] as? String, !containerId.isEmpty else {
                result(false); return
            }
            hasContainer(containerId, result: result)
        case "deleteContainer":
            guard let containerId = args?["containerId"] as? String, !containerId.isEmpty else {
                result(false); return
            }
            deleteContainer(containerId, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func getAllContainerNames(result: @escaping FlutterResult) {
        WKWebsiteDataStore.fetchAllDataStoreIdentifiers { uuids in
            let liveUUIDs = Set(uuids.map { $0.uuidString.lowercased() })
            let map = ContainerManager.loadIdMap()
            // Only return ids whose UUID is still materialized — drop
            // stale registry entries.
            let names = map.compactMap { (id, uuidStr) -> String? in
                liveUUIDs.contains(uuidStr.lowercased()) ? id : nil
            }
            DispatchQueue.main.async { result(names) }
        }
    }

    private func hasContainer(_ containerId: String, result: @escaping FlutterResult) {
        let target = containerIdToUUID(containerId).uuidString.lowercased()
        WKWebsiteDataStore.fetchAllDataStoreIdentifiers { uuids in
            let exists = uuids.contains { $0.uuidString.lowercased() == target }
            DispatchQueue.main.async { result(exists) }
        }
    }

    private func deleteContainer(_ containerId: String, result: @escaping FlutterResult) {
        let uuid = containerIdToUUID(containerId)
        WKWebsiteDataStore.remove(forIdentifier: uuid) { error in
            // Apple returns an error when the store doesn't exist or
            // when a WKWebView is still using it. Treat both as "did
            // not delete" — true means we deleted, false means we
            // didn't.
            let deleted = (error == nil)
            if deleted {
                var map = ContainerManager.loadIdMap()
                map.removeValue(forKey: containerId)
                ContainerManager.saveIdMap(map)
            }
            DispatchQueue.main.async { result(deleted) }
        }
    }

    public override func dispose() {
        super.dispose()
        plugin = nil
    }
}
