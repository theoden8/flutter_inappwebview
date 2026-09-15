//
//  ProxyManager.swift
//  flutter_inappwebview
//

import Foundation
import WebKit
import Flutter

@available(iOS 17.0, *)
public class ProxyManager: ChannelDelegate {
    static let METHOD_CHANNEL_NAME = "com.pichillilorenzo/flutter_inappwebview_proxycontroller"

    private var plugin: InAppWebViewFlutterPlugin?

    init(plugin: InAppWebViewFlutterPlugin) {
        super.init(channel: FlutterMethodChannel(name: ProxyManager.METHOD_CHANNEL_NAME, binaryMessenger: plugin.registrar.messenger()))
        self.plugin = plugin
    }

    public override func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any]
        switch call.method {
        case "setProxyOverride":
            if let args = arguments?["settings"] as? [String:Any?],
               let settings = ProxySettings.fromMap(map: args) {
                setProxyOverride(settings)
                result(true)
            } else {
                result(false)
            }
            break
        case "clearProxyOverride":
            clearProxyOverride()
            result(true)
            break
        default:
            result(FlutterMethodNotImplemented)
            break
        }
    }
    
    // The configurations the Dart side last asked for, or nil when no
    // override is active. A container's WKWebsiteDataStore is created
    // lazily -- the first time a WebView joins that container, which can be
    // long after setProxyOverride ran -- and a fresh store carries no proxy,
    // so the intent has to outlive the list of stores it was applied to.
    static var activeProxyConfigurations: [ProxyConfiguration]? = nil

    // Stores a WebView pinned with a proxy of its own. The process-wide
    // override is the fallback for sites that named no proxy, so it must
    // not reach these: writing it over one swaps the site's proxy for the
    // global one, and clearing it drops the site to the device IP.
    // Assigning an empty array is the only call in this stack that reaches
    // WebKit's clearProxyConfigData, which is the one thing that takes a
    // proxy off a live session.
    //
    // Weak: a non-persistent store is transient, and a set of raw
    // identifiers would pin a freed address that a later store can reuse.
    private static let perSiteProxyStores = NSHashTable<WKWebsiteDataStore>.weakObjects()
    private static let perSiteProxyLock = NSLock()

    // Called by InAppWebView once it has assigned a per-WebView proxy.
    static func pinPerSiteProxy(to store: WKWebsiteDataStore) {
        perSiteProxyLock.lock()
        defer { perSiteProxyLock.unlock() }
        perSiteProxyStores.add(store)
    }

    // Called by InAppWebView when a WebView binds a store and names no
    // proxy: the store goes back to following the process-wide override,
    // which is what that site's effective proxy resolves to.
    static func releasePerSiteProxy(from store: WKWebsiteDataStore) {
        perSiteProxyLock.lock()
        let wasPinned = perSiteProxyStores.contains(store)
        perSiteProxyStores.remove(store)
        perSiteProxyLock.unlock()
        guard wasPinned else { return }
        store.proxyConfigurations = activeProxyConfigurations ?? []
    }

    static func carriesPerSiteProxy(_ store: WKWebsiteDataStore) -> Bool {
        perSiteProxyLock.lock()
        defer { perSiteProxyLock.unlock() }
        return perSiteProxyStores.contains(store)
    }

    // Replays the active override, if any, onto a store created after the
    // fan-out below ran. Called by ContainerManager.getOrCreateDataStore.
    static func applyActiveProxyOverride(to store: WKWebsiteDataStore) {
        guard let proxyConfigurations = activeProxyConfigurations else {
            return
        }
        if carriesPerSiteProxy(store) {
            return
        }
        store.proxyConfigurations = proxyConfigurations
    }

    public func setProxyOverride(_ settings: ProxySettings) {
        guard let proxyConfigurations = settings.toProxyConfigurations() else {
            debugPrint("ProxyManager - refusing a proxy override with an unusable rule; leaving the current proxy alone")
            return
        }
        // Remembered before anything is applied: a container joined later
        // replays it rather than coming up with no proxy at all.
        ProxyManager.activeProxyConfigurations = proxyConfigurations
        ProxyManager.fanOutToFollowingStores(proxyConfigurations)
    }

    public func clearProxyOverride() {
        ProxyManager.activeProxyConfigurations = nil
        ProxyManager.fanOutToFollowingStores([])
    }

    // Every store that follows the process-wide override, which is all of
    // them but the ones a WebView pinned. A container store is neither the
    // default nor the non-persistent one, so without this fan-out a
    // contained WebView keeps loading over the device IP while an override
    // is in force.
    static func fanOutToFollowingStores(_ proxyConfigurations: [ProxyConfiguration]) {
        let defaultStore = WKWebsiteDataStore.default()
        if !carriesPerSiteProxy(defaultStore) {
            defaultStore.proxyConfigurations = proxyConfigurations
        }
        WKWebsiteDataStore.nonPersistent().proxyConfigurations = proxyConfigurations
        for store in ContainerManager.allCachedDataStores()
        where !carriesPerSiteProxy(store) {
            store.proxyConfigurations = proxyConfigurations
        }
    }

    public override func dispose() {
        super.dispose()
        plugin = nil
    }

    deinit {
        debugPrint("ProxyManager - dealloc")
        dispose()
    }
}

@available(iOS 17.0, *)
public class ProxySettings {
    var proxyRules: [ProxyRule]

    init(
        proxyRules: [ProxyRule]
    ) {
        self.proxyRules = proxyRules
    }

    public static func fromMap(map: [String:Any?]?) -> ProxySettings? {
        guard let map = map else {
            return nil
        }
        return ProxySettings(
            proxyRules: (map["proxyRules"] as! [[String:Any?]]).map { ProxyRule.fromMap(map: $0)! }
        )
    }
    
    // nil when any rule failed to convert, rather than the rules that did.
    // A partial list applies a proxy the caller did not ask for, and an empty
    // one is worse than a no-op: WKWebsiteDataStore routes an empty array to
    // clearProxyConfigData, so one unparseable rule would turn "use this
    // proxy" into "stop using any proxy" on a live session. An empty
    // proxyRules still yields an empty array, which is the caller genuinely
    // asking for no proxy.
    public func toProxyConfigurations() -> [ProxyConfiguration]? {
        var proxyConfigurations: [ProxyConfiguration] = []
        for rule in proxyRules {
            guard let proxyConfiguration = rule.toProxyConfiguration() else {
                return nil
            }
            proxyConfigurations.append(proxyConfiguration)
        }
        return proxyConfigurations
    }
}

@available(iOS 17.0, *)
public class ProxyRule {
    var url: String
    var allowFailover: Bool?
    var excludedDomains: [String]?
    var matchDomains: [String]?
    var username: String?
    var password: String?
    var relayHop1: ProxyRelayHop?
    var relayHop2: ProxyRelayHop?

    init(
        url: String,
        allowFailover: Bool?,
        excludedDomains: [String]?,
        matchDomains: [String]?,
        username: String?,
        password: String?,
        relayHop1: ProxyRelayHop?,
        relayHop2: ProxyRelayHop?
    ) {
        self.url = url
        self.allowFailover = allowFailover
        self.excludedDomains = excludedDomains
        self.matchDomains = matchDomains
        self.username = username
        self.password = password
        self.relayHop1 = relayHop1
        self.relayHop2 = relayHop2
    }

    public static func fromMap(map: [String:Any?]?) -> ProxyRule? {
        guard let map = map else {
            return nil
        }
        return ProxyRule(
            url: map["url"] as! String,
            allowFailover: map["allowFailover"] as? Bool,
            excludedDomains: map["excludedDomains"] as? [String],
            matchDomains: map["matchDomains"] as? [String],
            username: map["username"] as? String,
            password: map["password"] as? String,
            relayHop1: ProxyRelayHop.fromMap(map: map["relayHop1"] as? [String:Any?]),
            relayHop2: ProxyRelayHop.fromMap(map: map["relayHop2"] as? [String:Any?])
        )
    }
    
    public func toProxyConfiguration() -> ProxyConfiguration? {
        guard let endpointUrl = URL(string: url.contains("://") ? url : "http://" + url),
              let port: NWEndpoint.Port = .init(rawValue: UInt16(endpointUrl.port ?? 80)),
              let host = endpointUrl.host else {
            return nil
        }
        
        var endpointHost = NWEndpoint.Host(host)
        if let ipv4 = IPv4Address(host) {
            endpointHost = .ipv4(ipv4)
        } else if let ipv6 = IPv6Address(host) {
            endpointHost = .ipv6(ipv6)
        }
        let endpoint = NWEndpoint.hostPort(host: endpointHost, port: port)
        var proxyConfiguration: ProxyConfiguration
        let proxyRelayHops: [ProxyRelayHop] = [relayHop1, relayHop2].filter({ $0 != nil }).map({ $0! })
        if !proxyRelayHops.isEmpty {
            proxyConfiguration = ProxyConfiguration(relayHops: proxyRelayHops.compactMap({ $0.toRelayHop() }))
        } else {
            proxyConfiguration = endpointUrl.scheme?.lowercased() == "socks5" ?
            ProxyConfiguration(socksv5Proxy: endpoint) :
            ProxyConfiguration(httpCONNECTProxy: endpoint, tlsOptions: endpointUrl.scheme?.lowercased() == "https" ? .init() : nil)
        }

        if let allowFailover = allowFailover {
            proxyConfiguration.allowFailover = allowFailover
        }
        if let excludedDomains = excludedDomains {
            proxyConfiguration.excludedDomains = excludedDomains
        }
        if let matchDomains = matchDomains {
            proxyConfiguration.matchDomains = matchDomains
        }
        if let username = username, let password = password {
            proxyConfiguration.applyCredential(username: username, password: password)
        }
        return proxyConfiguration
    }
}

@available(iOS 17.0, *)
public class ProxyRelayHop {
    var http3RelayEndpoint: String?
    var http2RelayEndpoint: String?
    var additionalHTTPHeaders: [String:String]?
    
    init(
        http3RelayEndpoint: String,
        http2RelayEndpoint: String?,
        additionalHTTPHeaders: [String:String]?
    ) {
        self.http3RelayEndpoint = http3RelayEndpoint
        self.http2RelayEndpoint = http2RelayEndpoint
        self.additionalHTTPHeaders = additionalHTTPHeaders
    }
    
    init(
        http2RelayEndpoint: String,
        additionalHTTPHeaders: [String:String]?
    ) {
        self.http2RelayEndpoint = http2RelayEndpoint
        self.additionalHTTPHeaders = additionalHTTPHeaders
    }
    
    public static func fromMap(map: [String:Any?]?) -> ProxyRelayHop? {
        guard let map = map else {
            return nil
        }
        let http3RelayEndpoint = map["http3RelayEndpoint"] as? String
        let http2RelayEndpoint = map["http2RelayEndpoint"] as? String
        let additionalHTTPHeaders = map["additionalHTTPHeaders"] as? [String:String]
        if http3RelayEndpoint == nil, http2RelayEndpoint == nil {
            return nil
        }
        if http3RelayEndpoint != nil {
            return ProxyRelayHop(
                http3RelayEndpoint: http3RelayEndpoint!,
                http2RelayEndpoint: http2RelayEndpoint,
                additionalHTTPHeaders: additionalHTTPHeaders
            )
        }
        return ProxyRelayHop(
            http2RelayEndpoint: http2RelayEndpoint!,
            additionalHTTPHeaders: additionalHTTPHeaders
        )
    }
    
    public func toRelayHop() -> ProxyConfiguration.RelayHop? {
        if let http3RelayEndpoint = http3RelayEndpoint,
           let url = URL(string: http3RelayEndpoint) {
            var http2Endpoint: NWEndpoint? = nil
            if let http2RelayEndpoint = http2RelayEndpoint,
               let url2 = URL(string: http2RelayEndpoint) {
                http2Endpoint = NWEndpoint.url(url2)
            }
            return ProxyConfiguration.RelayHop(http3RelayEndpoint: NWEndpoint.url(url),
                                               http2RelayEndpoint: http2Endpoint,
                                               additionalHTTPHeaderFields: additionalHTTPHeaders ?? [:])
        }
        if let http2RelayEndpoint = http2RelayEndpoint,
           let url = URL(string: http2RelayEndpoint) {
            return ProxyConfiguration.RelayHop(http2RelayEndpoint: NWEndpoint.url(url),
                                               additionalHTTPHeaderFields: additionalHTTPHeaders ?? [:])
        }
        return nil
    }
}
