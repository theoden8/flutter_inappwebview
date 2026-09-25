// Which proxy configurations make WebKit rebuild a live store's NSURLSessions
// (NetworkSessionCocoa::setProxyConfigData takes that path when
// nw_proxy_config_stack_requires_http_protocols holds for any of them)?
import Foundation
import Network
import WebKit

@available(macOS 14.0, *)
func probe() {
    typealias RequiresFn = @convention(c) (UnsafeRawPointer) -> Bool
    let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "nw_proxy_config_stack_requires_http_protocols")
    print("PROBE nw_proxy_config_stack_requires_http_protocols exported: \(sym != nil)")
    let requires = sym.map { unsafeBitCast($0, to: RequiresFn.self) }

    func check(_ name: String, _ config: AnyObject) {
        let p = Unmanaged.passUnretained(config).toOpaque()
        print("PROBE \(name): requires_http_protocols=\(requires.map { $0(p) } as Any) \(config)")
    }

    let proxy = NWEndpoint.hostPort(host: "127.0.0.1", port: 8083)
    let relay = NWEndpoint.hostPort(host: "relay.invalid", port: 443)

    var configs: [(String, ProxyConfiguration)] = [
        ("http_connect", ProxyConfiguration(httpCONNECTProxy: proxy, tlsOptions: nil)),
        ("https_connect", ProxyConfiguration(httpCONNECTProxy: proxy, tlsOptions: .init())),
        ("socksv5", ProxyConfiguration(socksv5Proxy: proxy)),
        ("relay_h3", ProxyConfiguration(relayHops: [ProxyConfiguration.RelayHop(http3RelayEndpoint: relay)])),
        ("relay_h2", ProxyConfiguration(relayHops: [ProxyConfiguration.RelayHop(http2RelayEndpoint: relay)])),
    ]
    var matched = ProxyConfiguration(relayHops: [ProxyConfiguration.RelayHop(http2RelayEndpoint: relay)])
    matched.matchDomains = ["session.invalid"]
    configs.append(("relay_h2_matchDomains", matched))
    let keyConfig = Data([0x01, 0x00, 0x20] + [UInt8](repeating: 7, count: 32) + [0x00, 0x04, 0x00, 0x01, 0x00, 0x01])
    configs.append(("ohttp_matchDomains", ProxyConfiguration(
        obliviousHTTPRelay: ProxyConfiguration.RelayHop(http3RelayEndpoint: relay),
        relayResourcePath: "/gateway", gatewayKeyConfig: keyConfig, matchDomains: ["session.invalid"])))
    configs.append(("ohttp_emptyKey", ProxyConfiguration(
        obliviousHTTPRelay: ProxyConfiguration.RelayHop(http2RelayEndpoint: relay),
        relayResourcePath: "/", gatewayKeyConfig: Data(), matchDomains: ["session.invalid"])))

    for (name, config) in configs {
        let store = WKWebsiteDataStore.nonPersistent()
        store.proxyConfigurations = [config]
        guard let objects = store.value(forKey: "proxyConfigurations") as? [AnyObject], let nw = objects.first else {
            print("PROBE \(name): no nw_proxy_config came back")
            continue
        }
        check(name, nw)
    }

    // A path that exists only on macOS, not on the command line tools' SDK?
    print("PROBE done with requires checks")

    // Is debugDescription enough to tell two routes apart?
    var withCredential = ProxyConfiguration(httpCONNECTProxy: proxy, tlsOptions: nil)
    withCredential.applyCredential(username: "user", password: "secret")
    var scoped = ProxyConfiguration(socksv5Proxy: proxy)
    scoped.matchDomains = ["example.com"]
    scoped.excludedDomains = ["example.org"]
    scoped.allowFailover = true
    for (name, config) in [
        ("http_connect", ProxyConfiguration(httpCONNECTProxy: proxy, tlsOptions: nil)),
        ("http_connect_again", ProxyConfiguration(httpCONNECTProxy: proxy, tlsOptions: nil)),
        ("http_connect_8084", ProxyConfiguration(httpCONNECTProxy: .hostPort(host: "127.0.0.1", port: 8084), tlsOptions: nil)),
        ("http_connect_credential", withCredential),
        ("socks_scoped", scoped),
    ] {
        print("DESC \(name): \(String(reflecting: config))")
        let store = WKWebsiteDataStore.nonPersistent()
        store.proxyConfigurations = [config]
        print("DESC \(name) read back: \(String(reflecting: store.proxyConfigurations))")
    }
}

if #available(macOS 14.0, *) {
    probe()
} else {
    print("PROBE needs macOS 14")
}
