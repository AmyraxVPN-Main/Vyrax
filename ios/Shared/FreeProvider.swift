// SPDX-License-Identifier: MIT
// Guardian protocol adapted from FoxyVPN, Copyright (c) 2026 Vauth (MIT).
import Foundation
import CryptoKit
import Darwin

// A process-local serial provider. While the tunnel is active the app forwards
// account actions to that process, which also owns pass renewal.
final class FreeProvider {
    private let lock=NSRecursiveLock()
    private var accounts=[[String:Any]](),session=[String:Any]()
    private var pass="",passEmail="",expiry:Double=0
    private let transport:([String:Any]) throws -> [String:Any]
    private let load:() throws -> [String:Any]
    private let store:([String:Any]) throws -> Void
    init(transport:@escaping([String:Any]) throws -> [String:Any] = {
        guard let result=try NativeCore.invoke("freeRequest",$0) as? [String:Any] else{throw VyraxError.code("err.freeService")};return result
    },load:@escaping() throws -> [String:Any] = {try SharedStore.load(name:"firefox")},store:@escaping([String:Any]) throws -> Void = {try SharedStore.save($0,name:"firefox")}) {
        self.transport=transport;self.load=load;self.store=store
    }
    private func read() throws {
        do {
            let saved=try load();accounts=saved["accounts"] as? [[String:Any]] ?? []
            session=accounts.first{($0["email"] as? String)==(saved["activeEmail"] as? String)} ?? accounts.first ?? [:]
            if passEmail != session["email"] as? String {pass="";expiry=0}
        }catch{throw VyraxError.code("err.freeStorage")}
    }
    private func persist() throws {
        if let email=session["email"] as? String {accounts.removeAll{($0["email"] as? String)==email};accounts.append(session)}
        do {try store(["accounts":accounts,"activeEmail":session["email"] as? String ?? ""])}catch{throw VyraxError.code("err.freeStorage")}
    }
    private func vaultLock() throws -> Int32 {
        let file=try SharedStore.folder().appendingPathComponent("firefox.lock")
        let descriptor=open(file.path,O_CREAT|O_RDWR,S_IRUSR|S_IWUSR)
        guard descriptor>=0 else{throw VyraxError.code("err.freeStorage")}
        guard flock(descriptor,LOCK_EX)==0 else{close(descriptor);throw VyraxError.code("err.freeStorage")}
        return descriptor
    }
    private func summary()->[String:Any] {
        var result:[String:Any]=["signedIn":session["refreshToken"] as? String != nil,"email":session["email"] as? String ?? "","activeEmail":session["email"] as? String ?? "","activated":session["activated"] as? Bool ?? false]
        result["quota"]=session["quota"]
        result["accounts"]=accounts.map{account -> [String:Any] in
            var safe:[String:Any]=["email":account["email"] as? String ?? ""]
            for key in ["activated","quota"]{safe[key]=account[key]};return safe
        };return result
    }
    static func validToken(_ value:Any?)->Bool {
        guard let token=value as? String,!token.isEmpty,token.utf8.count<=16384 else{return false}
        return !token.unicodeScalars.contains{CharacterSet.whitespacesAndNewlines.contains($0)||CharacterSet.controlCharacters.contains($0)}
    }
    static func data(_ response:[String:Any]) throws -> [String:Any] {
        let status=response["status"] as? Int ?? 0
        let object=(response["body"] as? String).flatMap{$0.data(using:.utf8)}.flatMap{try? JSONSerialization.jsonObject(with:$0)} as? [String:Any]
        if (200..<300).contains(status){guard let object else{throw VyraxError.code("err.freeService")};return object}
        if status==406{throw VyraxError.code("err.freeChallenge")}
        if status==429{throw VyraxError.code("err.freeQuota")}
        if status==403{throw VyraxError.code("err.freeEligibility")}
        if status==401{throw VyraxError.code("err.freeAuth")}
        throw VyraxError.code("err.freeService")
    }
    func request(_ args:[String:Any]) throws -> [String:Any] {
        guard let endpoint=args["endpoint"] as? String,["login","verify","oauth","servers"].contains(endpoint) else{throw VyraxError.code("err.action")}
        return try transport(args)
    }
    private func access() throws -> String {
        guard Self.validToken(session["refreshToken"]) else{throw VyraxError.code("err.freeAuth")}
        if let token=session["accessToken"] as? String,Self.validToken(token),(session["expiresAt"] as? Double ?? 0)>Date().timeIntervalSince1970+60{return token}
        let body:[String:Any]=["client_id":"5882386c6d801776","grant_type":"refresh_token","refresh_token":session["refreshToken"]!,"scope":"profile https://identity.mozilla.com/apps/vpn"]
        let bytes=try JSONSerialization.data(withJSONObject:body)
        let response=try transport(["endpoint":"oauth","body":String(decoding:bytes,as:UTF8.self)])
        let data=try Self.data(response)
        guard Self.validToken(data["access_token"]) else{throw VyraxError.code("err.freeAuth")}
        session["accessToken"]=data["access_token"]
        if Self.validToken(data["refresh_token"]){session["refreshToken"]=data["refresh_token"]}
        session["expiresAt"]=Date().timeIntervalSince1970+(data["expires_in"] as? Double ?? 86400)
        try persist();return session["accessToken"] as! String
    }
    private func authorized(_ endpoint:String) throws -> [String:Any] {
        var response=try transport(["endpoint":endpoint,"authorization":"Bearer "+access()])
        if [401,403].contains(response["status"] as? Int ?? 0){session["expiresAt"]=0;response=try transport(["endpoint":endpoint,"authorization":"Bearer "+access()])}
        return response
    }
    private func quota(_ response:[String:Any],_ data:[String:Any]=[:]) {
        let headers=response["headers"] as? [String:String] ?? [:],previous=session["quota"] as? [String:Any] ?? [:]
        func number(_ key:String)->Any {guard let text=headers[key],!text.isEmpty,text.allSatisfy({$0.isASCII && $0.isNumber}),let value=Int64(text),value>=0 else{return NSNull()};return value}
        let limit=number("x-quota-limit")
        session["quota"]=["limit":limit is NSNull ? data["maxBytes"] ?? previous["limit"] ?? NSNull() : limit,"remaining":number("x-quota-remaining"),"reset":number("x-quota-reset")]
        if let active=data["subscribed"] as? Bool{session["activated"]=active}
    }
    private func cache(_ response:[String:Any]) throws {
        let data=try Self.data(response)
        guard Self.validToken(data["token"]),let token=data["token"] as? String else{throw VyraxError.code("err.freeAuth")}
        pass=token;passEmail=session["email"] as? String ?? ""
        expiry=data["expires_at"] as? Double ?? Date().timeIntervalSince1970+300
        if data["expires_at"] == nil,let part=token.split(separator:".").dropFirst().first {
            var text=String(part).replacingOccurrences(of:"-",with:"+").replacingOccurrences(of:"_",with:"/")
            text += String(repeating:"=",count:(4-text.count%4)%4)
            if let bytes=Data(base64Encoded:text),let payload=try? JSONSerialization.jsonObject(with:bytes) as? [String:Any],let exp=payload["exp"] as? Double{expiry=exp}
        }
        quota(response);session["activated"]=true
    }
    func perform(_ action:String,_ args:[String:Any]) throws -> [String:Any] {
        lock.lock();defer{lock.unlock()}
        let descriptor=try vaultLock();defer{flock(descriptor,LOCK_UN);close(descriptor)};try read()
        switch action {
        case "freeAccount":
            let operation=args["operation"] as? String ?? "status"
            if operation=="local"{return summary()}
            guard ["status","activate"].contains(operation) else{throw VyraxError.code("err.action")}
            var response=try authorized(operation)
            let code=response["status"] as? Int ?? 0
            let acknowledged=operation=="activate" && (200..<300).contains(code) && (response["body"] as? String ?? "").trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
            var data:[String:Any]=[:]
            if !acknowledged{data=try Self.data(response)}
            quota(response,data)
            if operation=="activate",data["subscribed"] as? Bool != true{response=try authorized("status");data=try Self.data(response);quota(response,data)}
            try persist()
            if operation=="activate",session["activated"] as? Bool != true{throw VyraxError.code("err.freeNotActivated")}
            if session["activated"] as? Bool == true {
                let response=try authorized("token")
                if response["status"] as? Int == 429{quota(response);var q=session["quota"] as? [String:Any] ?? [:];q["remaining"]=0;session["quota"]=q}
                else{try cache(response)}
            }
        case "freeSave":
            guard Self.validToken(args["accessToken"]),Self.validToken(args["refreshToken"]) else{throw VyraxError.code("err.freeAuth")}
            guard let email=args["email"] as? String,!email.isEmpty,email.utf8.count<=254,accounts.contains(where:{$0["email"] as? String==email})||accounts.count<10 else{throw VyraxError.code("err.freeAccounts")}
            session=["email":email,"accessToken":args["accessToken"]!,"refreshToken":args["refreshToken"]!,"expiresAt":args["expiresAt"] as? Double ?? 0];pass="";expiry=0
        case "freeSwitch":
            guard let next=accounts.first(where:{$0["email"] as? String==args["email"] as? String}) else{throw VyraxError.code("err.freeAuth")}
            session=next;pass="";expiry=0
        case "freeRemove","freeLogout":
            let email=action=="freeLogout" ? session["email"] as? String : args["email"] as? String
            guard let email else{throw VyraxError.code("err.freeAuth")}
            accounts.removeAll{$0["email"] as? String==email}
            if session["email"] as? String==email{session=accounts.first ?? [:];pass="";expiry=0}
        default:throw VyraxError.code("err.action")
        }
        try persist();return summary()
    }
    static func validServer(_ host:String,_ port:Int)->Bool {
        (1...65535).contains(port)&&host.count<=253&&host.range(of:"^[a-z0-9]+(?:[.-][a-z0-9]+)*\\.fastly-masque\\.net$",options:[.regularExpression,.caseInsensitive]) != nil
    }
    private func resolveOutbound(_ outbound:[String:Any]) throws -> [String:Any] {
        guard outbound["protocol"] as? String=="http",var settings=outbound["settings"] as? [String:Any],let headers=settings["headers"] as? [String:String],headers["Proxy-Authorization"]=="Bearer vyrax-native-pass" else{return outbound}
        let servers=settings["servers"] as? [[String:Any]] ?? []
        guard servers.count==1,let host=servers[0]["address"] as? String,let port=servers[0]["port"] as? Int,Self.validServer(host,port),let stream=outbound["streamSettings"] as? [String:Any],stream["security"] as? String=="tls",let tls=stream["tlsSettings"] as? [String:Any],tls["serverName"] as? String==host,tls["allowInsecure"] as? Bool==false,tls["alpn"] as? [String]==["h2"] else{throw VyraxError.code("err.freeServer")}
        if pass.isEmpty||expiry<=Date().timeIntervalSince1970+60{try cache(authorized("token"));try persist()}
        settings["headers"]=["Proxy-Authorization":"Bearer "+pass]
        var result=outbound;result["settings"]=settings
        if let tag=outbound["tag"] as? String {result["tag"]="node-"+SHA256.hash(data:Data((tag+pass).utf8)).prefix(12).map{String(format:"%02x",$0)}.joined()}
        return result
    }
    func prepare(_ config:[String:Any],single:Bool=false) throws -> [String:Any] {
        func needsPass(_ outbound:[String:Any])->Bool {((outbound["settings"] as? [String:Any])?["headers"] as? [String:String])?["Proxy-Authorization"]=="Bearer vyrax-native-pass"}
        if single && !needsPass(config){return config}
        if !single && !(config["outbounds"] as? [[String:Any]] ?? []).contains(where:needsPass){return config}
        lock.lock();defer{lock.unlock()}
        let descriptor=try vaultLock();defer{flock(descriptor,LOCK_UN);close(descriptor)};try read()
        if single{return try resolveOutbound(config)}
        guard let outbounds=config["outbounds"] as? [[String:Any]] else{throw VyraxError.code("err.config")}
        var tags=[String:String](),prepared=[[String:Any]]()
        for outbound in outbounds {let result=try resolveOutbound(outbound);if let old=outbound["tag"] as? String,let new=result["tag"] as? String,old != new{tags[old]=new};prepared.append(result)}
        func rewrite(_ value:Any)->Any {
            if let text=value as? String{return tags[text] ?? text}
            if let list=value as? [Any]{return list.map{rewrite($0)}}
            if let object=value as? [String:Any]{return object.mapValues{rewrite($0)}}
            return value
        }
        var result=rewrite(config) as! [String:Any];result["outbounds"]=prepared;return result
    }
}
