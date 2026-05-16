//
//  ContentRuleListCache.swift
//  flutter_inappwebview
//
//  Hash-keyed wrapper around WKContentRuleListStore. The upstream
//  call sites used a fixed identifier ("ContentBlockingRules") and
//  called removeAllContentRuleLists + compileContentRuleList on
//  every WebView creation. Compilation runs at the WebKit engine
//  level and for tens of thousands of ABP rules can take several
//  seconds, blocking initial page load for every new tab.
//
//  Strategy:
//   - Caller supplies an opaque identifier (or we hash the JSON
//     locally). Identifier is the WKContentRuleListStore key.
//   - lookUpContentRuleList by identifier first → cheap when warm.
//   - On miss, compile once and coalesce concurrent compile
//     requests so N parallel WebView creates trigger one compile.
//   - After install, walk the store and purge any iaw-rl-* entry
//     that isn't the active identifier. Without this, every rule
//     edit leaves the previous compiled bytecode on disk forever.
//

import Foundation
import WebKit
import CommonCrypto

@available(macOS 10.13, *)
public class ContentRuleListCache {
    /// Prefix every identifier we own. Used by [purgeStale] to find
    /// our entries without touching identifiers a different consumer
    /// of WKContentRuleListStore in the same app may have installed.
    public static let identifierPrefix = "iaw-rl-"

    private static let inFlightQueue = DispatchQueue(
        label: "com.pichillilorenzo.flutter_inappwebview.ContentRuleListCache.inflight"
    )
    private static var inFlight: [String: [(WKContentRuleList?) -> Void]] = [:]

    /// Apply the content rule list described by `contentBlockers` to
    /// `controller`.
    ///
    /// Identifier resolution:
    ///   1. `identifier` parameter (caller-supplied, e.g. a Dart-side
    ///      sha256 already computed) wins when provided.
    ///   2. Otherwise the JSON body is hashed (sha256) so identical
    ///      payloads converge on the same WKContentRuleListStore
    ///      entry across WebView creations and across launches.
    ///
    /// The identifier is always prefixed with [identifierPrefix] so
    /// purgeStale can find this consumer's entries unambiguously.
    public static func apply(
        contentBlockers: [[String: [String: Any]]],
        identifier: String? = nil,
        to controller: WKUserContentController,
        completion: ((WKContentRuleList?) -> Void)? = nil
    ) {
        guard !contentBlockers.isEmpty else {
            controller.removeAllContentRuleLists()
            completion?(nil)
            return
        }

        let blockRules: String
        do {
            let jsonData = try JSONSerialization.data(
                withJSONObject: contentBlockers,
                options: [.sortedKeys])
            guard let s = String(data: jsonData, encoding: .utf8) else {
                completion?(nil)
                return
            }
            blockRules = s
        } catch {
            print("[flutter_inappwebview] content rule list serialize failed: \(error.localizedDescription)")
            completion?(nil)
            return
        }

        let resolvedId: String
        if let caller = identifier, !caller.isEmpty {
            resolvedId = identifierPrefix + caller
        } else {
            resolvedId = identifierPrefix + sha256Hex(blockRules)
        }

        // WKUserContentController has no public API to enumerate the
        // attached rule lists, so we removeAll and re-add after the
        // lookup resolves. The remove path is a metadata flip — cheap.
        controller.removeAllContentRuleLists()

        WKContentRuleListStore.default().lookUpContentRuleList(forIdentifier: resolvedId) { existing, _ in
            if let existing = existing {
                controller.add(existing)
                completion?(existing)
                purgeStale(except: resolvedId)
                return
            }
            compileAndInstall(
                identifier: resolvedId,
                blockRules: blockRules,
                controller: controller,
                completion: completion
            )
        }
    }

    /// Remove every `iaw-rl-*` entry from WKContentRuleListStore
    /// except the one currently active. Stops stale compiled
    /// bytecode from accumulating on disk forever after each rule
    /// edit. Safe to call from any thread; the store hops to its
    /// own queue internally.
    ///
    /// `WKContentRuleListStore.getAvailableContentRuleListIdentifiers`
    /// is a documented public API (iOS 11+, macOS 10.13+) and the
    /// only way to enumerate the store without keeping our own
    /// sidecar registry. Pass nil from upstream callers that don't
    /// track identifiers — we'll wipe every entry we own.
    public static func purgeStale(except keepIdentifier: String?) {
        WKContentRuleListStore.default().getAvailableContentRuleListIdentifiers { ids in
            guard let ids = ids else { return }
            for id in ids {
                guard id.hasPrefix(identifierPrefix) else { continue }
                if id == keepIdentifier { continue }
                WKContentRuleListStore.default().removeContentRuleList(forIdentifier: id) { error in
                    if let error = error {
                        print("[flutter_inappwebview] failed to purge stale rule list \(id): \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private static func compileAndInstall(
        identifier: String,
        blockRules: String,
        controller: WKUserContentController,
        completion: ((WKContentRuleList?) -> Void)?
    ) {
        // Coalesce concurrent compile requests for the same identifier
        // — every InAppWebView/InAppBrowser creation calls apply()
        // independently, and without coalescing they race the
        // WKContentRuleListStore compile-cache.
        let queued: Bool = inFlightQueue.sync {
            if inFlight[identifier] != nil {
                inFlight[identifier]!.append { ruleList in
                    if let ruleList = ruleList { controller.add(ruleList) }
                    completion?(ruleList)
                }
                return true
            }
            inFlight[identifier] = []
            return false
        }
        if queued { return }

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: blockRules
        ) { ruleList, error in
            if let error = error {
                print("[flutter_inappwebview] content rule list compile failed: \(error.localizedDescription)")
            }
            if let ruleList = ruleList {
                controller.add(ruleList)
            }
            completion?(ruleList)

            let waiters: [(WKContentRuleList?) -> Void] = inFlightQueue.sync {
                let w = inFlight[identifier] ?? []
                inFlight.removeValue(forKey: identifier)
                return w
            }
            for waiter in waiters {
                waiter(ruleList)
            }

            // Purge stale identifiers AFTER the new one is in the
            // store, so a transient store enumeration during compile
            // can't return an empty set.
            if ruleList != nil {
                purgeStale(except: identifier)
            }
        }
    }

    private static func sha256Hex(_ s: String) -> String {
        let data = Data(s.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buf in
            _ = CC_SHA256(buf.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
