// SPDX-License-Identifier: MIT
import Foundation
import NetworkExtension

final class PacketTunnelProvider:NEPacketTunnelProvider {
    private let lifecycle = DispatchQueue(label:"Vyrax.tunnel.lifecycle")
    private let network:OperationQueue = {let q=OperationQueue();q.maxConcurrentOperationCount=3;q.qualityOfService = .utility;return q}()
    private let pump = PacketPump()
    private var session:[String:Any] = [:]
    private var started = false
    private var generation=0
    override func startTunnel(options:[String:NSObject]?, completionHandler:@escaping(Error?)->Void) {
        lifecycle.async { [self] in
            generation+=1;let token=generation
            do {
                session = try SharedStore.load(name:"session")
                guard let config = session["config"] as? [String:Any] else {throw VyraxError.code("err.config")}
                _ = try NativeCore.invoke("start",config)
                let settings = session["settings"] as? [String:Any] ?? [:]
                let net = NEPacketTunnelNetworkSettings(tunnelRemoteAddress:"127.0.0.1")
                net.mtu = NSNumber(value:settings["mtu"] as? Int ?? 1280)
                let ipv4 = NEIPv4Settings(addresses:["198.18.0.1"],subnetMasks:["255.255.255.252"])
                ipv4.includedRoutes = [NEIPv4Route.default()]
                let ipv6 = NEIPv6Settings(addresses:["fd00:7679:7261::1"],networkPrefixLengths:[126])
                ipv6.includedRoutes = [NEIPv6Route.default()]
                net.ipv4Settings = ipv4;net.ipv6Settings = ipv6
                let dns = NEDNSSettings(servers:["1.1.1.1","8.8.8.8"]);dns.matchDomains = [""];net.dnsSettings = dns
                setTunnelNetworkSettings(net) { [self] error in
                    lifecycle.async { [self] in
                        do {
                            guard token==generation else{throw VyraxError.code("err.notConnected")}
                            if let error{throw error}
                            pump.failure = { [weak self] in self?.cancelTunnelWithError(VyraxError.code("err.core")) }
                            try pump.start(flow:packetFlow,mtu:settings["mtu"] as? Int ?? 1280)
                            started = true;session["since"] = ISO8601DateFormatter().string(from:Date())
                            try SharedStore.save(session,name:"session")
                            completionHandler(nil)
                        } catch {
                            if token==generation{if started{pump.stop();started=false};_ = try? NativeCore.invoke("stop")}
                            completionHandler(error)
                        }
                    }
                }
            } catch { _ = try? NativeCore.invoke("stop");completionHandler(error) }
        }
    }
    override func stopTunnel(with reason:NEProviderStopReason,completionHandler:@escaping()->Void) {
        lifecycle.async { [self] in
            generation+=1
            if started{pump.stop();started=false}
            _ = try? NativeCore.invoke("stop")
            completionHandler()
        }
    }
    override func handleAppMessage(_ messageData:Data,completionHandler:((Data?)->Void)?) {
        guard messageData.count<=8*1024*1024,let request = try? JSONSerialization.jsonObject(with:messageData) as? [String:Any],let action = request["action"] as? String else{completionHandler?(nil);return}
        let args = request["args"] as? [String:Any] ?? [:]
        let finish:(Any?,Error?)->Void = { value,error in
            let obj:[String:Any] = error.map{["error":code($0)]} ?? ["result":value ?? NSNull()]
            completionHandler?(try? JSONSerialization.data(withJSONObject:obj))
        }
        if action=="select" {
            lifecycle.async { [self] in
                do {
                    guard let config = args["config"] as? [String:Any] else{throw VyraxError.code("err.config")}
                    _ = try NativeCore.invoke("select",config)
                    for key in ["config","profileId","selectionMode","activeSourceId"]{session[key]=args[key]}
                    try SharedStore.save(session,name:"session");finish(snapshot(),nil)
                }catch{finish(nil,error)}
            }
        } else if action=="status" {
            lifecycle.async { [self] in finish(snapshot(),nil) }
        } else {
            network.addOperation {
                do {
                    switch action {
                    case "delay","ping":finish(try NativeCore.invoke("delay",args["outbound"] ?? [:]),nil)
                    case "subscription":finish(try NativeCore.invoke("http",args),nil)
                    case "checkUpdates":finish(try NativeCore.invoke("http",["url":"https://api.github.com/repos/AmyraxVPN-Main/Vyrax/releases/latest","update":true]),nil)
                    default:throw VyraxError.code("err.action")
                    }
                }catch{finish(nil,error)}
            }
        }
    }
    private func snapshot()->[String:Any] {
        var value = pump.stats();value["status"] = started ? "connected":"connecting";value["elevated"]=true
        for key in ["profileId","selectionMode","since","settings"]{value[key]=session[key]}
        return value
    }
}
