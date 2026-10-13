// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import Foundation
import Security
import CryptoKit

enum VyraxError: Error { case code(String) }
func code(_ error: Error) -> String {
    if case VyraxError.code(let value) = error { return value }
    return "err.core"
}
enum SharedStore {
    static let group = "group.com.amyrax.vyrax"
    static func folder() throws -> URL {
        #if targetEnvironment(simulator)
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("VyraxSimulator")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
        #else
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { throw VyraxError.code("err.store") }
        return url
        #endif
    }
    static func key() throws -> SymmetricKey {
        var query: [String: Any] = [kSecClass as String:kSecClassGenericPassword, kSecAttrService as String:"Vyrax.Encryption", kSecAttrAccount as String:"store-key"]
        #if !targetEnvironment(simulator)
        guard let access = Bundle.main.object(forInfoDictionaryKey: "VyraxKeychainGroup") as? String, !access.contains("$(") else { throw VyraxError.code("err.store") }
        query[kSecAttrAccessGroup as String] = access
        #endif
        var read = query
        read[kSecReturnData as String] = true
        read[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let result = SecItemCopyMatching(read as CFDictionary, &item)
        if result == errSecSuccess, let bytes = item as? Data, bytes.count == 32 { return SymmetricKey(data:bytes) }
        guard result == errSecItemNotFound else { throw VyraxError.code("err.store") }
        var bytes = Data(count:32)
        guard bytes.withUnsafeMutableBytes({ SecRandomCopyBytes(kSecRandomDefault,32,$0.baseAddress!) }) == errSecSuccess else { throw VyraxError.code("err.store") }
        query[kSecValueData as String] = bytes
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let added = SecItemAdd(query as CFDictionary,nil)
        if added == errSecDuplicateItem { return try key() }
        guard added == errSecSuccess else { throw VyraxError.code("err.store") }
        return SymmetricKey(data:bytes)
    }
    static func save(_ object:[String:Any], name:String = "catalog") throws {
        let plain = try JSONSerialization.data(withJSONObject:object)
        guard plain.count <= 6*1024*1024 else { throw VyraxError.code("err.tooBig") }
        let box = try AES.GCM.seal(plain,using:key())
        guard let bytes = box.combined else { throw VyraxError.code("err.store") }
        try bytes.write(to:folder().appendingPathComponent(name+".encrypted"),options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
    }
    static func load(name:String = "catalog") throws -> [String:Any] {
        let url = try folder().appendingPathComponent(name+".encrypted")
        if !FileManager.default.fileExists(atPath:url.path) { return ["profiles":[],"subscriptions":[],"settings":["mode":"tun","preferencesVersion":1]] }
        let bytes = try Data(contentsOf:url)
        guard bytes.count <= 6*1024*1024+64 else { throw VyraxError.code("err.store") }
        let plain = try AES.GCM.open(AES.GCM.SealedBox(combined:bytes),using:key())
        guard let object = try JSONSerialization.jsonObject(with:plain) as? [String:Any] else { throw VyraxError.code("err.store") }
        return object
    }
    static func settings(_ raw:[String:Any]) throws -> [String:Any] {
        var value = raw
        value["mode"] = "tun";value["proxyShare"] = false;value["preferencesVersion"] = 1
        let mtu = raw["mtu"] as? Int ?? 1280
        guard (1280...1500).contains(mtu) else { throw VyraxError.code("err.config") }
        value["mtu"] = mtu
        let split = raw["splitTunneling"] as? Bool ?? false, bypass = raw["bypassSites"] as? Bool ?? false
        if split && bypass { throw VyraxError.code("err.routeConflict") }
        for (key,enabled) in [("splitAddresses",split),("bypassAddresses",bypass)] {
            let entries = raw[key] as? [String] ?? []
            guard entries.count <= 200, entries.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 260 && !$0.contains(where:{$0.isWhitespace}) }) else { throw VyraxError.code("err.routeList") }
            if enabled && entries.isEmpty { throw VyraxError.code("err.routeEmpty") }
            value[key] = entries
        }
        return value
    }
}
