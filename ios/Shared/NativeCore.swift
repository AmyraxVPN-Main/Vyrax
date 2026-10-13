// SPDX-License-Identifier: MIT
import Foundation
import VyraxCore

enum NativeCore {
    static func invoke(_ method:String, _ payload:Any = [:]) throws -> Any {
        let bytes = try JSONSerialization.data(withJSONObject:["method":method,"payload":payload])
        guard let text = String(data:bytes,encoding:.utf8) else { throw VyraxError.code("err.config") }
        let output = text.withCString { VyraxInvoke(UnsafeMutablePointer(mutating:$0)) }
        guard let output else { throw VyraxError.code("err.core") }
        defer { VyraxFree(output) }
        let result = Data(String(cString:output).utf8)
        guard let obj = try JSONSerialization.jsonObject(with:result) as? [String:Any] else { throw VyraxError.code("err.core") }
        if let error = obj["error"] as? String { throw VyraxError.code(error) }
        return obj["result"] ?? NSNull()
    }
}
