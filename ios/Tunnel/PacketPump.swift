// SPDX-License-Identifier: MIT
// Public NEPacketTunnelFlow API, no private descriptor lookup or KVC.
import Foundation
import NetworkExtension
import HevSocks5Tunnel
import Darwin

final class PacketPump {
    private let queue = DispatchQueue(label:"Vyrax.packets",qos:.userInitiated)
    private let worker = DispatchQueue(label:"Vyrax.tun2socks",qos:.userInitiated)
    private var input:DispatchSourceRead?
    private var fd:Int32 = -1, coreFD:Int32 = -1
    private var running = false
    private var uploaded=0,downloaded=0
    private let stopped = DispatchGroup()
    private weak var flow:NEPacketTunnelFlow?
    var failure:(()->Void)?
    func start(flow:NEPacketTunnelFlow, mtu:Int) throws {
        var sockets:[Int32] = [-1,-1]
        guard socketpair(AF_UNIX,SOCK_DGRAM,0,&sockets) == 0 else { throw VyraxError.code("err.core") }
        fd = sockets[0];coreFD = sockets[1];self.flow = flow
        _ = fcntl(fd,F_SETFL,O_NONBLOCK)
        var size:Int32 = 1024*1024
        setsockopt(fd,SOL_SOCKET,SO_SNDBUF,&size,socklen_t(MemoryLayout.size(ofValue:size)))
        setsockopt(coreFD,SOL_SOCKET,SO_SNDBUF,&size,socklen_t(MemoryLayout.size(ofValue:size)))
        running = true
        let source = DispatchSource.makeReadSource(fileDescriptor:fd,queue:queue)
        input = source
        source.setEventHandler { [weak self] in self?.receive() }
        source.resume()
        let config = """
        tunnel:
          mtu: \(mtu)
        socks5:
          address: 127.0.0.1
          port: 10808
          udp: udp
        misc:
          task-stack-size: 24576
          tcp-buffer-size: 4096
          max-session-count: 256
          connect-timeout: 10000
          log-file: null
          log-level: error
        """
        let core = coreFD
        stopped.enter()
        worker.async { [weak self] in
            let bytes = Array(config.utf8)
            let result = bytes.withUnsafeBufferPointer { hev_socks5_tunnel_main_from_str($0.baseAddress,UInt32($0.count),core) }
            self?.stopped.leave()
            self?.queue.async { [weak self] in if self?.running == true { self?.failure?() } }
            _ = result
        }
        queue.async { [weak self] in self?.readFlow() }
    }
    private func readFlow() {
        guard running,let flow else{return}
        flow.readPackets { [weak self] packets,protocols in
            self?.queue.async { [weak self] in
                guard let self,self.running else{return}
                for (packet,proto) in zip(packets,protocols) {
                    guard (proto.int32Value==AF_INET || proto.int32Value==AF_INET6),packet.count<=65535 else{continue}
                    var family = UInt32(proto.int32Value).bigEndian
                    var bytes = Data(bytes:&family,count:4);bytes.append(packet)
                    // Datagram writes are atomic and bounded. Under pressure the
                    // stack retransmits TCP; no unbounded packet queues accumulate.
                    let sent=bytes.withUnsafeBytes { Darwin.send(self.fd,$0.baseAddress,$0.count,0) }
                    if sent==bytes.count{self.uploaded+=packet.count}
                }
                self.readFlow()
            }
        }
    }
    private func receive() {
        guard running else{return}
        var buffer = [UInt8](repeating:0,count:65539)
        var packets:[Data]=[],protocols:[NSNumber]=[]
        for _ in 0..<64 {
            let count = Darwin.recv(fd,&buffer,buffer.count,0)
            if count<=4{break}
            let proto = buffer[4]>>4 == 4 ? AF_INET : AF_INET6
            packets.append(Data(buffer[4..<count]));protocols.append(NSNumber(value:proto))
            downloaded+=count-4
        }
        if !packets.isEmpty{flow?.writePackets(packets,withProtocols:protocols)}
    }
    func stop() {
        queue.sync { running=false;input?.cancel();input=nil }
        // quit waits for Hev's initialization barrier, then wakes its event loop.
        hev_socks5_tunnel_quit()
        stopped.wait()
        if fd>=0 {Darwin.close(fd);fd = -1}
        if coreFD>=0 {Darwin.close(coreFD);coreFD = -1}
    }
    func stats()->[String:Any] {
        // Counters are owned by the packet queue, so the UI never reads Hev's
        // unsynchronized C globals from its worker thread.
        return queue.sync{["up":uploaded,"down":downloaded]}
    }
}
