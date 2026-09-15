import FlutterMacOS
import Cocoa
import Network
import WebKit
import XCTest

@testable import flutter_inappwebview_macos

// This demonstrates a simple unit test of the Swift portion of this plugin's implementation.
//
// See https://developer.apple.com/documentation/xctest for more information about using XCTest.

class RunnerTests: XCTestCase {

  func testGetPlatformVersion() {
    let plugin = FlutterInappwebviewMacosPlugin()

    let call = FlutterMethodCall(methodName: "getPlatformVersion", arguments: [])

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertEqual(result as! String,
                     "macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  // Regression guard for the cold-start EXC_BAD_ACCESS in
  // WTF::RunLoop::dispatch when fetchAllDataStoreIdentifiers /
  // WKWebsiteDataStore(forIdentifier:) is the first WebKit touch in
  // the process. See ContainerManager.ensureWebKitInitialized() docs.
  //
  // The XCTest target shares a process with anything earlier in the
  // suite, so we can't make this test truly "cold WebKit" — but we
  // can prove (a) the warmup helper still flips its flag and is
  // idempotent and (b) calling fetchAllDataStoreIdentifiers after
  // the warmup reaches its completion. If a future change drops the
  // warmup body or stops calling ensureWebKitInitialized at the
  // entry points, those properties stop holding.

  @available(macOS 14.0, *)
  func testEnsureWebKitInitializedIsIdempotent() {
    // Reset shared state so this test's assertion about the first
    // call is meaningful regardless of suite ordering.
    ContainerManager.didWarmUpWebKit = false

    ContainerManager.ensureWebKitInitialized()
    XCTAssertTrue(ContainerManager.didWarmUpWebKit,
                  "ensureWebKitInitialized should set the warmup flag on first call")

    // Second call is a no-op; the flag stays true and nothing crashes.
    ContainerManager.ensureWebKitInitialized()
    XCTAssertTrue(ContainerManager.didWarmUpWebKit)
  }

  @available(macOS 14.0, *)
  func testFetchAllDataStoreIdentifiersReachesCompletionAfterWarmup() {
    ContainerManager.ensureWebKitInitialized()

    let completion = expectation(description: "fetchAllDataStoreIdentifiers completion ran")
    WKWebsiteDataStore.fetchAllDataStoreIdentifiers { _ in
      // We don't care about the identifier list; we care that the
      // closure was reached. Pre-fix, WebKit could crash inside
      // WTF::RunLoop::dispatch before getting here.
      completion.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  // containerIdToUUID is the contract consumers pin their on-disk data
  // stores to: same string → same UUID across launches, rebuilds and
  // plugin versions. If this golden value ever drifts, every existing
  // container silently detaches from its data at the next app update —
  // so never "fix" the expected value here; fix whatever broke the
  // derivation instead. Expected value is SHA-256("ws-golden-container")
  // truncated to its first 16 bytes and formatted as a UUID. It is
  // deliberately identical to the iOS golden value: the derivation is
  // shared so a container id maps to the same UUID on both platforms.
  @available(macOS 14.0, *)
  func testContainerIdToUUIDIsStable() {
    XCTAssertEqual(containerIdToUUID("ws-golden-container").uuidString,
                   "EBC4B01E-6B6C-DAEB-E0D3-F38061A618A4")
    XCTAssertEqual(containerIdToUUID("ws-golden-container"),
                   containerIdToUUID("ws-golden-container"),
                   "same id must derive the same UUID within a process")
    XCTAssertNotEqual(containerIdToUUID("ws-golden-container"),
                      containerIdToUUID("ws-other-container"),
                      "distinct ids must not collide")
  }

  // The shared-wrapper cache is what keeps every WebView in a container
  // and every controller op on the same WKWebsiteDataStore instance —
  // wrapper duplication is what remove(forIdentifier:) counts as
  // "in use". Identity (===) is the property that matters, not equality.
  @available(macOS 14.0, *)
  func testGetOrCreateDataStoreReturnsSharedWrapper() {
    let first = ContainerManager.getOrCreateDataStore(forContainer: "runner-test-shared")
    let second = ContainerManager.getOrCreateDataStore(forContainer: "runner-test-shared")
    XCTAssertTrue(first === second,
                  "same containerId must resolve to the same wrapper instance")

    let other = ContainerManager.getOrCreateDataStore(forContainer: "runner-test-other")
    XCTAssertFalse(first === other,
                   "different containerIds must not share a wrapper")
  }

  // `proxySettings` is typed [String: Any?]?, which Objective-C cannot
  // represent, so @objcMembers emits no selector for it and
  // ISettings.parse's responds(to:) path skipped the key without a word.
  // The explicit branch in InAppWebViewSettings.parse is the only thing
  // binding it, and preWKWebViewConfiguration assigns
  // websiteDataStore.proxyConfigurations only for a non-nil value — so
  // before that branch a WebView pinned to a proxy quietly loaded over the
  // device IP while the Dart side believed it had sent one. The value goes
  // in as an NSDictionary because that is what FlutterStandardMessageCodec
  // decodes a Dart map into: the branch's `as? [String: Any?]` has to
  // survive that bridge, not just a native Swift literal.
  @available(macOS 14.0, *)
  func testParseBindsProxySettings() {
    let proxyMap: NSDictionary = [
      "proxyRules": [["url": "socks5://127.0.0.1:9050"]]
    ]

    let parsed = InAppWebViewSettings().parse(settings: [
      "containerId": "runner-test-proxy",
      "proxySettings": proxyMap,
    ])

    XCTAssertNotNil(parsed.proxySettings,
                    "parse must bind proxySettings; preWKWebViewConfiguration skips a nil one")
    XCTAssertEqual(ProxySettings.fromMap(map: parsed.proxySettings)?.proxyRules.first?.url,
                   "socks5://127.0.0.1:9050",
                   "the bound map must still convert into ProxySettings")

    // containerId is a plain String?, which KVC does carry. It rides along
    // to show the failure was specific to the non-representable type
    // rather than to settings parsing at large.
    XCTAssertEqual(parsed.containerId, "runner-test-proxy")
  }

  // Companion to the above. If this ever starts responding, the property
  // became Objective-C representable and super.parse can carry it on its
  // own — at which point the explicit branch is redundant rather than
  // load-bearing, and this test is the place that says so.
  func testProxySettingsIsNotKeyValueCodable() {
    XCTAssertFalse(InAppWebViewSettings().responds(to: Selector("proxySettings")),
                   "no selector expected; if one appears the property type changed")
  }

  // ProxyController.setProxyOverride reaches WKWebsiteDataStore.default(),
  // .nonPersistent() and the container stores cached at the time of the call.
  // A container store is created lazily, the first time a WebView joins that
  // container, so an override set beforehand -- the usual ordering, proxy at
  // startup and WebViews after -- has to be replayed onto it here. Without
  // that, a contained WebView loads over the device IP while an override is
  // in force.
  @available(macOS 14.0, *)
  func testContainerStoreCreatedLaterInheritsProxyOverride() {
    ProxyManager.activeProxyConfigurations = [
      ProxyConfiguration(httpCONNECTProxy: .hostPort(host: "127.0.0.1", port: 8083))
    ]
    defer { ProxyManager.activeProxyConfigurations = nil }

    let store = ContainerManager.getOrCreateDataStore(forContainer: "runner-test-proxy-replay")
    XCTAssertEqual(store.proxyConfigurations.count, 1,
                   "a container store created while an override is active must carry it")
  }

  @available(macOS 14.0, *)
  func testContainerStoreCarriesNoProxyWhenNoOverrideIsActive() {
    ProxyManager.activeProxyConfigurations = nil

    let store = ContainerManager.getOrCreateDataStore(forContainer: "runner-test-proxy-none")
    XCTAssertTrue(store.proxyConfigurations.isEmpty,
                  "with no override active the store is left alone")
  }

  // The process-wide override is the fallback for sites that named no
  // proxy of their own, so it must not reach a store a WebView pinned:
  // overwriting it swaps that site's proxy for the global one, and
  // clearing it drops the site to the device IP. Assigning an empty array
  // is the only call in this stack that reaches WebKit's
  // clearProxyConfigData, and clearProxyOverride used to make it over
  // every container store at once.
  @available(macOS 14.0, *)
  func testPinnedStoreIsNotClobberedByTheOverrideFanOut() {
    let store = ContainerManager.getOrCreateDataStore(forContainer: "runner-test-proxy-pinned")
    // Two, so the count distinguishes this from the single-entry override.
    store.proxyConfigurations = [
      ProxyConfiguration(socksv5Proxy: .hostPort(host: "127.0.0.1", port: 9050)),
      ProxyConfiguration(socksv5Proxy: .hostPort(host: "127.0.0.1", port: 9051)),
    ]
    ProxyManager.pinPerSiteProxy(to: store)
    defer { ProxyManager.releasePerSiteProxy(from: store) }

    ProxyManager.fanOutToFollowingStores([
      ProxyConfiguration(httpCONNECTProxy: .hostPort(host: "127.0.0.1", port: 8083))
    ])
    XCTAssertEqual(store.proxyConfigurations.count, 2,
                   "setting the override must not overwrite a pinned site's proxy")

    ProxyManager.fanOutToFollowingStores([])
    XCTAssertEqual(store.proxyConfigurations.count, 2,
                   "clearing the override must not drop a pinned site to the device IP")
  }

  // The control: a container store nobody pinned still follows the
  // override, which is what the fan-out exists for.
  @available(macOS 14.0, *)
  func testUnpinnedContainerStoreStillFollowsTheOverride() {
    let store = ContainerManager.getOrCreateDataStore(forContainer: "runner-test-proxy-unpinned")

    ProxyManager.fanOutToFollowingStores([
      ProxyConfiguration(httpCONNECTProxy: .hostPort(host: "127.0.0.1", port: 8083))
    ])
    XCTAssertEqual(store.proxyConfigurations.count, 1,
                   "a store with no proxy of its own must take the override")

    ProxyManager.fanOutToFollowingStores([])
    XCTAssertTrue(store.proxyConfigurations.isEmpty,
                  "and must give it up when the override is cleared")
  }

  // A WebView that binds the store and names no proxy hands it back to
  // the override, so a site whose proxy was removed stops using the old one.
  @available(macOS 14.0, *)
  func testReleaseHandsTheStoreBackToTheOverride() {
    let store = ContainerManager.getOrCreateDataStore(forContainer: "runner-test-proxy-released")
    store.proxyConfigurations = [
      ProxyConfiguration(socksv5Proxy: .hostPort(host: "127.0.0.1", port: 9050))
    ]
    ProxyManager.pinPerSiteProxy(to: store)

    ProxyManager.activeProxyConfigurations = nil
    ProxyManager.releasePerSiteProxy(from: store)
    XCTAssertTrue(store.proxyConfigurations.isEmpty,
                  "with no override active the released store carries nothing")
    XCTAssertFalse(ProxyManager.carriesPerSiteProxy(store),
                   "and it follows the fan-out again")
  }

  // toProxyConfigurations refuses a rule set that does not fully convert,
  // rather than handing back the rules that did. The empty array it used to
  // produce is not a no-op: WKWebsiteDataStore routes an empty array to
  // clearProxyConfigData, so one unusable rule would strip the proxy off a
  // live session instead of being refused.
  @available(macOS 14.0, *)
  func testPartiallyConvertibleRuleSetIsRefused() {
    let usable: [String: Any?] = [
      "proxyRules": [["url": "socks5://127.0.0.1:9050"]] as [[String: Any?]]
    ]
    XCTAssertEqual(ProxySettings.fromMap(map: usable)?.toProxyConfigurations()?.count, 1)

    // An empty url becomes "http://", which has no host, so that rule cannot
    // become a ProxyConfiguration.
    let partly: [String: Any?] = [
      "proxyRules": [["url": "socks5://127.0.0.1:9050"], ["url": ""]] as [[String: Any?]]
    ]
    XCTAssertNil(ProxySettings.fromMap(map: partly)?.toProxyConfigurations(),
                 "one unusable rule must refuse the whole set, not clear the proxy")
  }

}
