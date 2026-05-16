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
//  This helper hashes the JSON, queries the WKContentRuleListStore
//  disk cache by hashed identifier first, and only compiles when
//  the disk cache misses. The store persists across app launches,
//  so once an identifier compiles the result survives until the
//  ruleset changes (different hash) or the OS evicts it.
//

import Foundation
import WebKit
import CommonCrypto

@available(iOS 11.0, *)
public class ContentRuleListCache {
    private static let identifierPrefix = "iaw-rl-"
    private static let inFlightQueue = DispatchQueue(
        label: "com.pichillilorenzo.flutter_inappwebview.ContentRuleListCache.inflight"
    )
    private static var inFlight: [String: [(WKContentRuleList?) -> Void]] = [:]

    /// Apply the content rule list described by `contentBlockers` to
    /// `controller`. Looks the compiled list up by hash first; if the
    /// store doesn't have it, compiles once and feeds every caller
    /// waiting on the same identifier. Calls `completion` on the main
    /// queue with the installed rule list (or nil on failure).
    public static func apply(
        contentBlockers: [[String: [String: Any]]],
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

        let identifier = identifierPrefix + sha256Hex(blockRules)

        // Drop any previously-installed rule list whose identifier
        // doesn't match the one we're about to install. Different
        // identifier → different ruleset, so the old one's actions
        // would still fire alongside the new ones if left attached.
        controller.removeContentRuleLists(notMatching: identifier)

        WKContentRuleListStore.default().lookUpContentRuleList(forIdentifier: identifier) { existing, _ in
            if let existing = existing {
                controller.add(existing)
                completion?(existing)
                return
            }
            compileAndInstall(
                identifier: identifier,
                blockRules: blockRules,
                controller: controller,
                completion: completion
            )
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

@available(iOS 11.0, *)
private extension WKUserContentController {
    /// Remove every installed rule list whose identifier is not
    /// `keepIdentifier`. Cheap when nothing is installed; the
    /// userContentController doesn't expose its installed identifiers
    /// so we fall through to removeAll when we can't introspect.
    func removeContentRuleLists(notMatching keepIdentifier: String) {
        // WKUserContentController has no public API to enumerate the
        // currently-attached rule lists. The safe default is to
        // remove all and let the caller re-add the desired one — the
        // remove path is a metadata flip, not a recompile, so it's
        // cheap. The caller adds back the rule list once
        // apply() resolves the lookup/compile.
        removeAllContentRuleLists()
    }
}
