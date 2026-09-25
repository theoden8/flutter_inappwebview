part of 'main.dart';

// Does WebRTC go through the WebView's proxy? The page loads through proxy A,
// then gathers ICE candidates against the fixture's STUN server. The HTTP
// proxy only tunnels TCP; the SOCKS5 proxy also relays UDP when asked with
// UDP ASSOCIATE. The fixture logs every STUN binding request and whether it
// came through a SOCKS relay: one that did not went out directly, around
// the proxy.
void webRTCBehindProxy() {
  // How each platform takes a proxy: per WebView (on its container) on
  // Apple and Linux, process-wide on Android, as a browser argument of the
  // WebView2 environment on Windows.
  final perWebView =
      InAppWebViewSettings.isPropertySupported(
        InAppWebViewSettingsProperty.proxySettings,
      ) &&
      InAppWebViewSettings.isPropertySupported(
        InAppWebViewSettingsProperty.containerId,
      );
  final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  final processWide = !perWebView && ProxyController.isClassSupported();
  final shouldSkip = kIsWeb || (!perWebView && !processWide && !isWindows);

  const ports = {'http': 8083, 'socks5': 8085};

  Future<Map<String, dynamic>> fixture(String path) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('http://${environment["NODE_SERVER_IP"]}:8082$path'),
      );
      final response = await request.close();
      return jsonDecode(await response.transform(utf8.decoder).join())
          as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  for (final scheme in ports.keys) {
    skippableTestWidgets('WebRTC behind a $scheme proxy', (
      WidgetTester tester,
    ) async {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final proxyUrl =
          '$scheme://${environment["NODE_SERVER_IP"]}:${ports[scheme]}';
      final proxy = ProxySettings(proxyRules: [ProxyRule(url: proxyUrl)]);

      WebViewEnvironment? webViewEnvironment;
      if (isWindows) {
        final dir = await getTemporaryDirectory();
        webViewEnvironment = await WebViewEnvironment.create(
          settings: WebViewEnvironmentSettings(
            userDataFolder: '${dir.path}/webrtc-$scheme-$stamp',
            additionalBrowserArguments: '--proxy-server=$proxyUrl',
          ),
        );
      } else if (processWide) {
        await ProxyController.instance().setProxyOverride(settings: proxy);
      }

      try {
        await fixture('/webrtc-log/reset');

        final controllerCompleter = Completer<InAppWebViewController>();
        final pageLoaded = Completer<void>();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: InAppWebView(
              key: GlobalKey(),
              webViewEnvironment: webViewEnvironment,
              initialUrlRequest: URLRequest(
                url: WebUri('http://www.example.com/webrtc?$stamp'),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                containerId: perWebView ? 'webrtc-$scheme-$stamp' : null,
                proxySettings: perWebView ? proxy : null,
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

        expect(
          await controller.evaluateJavascript(
            source: "document.getElementById('proxy')?.innerHTML ?? null;",
          ),
          'A',
          reason:
              'the page has to come through the proxy for the rest to mean '
              'anything',
        );

        await controller.evaluateJavascript(
          source:
              '''
(function() {
  window.__webrtc = {done: false};
  if (typeof RTCPeerConnection === 'undefined') {
    window.__webrtc = {done: true, available: false, candidates: []};
    return;
  }
  var candidates = [];
  var pc = new RTCPeerConnection({
    iceServers: [{urls: 'stun:${environment["NODE_SERVER_IP"]}:3478'}]
  });
  var finish = function(error) {
    if (window.__webrtc.done) return;
    window.__webrtc = {
      done: true, available: true, candidates: candidates,
      state: pc.iceGatheringState, error: error || null
    };
    pc.close();
  };
  pc.onicecandidate = function(e) {
    if (e.candidate && e.candidate.candidate) {
      candidates.push(e.candidate.candidate);
    } else if (!e.candidate) {
      finish();
    }
  };
  pc.createDataChannel('probe');
  pc.createOffer()
    .then(function(offer) { return pc.setLocalDescription(offer); })
    .catch(function(e) { finish(String(e)); });
  setTimeout(function() { finish('timed out'); }, 10000);
})();
''',
        );

        Map<String, dynamic> gathered = {};
        for (var i = 0; i < 30; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          final raw = await controller.evaluateJavascript(
            source: 'JSON.stringify(window.__webrtc)',
          );
          final decoded = raw == null ? null : jsonDecode(raw.toString());
          if (decoded is Map) gathered = decoded.cast<String, dynamic>();
          if (gathered['done'] == true) break;
        }
        // STUN retransmits and late candidates.
        await Future.delayed(const Duration(seconds: 1));
        final log = await fixture('/webrtc-log');

        final stun = (log['stun'] as List).cast<Map<String, dynamic>>();
        final direct = stun.where((r) => r['viaSocks'] != true).toList();
        final relayed = stun.where((r) => r['viaSocks'] == true).toList();
        // ignore: avoid_print
        print(
          'WEBRTC-PROXY ${defaultTargetPlatform.name} $scheme: '
          'available=${gathered['available']} error=${gathered['error']} '
          'stun direct=${direct.length} relayed=${relayed.length} '
          'socks=${jsonEncode(log['socks'])} http=${jsonEncode(log['http'])} '
          'candidates=${jsonEncode(gathered['candidates'])}',
        );
        expect(
          direct,
          isEmpty,
          reason: 'WebRTC sent STUN around the $scheme proxy: $direct',
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        if (processWide) {
          await ProxyController.instance().clearProxyOverride();
        }
        await webViewEnvironment?.dispose();
      }
    }, skip: shouldSkip);
  }
}
