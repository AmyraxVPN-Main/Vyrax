import XCTest
@testable import Vyrax

final class FreeProviderTests:XCTestCase {
    func testNativeFirefoxCryptoVectors() throws {
        XCTAssertEqual(try FreeCrypto.perform(["operation":"authPassword","email":"test@example.com","password":"päss-آزمایش"]),"852a0f233a2a338e0a26a3a61480e8b9ddb6f0ebde2f0c8155767bd7979aca03")
        let signed=try FreeCrypto.perform(["operation":"hawk","sessionToken":String(repeating:"00",count:32),"endpoint":"verify","body":"{\"code\":\"123456\"}","ts":1700000000,"nonce":"nonce123"])
        XCTAssertEqual(signed,"Hawk id=\"cb339b3ae38e8ca7ce73414765fcf866ec6fd00faa48932575b407d1836c6e01\", ts=\"1700000000\", nonce=\"nonce123\", mac=\"uGwkJbaK0OVoYPoUHhWHAWqXaLGWHx/G4pgC7CYVYEQ=\", hash=\"Ep9IOeekIfor0O8wOtlEW2ta9aXArsz34Sju2Ketz/I=\"")
    }
    func testAccountsQuotaAndNativePassStaySeparateFromProfiles() throws {
        var vault=[String:Any](),requests=[String]()
        let provider=FreeProvider(transport:{args in
            let endpoint=args["endpoint"] as? String ?? "";requests.append(endpoint)
            let data:[String:Any]=endpoint=="token" ? ["token":"synthetic-pass","expires_at":Date().timeIntervalSince1970+3600] : ["subscribed":true,"maxBytes":50*1073741824]
            return ["status":200,"body":String(decoding:try JSONSerialization.data(withJSONObject:data),as:UTF8.self),"headers":["x-quota-remaining":"4096"]]
        },load:{vault},store:{vault=$0})
        func account(_ email:String)->[String:Any] {["email":email,"accessToken":"synthetic-access","refreshToken":"synthetic-refresh","expiresAt":Date().timeIntervalSince1970+3600]}
        _=try provider.perform("freeSave",account("a@example.test"))
        let status=try provider.perform("freeAccount",["operation":"status"])
        XCTAssertEqual((status["quota"] as? [String:Any])?["remaining"] as? Int64,4096)
        XCTAssertNil(status["accessToken"])
        let raw:[String:Any]=["tag":"node-fixture","protocol":"http","settings":["servers":[["address":"test.m1.fastly-masque.net","port":2499]],"headers":["Proxy-Authorization":"Bearer vyrax-native-pass"]],"streamSettings":["security":"tls","tlsSettings":["serverName":"test.m1.fastly-masque.net","allowInsecure":false,"alpn":["h2"]]]]
        let config:[String:Any]=["outbounds":[raw],"routing":["rules":[["outboundTag":"node-fixture"]]]]
        let prepared=try provider.prepare(config)
        let outbound=(prepared["outbounds"] as! [[String:Any]])[0]
        let target=(((prepared["routing"] as! [String:Any])["rules"] as! [[String:Any]])[0])["outboundTag"] as? String
        XCTAssertEqual(outbound["tag"] as? String,target);XCTAssertNotEqual(target,"node-fixture")
        let bytes=try JSONSerialization.data(withJSONObject:vault)
        XCTAssertFalse(String(decoding:bytes,as:UTF8.self).contains("synthetic-pass"))
        _=try provider.perform("freeSave",account("b@example.test"))
        _=try provider.perform("freeSwitch",["email":"a@example.test"])
        let removed=try provider.perform("freeRemove",["email":"b@example.test"])
        XCTAssertEqual((removed["accounts"] as? [[String:Any]])?.count,1)
        XCTAssertEqual(removed["email"] as? String,"a@example.test")
        let loggedOut=try provider.perform("freeLogout",[:]);XCTAssertEqual(loggedOut["signedIn"] as? Bool,false)
        XCTAssertThrowsError(try provider.prepare(config))
        XCTAssertEqual(requests.filter{$0=="token"}.count,1)
    }
    func testProtectionAndVaultErrorsDoNotAffectPersonalConnections() throws {
        XCTAssertThrowsError(try FreeProvider.data(["status":406,"body":"<html>challenge</html>"])){XCTAssertEqual(code($0),"err.freeChallenge")}
        let provider=FreeProvider(load:{throw VyraxError.code("err.store")},store:{_ in})
        let direct:[String:Any]=["outbounds":[["protocol":"freedom","tag":"direct"]]]
        XCTAssertNoThrow(try provider.prepare(direct))
        XCTAssertThrowsError(try provider.perform("freeAccount",["operation":"local"]))
        XCTAssertFalse(FreeProvider.validServer("test.fastly-masque.net.evil.test",443))
        XCTAssertFalse(FreeProvider.validToken("pass\r\ninjected"))
    }
}
