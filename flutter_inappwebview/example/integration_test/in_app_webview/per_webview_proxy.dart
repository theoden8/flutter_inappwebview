part of 'main.dart';

void perWebViewProxy() {
  // `proxySettings` is honored on iOS 17+ / macOS 14+ only, where
  // WKWebsiteDataStore.proxyConfigurations can scope a proxy to a single
  // WebView. Everywhere else the setting is serialized and ignored.
  final shouldSkip = !InAppWebViewSettings.isPropertySupported(
    InAppWebViewSettingsProperty.proxySettings,
  );

  // The test server's proxy (port 8083) answers *any* request with its own
  // "Proxy Works" page instead of forwarding, so the page that comes back is
  // itself the evidence: if the proxy is bound we get the marker document, and
  // if it is ignored we get whatever www.example.com serves (or a failure,
  // offline). That distinction is the whole point — the property is typed
  // `[String: Any?]?`, which Objective-C cannot represent, so it went
  // unparsed and the WebView silently loaded over the device IP while the
  // Dart side believed it had sent a proxy.
  skippableTestWidgets('proxySettings routes a single WebView through the proxy', (
    WidgetTester tester,
  ) async {
    final controllerCompleter = Completer<InAppWebViewController>();
    final pageLoaded = Completer<void>();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: InAppWebView(
          key: GlobalKey(),
          initialUrlRequest: URLRequest(url: TEST_URL_HTTP_EXAMPLE),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            proxySettings: ProxySettings(
              proxyRules: [
                ProxyRule(url: "${environment["NODE_SERVER_IP"]}:8083"),
              ],
            ),
          ),
          onWebViewCreated: controllerCompleter.complete,
          onLoadStop: (_, _) => pageLoaded.complete(),
        ),
      ),
    );

    final controller = await controllerCompleter.future;
    await tester.pump();
    await pageLoaded.future;

    // Served by the proxy, not by www.example.com. `#url` is the request line
    // the proxy saw, which is the full URL on some platforms and just the path
    // on others — same split the ProxyController test documents.
    expect(
      await controller.evaluateJavascript(
        source: "document.getElementById('method').innerHTML;",
      ),
      "GET",
      reason: 'the page must come from the proxy, not from the origin',
    );
    expect(
      await controller.evaluateJavascript(
        source: "document.getElementById('url').innerHTML;",
      ),
      anyOf("/", TEST_URL_HTTP_EXAMPLE.toString()),
    );
  }, skip: shouldSkip);
}
