import FlutterMacOS
import Cocoa
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

}
