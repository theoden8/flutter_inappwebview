//
//  WKProcessPoolManager.swift
//  flutter_inappwebview
//
//  Created by Lorenzo Pichilli on 19/11/2019.
//

import Foundation
import WebKit

public class WKProcessPoolManager {
    static let sharedProcessPool = WKProcessPool()

    // One pool per container, so a WebView that carries its own
    // WKWebsiteDataStore does not share a pool with WebViews carrying other
    // stores. Experiment for the per-site proxy defect: only the first store
    // in a process has its proxyConfigurations honoured, and a WKProcessPool
    // has historically been bound to a single network session, which would
    // explain it. Keyed by container id, since that is what decides which
    // store a WebView gets.
    private static var containerPools: [String: WKProcessPool] = [:]
    private static let containerPoolsLock = NSLock()

    static func processPool(forContainer containerId: String) -> WKProcessPool {
        containerPoolsLock.lock()
        defer { containerPoolsLock.unlock() }
        if let pool = containerPools[containerId] { return pool }
        let pool = WKProcessPool()
        containerPools[containerId] = pool
        return pool
    }
}
