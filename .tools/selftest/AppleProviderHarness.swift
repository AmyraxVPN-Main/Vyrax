// SPDX-License-Identifier: MIT
// Synthetic native provider smoke test; no account or network access.
import Foundation
enum VyraxError:Error {case code(String)}
enum NativeCore {static func invoke(_ method:String,_ payload:Any) throws -> Any {throw VyraxError.code("err.action")}}
enum SharedStore {
    static func folder() throws -> URL {FileManager.default.temporaryDirectory}
    static func load(name:String) throws -> [String:Any] {[:]}
    static func save(_ value:[String:Any],name:String) throws {}
}
@main enum Harness {
    static func main() throws {
        let password=try FreeCrypto.perform(["operation":"authPassword","email":"test@example.com","password":"päss-آزمایش"])
        precondition(password=="852a0f233a2a338e0a26a3a61480e8b9ddb6f0ebde2f0c8155767bd7979aca03")
        let signed=try FreeCrypto.perform(["operation":"hawk","sessionToken":String(repeating:"00",count:32),"endpoint":"verify","body":"{\"code\":\"123456\"}","ts":1700000000,"nonce":"nonce123"])
        precondition(signed.contains("mac=\"uGwkJbaK0OVoYPoUHhWHAWqXaLGWHx/G4pgC7CYVYEQ=\""))
        var vault=[String:Any]()
        let provider=FreeProvider(transport:{_ in ["status":200,"body":"{\"token\":\"synthetic-pass\",\"expires_at\":9999999999}"]},load:{vault},store:{vault=$0})
        _=try provider.perform("freeSave",["email":"fixture@example.test","accessToken":"synthetic-access","refreshToken":"synthetic-refresh","expiresAt":9999999999.0])
        let state=try provider.perform("freeAccount",["operation":"local"])
        precondition(state["signedIn"] as? Bool==true && state["accessToken"]==nil)
        _=try provider.perform("freeLogout",[:])
        precondition(!FreeProvider.validServer("bad.fastly-masque.net.example",443))
        print("Native Firefox crypto vectors and account isolation passed")
    }
}
