part of 'main.dart';

void onReceivedHttpAuthRequest() {
  final shouldSkip = !InAppWebView.isPropertySupported(
    PlatformWebViewCreationParamsProperty.onReceivedHttpAuthRequest,
  );

  skippableTestWidgets('onReceivedHttpAuthRequest', (
    WidgetTester tester,
  ) async {
    final Completer<InAppWebViewController> controllerCompleter =
        Completer<InAppWebViewController>();
    final Completer<void> pageLoaded = Completer<void>();
    final List<HttpAuthenticationChallenge> challenges = [];

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: InAppWebView(
          key: GlobalKey(),
          initialUrlRequest: URLRequest(
            url: WebUri("http://${environment["NODE_SERVER_IP"]}:8081/"),
          ),
          initialSettings: InAppWebViewSettings(clearCache: true),
          onWebViewCreated: (controller) {
            controllerCompleter.complete(controller);
          },
          onLoadStop: (controller, url) {
            if (!pageLoaded.isCompleted) {
              pageLoaded.complete();
            }
          },
          onReceivedHttpAuthRequest: (controller, challenge) async {
            challenges.add(challenge);
            // A wrong password first, so that the server challenges again.
            return new HttpAuthResponse(
              username: "USERNAME",
              password: challenges.length == 1 ? "WRONG_PASSWORD" : "PASSWORD",
              action: HttpAuthResponseAction.PROCEED,
            );
          },
        ),
      ),
    );

    final InAppWebViewController controller = await controllerCompleter.future;
    await pageLoaded.future;

    expect(challenges.length, 2);
    expect(challenges[0].protectionSpace.host, environment["NODE_SERVER_IP"]);
    expect(challenges[0].protectionSpace.realm, "Node");
    expect(
      challenges[1].previousFailureCount,
      greaterThan(challenges[0].previousFailureCount),
    );

    final String h1Content = await controller.evaluateJavascript(
      source: "document.body.querySelector('h1').textContent",
    );
    expect(h1Content, "Authorized");
  }, skip: shouldSkip);
}
