part of 'main.dart';

// A container's storage session outlives its WebViews, so a proxy change for
// the container lands on a session that may still pool a connection opened
// through the old proxy. Each case loads through proxy A, disposes the
// WebView, rebuilds it on the same container with proxy B and checks which
// proxy served the second load: B means the change took effect, A means the
// container kept using the old route. ContainerController.resetNetworkSession
// is meant to force a fresh session in between.
void containerProxyChange() {
  final shouldSkip =
      !InAppWebViewSettings.isPropertySupported(
        InAppWebViewSettingsProperty.proxySettings,
      ) ||
      !InAppWebViewSettings.isPropertySupported(
        InAppWebViewSettingsProperty.containerId,
      );
  final resetSupported =
      !shouldSkip &&
      ContainerController.isMethodSupported(
        PlatformContainerControllerMethod.resetNetworkSession,
      );

  // test_node_server: HTTP proxies on 8083/8084, SOCKS5 proxies on 8085/8086,
  // each answering with its own id.
  const ports = {
    'http': [8083, 8084],
    'socks5': [8085, 8086],
  };

  for (final scheme in ports.keys) {
    for (final reset in [false, true]) {
      skippableTestWidgets(
        'container proxy change from A to B over $scheme, '
        '${reset ? 'with' : 'without'} resetNetworkSession',
        (WidgetTester tester) async {
          final stamp = DateTime.now().millisecondsSinceEpoch;
          final containerId = 'proxy-change-$scheme-$reset-$stamp';

          Future<String?> load(int proxyPort, String step) async {
            final controllerCompleter = Completer<InAppWebViewController>();
            final pageLoaded = Completer<void>();
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: InAppWebView(
                  key: GlobalKey(),
                  initialUrlRequest: URLRequest(
                    url: WebUri('http://www.example.com/$step?$stamp'),
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    containerId: containerId,
                    proxySettings: ProxySettings(
                      proxyRules: [
                        ProxyRule(
                          url:
                              '$scheme://${environment["NODE_SERVER_IP"]}:$proxyPort',
                        ),
                      ],
                    ),
                  ),
                  onWebViewCreated: controllerCompleter.complete,
                  onLoadStop: (_, _) {
                    if (!pageLoaded.isCompleted) pageLoaded.complete();
                  },
                ),
              ),
            );
            final controller = await controllerCompleter.future;
            await tester.pump();
            await pageLoaded.future;
            final served = await controller.evaluateJavascript(
              source: "document.getElementById('proxy')?.innerHTML ?? null;",
            );
            // Dispose the WebView so nothing but the container holds its
            // session.
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            return served?.toString();
          }

          expect(await load(ports[scheme]![0], 'first'), 'A');

          if (reset) {
            // WebKit lets go of the disposed WebView asynchronously; the
            // reset waits for that itself. Logged rather than asserted, so
            // the second load still shows which proxy served it.
            final released = await ContainerController.instance()
                .resetNetworkSession(containerId);
            // ignore: avoid_print
            print('PROXY-CHANGE $scheme resetNetworkSession returned $released');
          }

          final second = await load(ports[scheme]![1], 'second');
          // ignore: avoid_print
          print(
            'PROXY-CHANGE $scheme reset=$reset: second load served by '
            '${second ?? 'no proxy'}',
          );
          expect(
            second,
            'B',
            reason: 'after the container moved to proxy B its next load still '
                'went out through ${second ?? 'no proxy'}',
          );
        },
        skip: shouldSkip || (reset && !resetSupported),
      );
    }
  }
}
