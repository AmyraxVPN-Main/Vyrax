// SPDX-License-Identifier: MIT
import Foundation
import NetworkExtension

@MainActor final class VPNController {
    private var manager:NETunnelProviderManager?
    private var generation=0
    private var connecting=false
    var changed:(()->Void)?
    private var observer:NSObjectProtocol?
    init(){observer=NotificationCenter.default.addObserver(forName:.NEVPNStatusDidChange,object:nil,queue:.main){[weak self] _ in self?.changed?()}}
    deinit{if let observer{NotificationCenter.default.removeObserver(observer)}}
    func prepare() async throws {
        if manager != nil{return}
        let all = try await NETunnelProviderManager.loadAllFromPreferences()
        manager = all.first{($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier=="com.amyrax.vyrax.tunnel"} ?? NETunnelProviderManager()
    }
    var active:Bool {manager?.connection.status == .connected || manager?.connection.status == .reasserting}
    var status:String {
        switch manager?.connection.status {
        case .connected,.reasserting:return "connected"
        case .connecting:return "connecting"
        default:return "disconnected"
        }
    }
    func snapshot() async throws -> [String:Any] {
        #if !targetEnvironment(simulator)
        try await prepare()
        #endif
        if active {return try await message("status",[:]) as? [String:Any] ?? ["status":status,"elevated":true]}
        return ["status":status,"elevated":true]
    }
    func connect(_ args:[String:Any]) async throws -> [String:Any] {
        #if targetEnvironment(simulator)
        throw VyraxError.code("err.vpnPermission") // The simulator cannot establish an iPhone VPN.
        #else
        guard !connecting else{throw VyraxError.code("err.busy")}
        connecting=true;defer{connecting=false}
        generation+=1;let token=generation
        try await prepare()
        guard let manager,let config=args["config"] as? [String:Any],!config.isEmpty else{throw VyraxError.code("err.config")}
        let settings=try SharedStore.settings(args["settings"] as? [String:Any] ?? [:])
        var session=args;session["settings"]=settings
        try await Task.detached{try SharedStore.save(session,name:"session")}.value
        let proto=NETunnelProviderProtocol();proto.providerBundleIdentifier="com.amyrax.vyrax.tunnel";proto.serverAddress="Vyrax"
        manager.protocolConfiguration=proto;manager.localizedDescription="Vyrax";manager.isEnabled=true
        if settings["autoReconnect"] as? Bool == true {
            let rule=NEOnDemandRuleConnect();rule.interfaceTypeMatch = .any
            manager.onDemandRules=[rule];manager.isOnDemandEnabled=true
        }else{manager.isOnDemandEnabled=false;manager.onDemandRules=[]}
        try await manager.saveToPreferences();try await manager.loadFromPreferences()
        guard token==generation else{throw VyraxError.code("err.notConnected")}
        try manager.connection.startVPNTunnel()
        for _ in 0..<150 {
            try await Task.sleep(nanoseconds:200_000_000)
            guard token==generation else{throw VyraxError.code("err.notConnected")}
            if active{return try await snapshot()}
            if manager.connection.status == .disconnected || manager.connection.status == .invalid {throw VyraxError.code("err.core")}
        }
        manager.connection.stopVPNTunnel();throw VyraxError.code("err.core")
        #endif
    }
    func disconnect() async throws -> [String:Any] {
        generation+=1
        if let manager {
            manager.isOnDemandEnabled=false
            try await manager.saveToPreferences()
            manager.connection.stopVPNTunnel()
        }
        return ["status":"disconnected","elevated":true]
    }
    func message(_ action:String,_ args:[String:Any]) async throws -> Any {
        guard active,let connection=manager?.connection as? NETunnelProviderSession else{throw VyraxError.code("err.notConnected")}
        let bytes=try JSONSerialization.data(withJSONObject:["action":action,"args":args])
        return try await withCheckedThrowingContinuation { continuation in
            let reply=TunnelReply(continuation)
            do {try connection.sendProviderMessage(bytes){data in
                DispatchQueue.main.async {
                    guard let data,let obj=try? JSONSerialization.jsonObject(with:data) as? [String:Any] else{reply.finish(.failure(VyraxError.code("err.core")));return}
                    if let error=obj["error"] as? String{reply.finish(.failure(VyraxError.code(error)))}else{reply.finish(.success(obj["result"] ?? NSNull()))}
                }
            }}catch{reply.finish(.failure(error))}
            DispatchQueue.main.asyncAfter(deadline:.now()+35){reply.finish(.failure(VyraxError.code("err.core")))}
        }
    }
}
@MainActor private final class TunnelReply {
    private var continuation:CheckedContinuation<Any,Error>?
    init(_ value:CheckedContinuation<Any,Error>){continuation=value}
    func finish(_ value:Result<Any,Error>){guard let continuation else{return};self.continuation=nil;continuation.resume(with:value)}
}
