// SPDX-License-Identifier: MIT
import Foundation
import Darwin

enum Geo {
    static func lookup(_ hosts:[String]) throws -> [String:String] {
        guard hosts.count<=512,let url=Bundle.main.url(forResource:"geo",withExtension:"bin") else{return [:]}
        let data=try Data(contentsOf:url,options:.mappedIfSafe)
        func u16(_ at:Int)->Int{Int(data[at])|Int(data[at+1])<<8}
        func u32(_ at:Int)->UInt32{UInt32(data[at])|UInt32(data[at+1])<<8|UInt32(data[at+2])<<16|UInt32(data[at+3])<<24}
        guard data.count>=6 else{return [:]};let count=u16(0),start=2+count*2
        guard start+4<=data.count else{return [:]};let ranges=Int(u32(start)),base=start+4
        guard base+ranges*6<=data.count else{return [:]}
        var answer:[String:String]=[:]
        for host in Set(hosts) {
            guard host.utf8.count<=253,!host.contains(where:{$0.isWhitespace}) else{continue}
            var hints=addrinfo();hints.ai_family=AF_INET;hints.ai_socktype=SOCK_STREAM
            var result:UnsafeMutablePointer<addrinfo>?
            if getaddrinfo(host,nil,&hints,&result) != 0{continue}
            defer{if let result{freeaddrinfo(result)}}
            guard let address=result?.pointee.ai_addr else{continue}
            let ip=UnsafeRawPointer(address).assumingMemoryBound(to:sockaddr_in.self).pointee.sin_addr.s_addr.bigEndian
            var lo=0,hi=ranges-1
            while lo<hi{let mid=(lo+hi)/2;if ip<=u32(base+mid*6){hi=mid}else{lo=mid+1}}
            if lo<ranges{let index=u16(base+lo*6+4);if index<count{answer[host]=String(data:data[(2+index*2)..<(4+index*2)],encoding:.ascii)}}
        }
        return answer
    }
}
