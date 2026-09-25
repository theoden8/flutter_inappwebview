part of 'main.dart';

// Does WebRTC go through the WebView's proxy? It does not on any platform
// (ci/webrtc-proxy, first run): STUN goes out directly over UDP, and no
// WebView asks a SOCKS5 proxy to relay it. These cases check what stops it.
//
// The page loads through proxy A, then gathers ICE candidates against the
// fixture's STUN server. The fixture logs every STUN binding request and
// whether it came through a SOCKS relay: one that did not went out directly,
// around the proxy.
//
// Mitigations:
// - script: a document-start user script, in every frame, that removes
//   RTCPeerConnection. The page also looks for a clean copy in an
//   about:blank iframe and a srcdoc iframe it creates itself.
// - policy: WebView2's --force-webrtc-ip-handling-policy=
//   disable_non_proxied_udp (Windows only).
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
  final mitigations = ['script', if (isWindows) 'policy'];

  const removeWebRTC = '''
(function() {
  ['RTCPeerConnection', 'webkitRTCPeerConnection'].forEach(function(name) {
    try { delete window[name]; } catch (e) {}
    try {
      Object.defineProperty(window, name, {
        value: undefined, writable: false, configurable: false
      });
    } catch (e) {}
  });
})();
''';

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
    for (final mitigation in mitigations) {
      skippableTestWidgets('WebRTC behind a $scheme proxy with $mitigation', (
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
              userDataFolder: '${dir.path}/webrtc-$scheme-$mitigation-$stamp',
              additionalBrowserArguments: [
                '--proxy-server=$proxyUrl',
                if (mitigation == 'policy')
                  '--force-webrtc-ip-handling-policy=disable_non_proxied_udp',
              ].join(' '),
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
                  containerId: perWebView
                      ? 'webrtc-$scheme-$mitigation-$stamp'
                      : null,
                  proxySettings: perWebView ? proxy : null,
                ),
                initialUserScripts: UnmodifiableListView([
                  if (mitigation == 'script')
                    UserScript(
                      source: removeWebRTC,
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                      forMainFrameOnly: false,
                    ),
                ]),
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

          // Looks for RTCPeerConnection in the page and in two iframes the
          // page makes itself, and gathers through the first one found.
          await controller.evaluateJavascript(
            source:
                '''
(function() {
  window.__webrtc = {done: false};
  function constructorIn(w) {
    try { return w && (w.RTCPeerConnection || w.webkitRTCPeerConnection); }
    catch (e) { return null; }
  }
  var blank = document.createElement('iframe');
  document.body.appendChild(blank);
  var srcdoc = document.createElement('iframe');
  srcdoc.srcdoc = '<p>frame</p>';
  var started = false;
  var gather = function() {
    if (started) return;
    started = true;
    var found = {
      page: !!constructorIn(window),
      blankIframe: !!constructorIn(blank.contentWindow),
      srcdocIframe: !!constructorIn(srcdoc.contentWindow)
    };
    var PC = constructorIn(window) || constructorIn(blank.contentWindow)
      || constructorIn(srcdoc.contentWindow);
    if (!PC) {
      window.__webrtc = {done: true, available: false, found: found, candidates: []};
      return;
    }
    var candidates = [];
    var pc = new PC({
      iceServers: [{urls: 'stun:${environment["NODE_SERVER_IP"]}:3478'}]
    });
    var finish = function(error) {
      if (window.__webrtc.done) return;
      window.__webrtc = {
        done: true, available: true, found: found, candidates: candidates,
        error: error || null
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
  };
  srcdoc.onload = gather;
  document.body.appendChild(srcdoc);
  setTimeout(gather, 3000);
})();
''',
          );

          Map<String, dynamic> gathered = {};
          for (var i = 0; i < 40; i++) {
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
            'WEBRTC-PROXY ${defaultTargetPlatform.name} $scheme $mitigation: '
            'available=${gathered['available']} '
            'found=${jsonEncode(gathered['found'])} '
            'error=${gathered['error']} '
            'stun direct=${direct.length} relayed=${relayed.length} '
            'socks=${jsonEncode(log['socks'])} '
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
}
