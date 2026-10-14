// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import Foundation
import CryptoKit
import Security

// WebKit custom schemes do not consistently expose SubtleCrypto on iOS 16.
// Keep the existing protocol vectors while deriving on a background native task.
enum FreeCrypto {
    private static func hmac(_ key:Data,_ data:Data)->Data {Data(HMAC<SHA256>.authenticationCode(for:data,using:SymmetricKey(data:key)))}
    private static func hkdf(_ input:Data,_ info:String,_ length:Int)->Data {
        let key=HKDF<SHA256>.deriveKey(inputKeyMaterial:SymmetricKey(data:input),salt:Data(repeating:0,count:32),info:Data(("identity.mozilla.com/picl/v1/"+info).utf8),outputByteCount:length)
        return key.withUnsafeBytes{Data($0)}
    }
    private static func hex(_ data:Data)->String {data.map{String(format:"%02x",$0)}.joined()}
    static func perform(_ args:[String:Any]) throws -> String {
        switch args["operation"] as? String {
        case "authPassword":
            guard let email=args["email"] as? String,email.utf8.count<=1024,let password=args["password"] as? String,!password.isEmpty,password.count<=4096 else{throw VyraxError.code("err.freeCredentials")}
            let key=Data(password.utf8),salt=Data(("identity.mozilla.com/picl/v1/quickStretch:"+email).utf8)+Data([0,0,0,1])
            var block=hmac(key,salt),stretched=block
            for _ in 1..<1000{block=hmac(key,block);for index in 0..<32{stretched[index] ^= block[index]}}
            return hex(hkdf(stretched,"authPW",32))
        case "hawk":
            guard let token=args["sessionToken"] as? String,token.count%2==0,token.range(of:"^[a-fA-F0-9]{64,256}$",options:.regularExpression) != nil,
                  let endpoint=args["endpoint"] as? String,["verify","oauth"].contains(endpoint),let body=args["body"] as? String,body.utf8.count<=32768 else{throw VyraxError.code("err.action")}
            let chars=Array(token),input=Data(stride(from:0,to:chars.count,by:2).map{UInt8(String(chars[$0...$0+1]),radix:16)!})
            let material=hkdf(input,"sessionToken",64),ts=args["ts"] as? Int ?? Int(Date().timeIntervalSince1970)
            var random=Data(count:6)
            guard random.withUnsafeMutableBytes({SecRandomCopyBytes(kSecRandomDefault,6,$0.baseAddress!)})==errSecSuccess else{throw VyraxError.code("err.core")}
            let nonce=args["nonce"] as? String ?? random.base64EncodedString().replacingOccurrences(of:"+",with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"")
            guard nonce.range(of:"^[a-zA-Z0-9_-]{1,64}$",options:.regularExpression) != nil else{throw VyraxError.code("err.action")}
            let path=endpoint=="verify" ? "/v1/session/verify_code" : "/v1/oauth/token"
            let payload=Data(SHA256.hash(data:Data(("hawk.1.payload\napplication/json\n"+body+"\n").utf8))).base64EncodedString()
            let normalized="hawk.1.header\n\(ts)\n\(nonce)\nPOST\n\(path)\napi.accounts.firefox.com\n443\n\(payload)\n\n"
            let mac=hmac(Data(material.suffix(32)),Data(normalized.utf8)).base64EncodedString()
            return "Hawk id=\"\(hex(Data(material.prefix(32))))\", ts=\"\(ts)\", nonce=\"\(nonce)\", mac=\"\(mac)\", hash=\"\(payload)\""
        default:throw VyraxError.code("err.action")
        }
    }
}
