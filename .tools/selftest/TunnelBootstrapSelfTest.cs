using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Vyrax;

// Real Xray + synthetic DNS/VLESS servers. Never installs routes or changes DNS.
public static class TunnelBootstrapSelfTest {
    static int checks;
    static void Assert(bool ok,string label){if(!ok)throw new Exception(label);checks++;Console.WriteLine("PASS: "+label);}
    public static int Main(string[] args){try{Run(args[0]).GetAwaiter().GetResult();Console.WriteLine(checks+" TUN bootstrap checks passed");return 0;}catch(Exception e){Console.WriteLine("FAIL: "+e);return 1;}}
    static async Task Run(string exe) {
        Assert(NetworkUplink.IsTunnel("FlClash","Meta Tunnel",NetworkInterfaceType.Ethernet),"gateway-less Meta Tunnel is excluded from physical uplinks");
        Assert(NetworkUplink.IsTunnel("Vyrax","Vyrax",NetworkInterfaceType.Ethernet),"own TUN cannot become its transport uplink");
        Assert(!NetworkUplink.IsTunnel("Wi-Fi","Intel Wireless",NetworkInterfaceType.Wireless80211),"physical Wi-Fi remains eligible");
        var uplink=NetworkUplink.Capture();Assert(!String.IsNullOrEmpty(uplink.Name),"read-only uplink snapshot finds an active adapter");
        var loopback=NetworkInterface.GetAllNetworkInterfaces().First(adapter=>adapter.NetworkInterfaceType==NetworkInterfaceType.Loopback).Name;
        using(var dns=new DnsCapture())using(var server=new VlessCapture())using(var ipv6Server=new VlessCapture(true)) {
            var ipv6Available=true;
            using(var peer=new TcpClient(AddressFamily.InterNetworkV6))try{await peer.ConnectAsync(IPAddress.IPv6Loopback,ipv6Server.Port);}
            catch(SocketException e){if(e.SocketErrorCode!=SocketError.AccessDenied)throw;ipv6Available=false;Console.WriteLine("SKIP: Windows denies even unbound IPv6 loopback TCP on this host (WSAEACCES)");}
            var profiles=new[]{Profile("a","server-a.vyrax.invalid",server.Port)};
            var original=Json.Write(profiles[0]);
            var old=(Dictionary<string,object>)Config.Xray(profiles[0],Cores.FreePort(),Cores.FreePort(),Cores.FreePort(),null,Cores.FreePort());
            Assert(!old.ContainsKey("dns"),"proxy mode keeps its existing DNS behaviour");
            var bound=(Dictionary<string,object>)Config.Outbound(profiles[0],loopback);
            Assert(Json.Str(profiles[0],"host")=="server-a.vyrax.invalid"&&Json.Write(profiles[0])==original,"binding never rewrites saved server addresses");
            var tlsProfile=new Dictionary<string,object>(profiles[0]);tlsProfile["tls"]=true;
            var tlsStream=(Dictionary<string,object>)((Dictionary<string,object>)Config.Outbound(tlsProfile,loopback))["streamSettings"];
            Assert(Json.Str((Dictionary<string,object>)tlsStream["tlsSettings"],"serverName")==Json.Str(tlsProfile,"host"),"TLS SNI stays the original server hostname");

            var folder=Path.Combine(Path.GetTempPath(),"vyrax-bootstrap-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(folder);
            Process core=null;
            try {
                // Merely configuring an internal DNS server does not fix the
                // legacy transport: without sockopt.domainStrategy it still
                // uses Windows DNS and cannot resolve this synthetic hostname.
                var legacyProbe=Cores.FreePort();
                var legacy=(Dictionary<string,object>)Config.Xray(profiles[0],Cores.FreePort(),Cores.FreePort(),Cores.FreePort(),null,legacyProbe);
                legacy["dns"]=Json.Obj("servers",new[]{Json.Obj("address","127.0.0.1","port",dns.Port)});
                var legacyFile=Path.Combine(folder,"legacy.json");File.WriteAllText(legacyFile,Json.Write(legacy));
                core=Cores.StartCore(exe,"run -config \""+legacyFile+"\"",null);
                using(var deadline=new CancellationTokenSource(5000))await Cores.WaitPort(core,legacyProbe,deadline.Token);
                var legacyHealthy=false;try{legacyHealthy=await Health(legacyProbe);}catch(HttpRequestException){}catch(TaskCanceledException){}
                Assert(!legacyHealthy&&!dns.Has("server-a.vyrax.invalid"),"legacy domain transport depends on Windows DNS and ignores the independent resolver");
                core.Kill();core.WaitForExit(2000);core.Dispose();core=null;
                int probe=Cores.FreePort();
                var config=(Dictionary<string,object>)Config.Xray(profiles[0],Cores.FreePort(),Cores.FreePort(),Cores.FreePort(),Json.Obj("splitTunneling",true,"splitAddresses",new[]{"allowed.example"}),probe,0,loopback,new[]{"127.0.0.1"});
                var dnsConfig=(Dictionary<string,object>)config["dns"];
                var noNetworkDns=(Dictionary<string,object>)Config.Xray(profiles[0],Cores.FreePort(),Cores.FreePort(),Cores.FreePort(),null,Cores.FreePort(),0,loopback,new string[0]);
                Assert(noNetworkDns.ContainsKey("dns")&&Json.Items(((Dictionary<string,object>)noNetworkDns["dns"])["servers"]).Length==2,"an uplink without configured network DNS still has HTTPS bootstrap resolvers");
                var productionFile=Path.Combine(folder,"production.json");File.WriteAllText(productionFile,Json.Write(config));Cores.Check(exe,"run -test -config \""+productionFile+"\"");
                Assert(true,"bundled Xray accepts the production HTTPS bootstrap configuration");
                Assert(Json.Bool(dnsConfig,"enableParallelQuery")&&Json.Items(dnsConfig["servers"]).Length==3,"network DNS races HTTPS alternatives rather than serial timeouts");
                var dnsServers=Json.Items(dnsConfig["servers"]);
                Assert(dnsServers.OfType<Dictionary<string,object>>().Skip(1).All(resolver=>Json.Str(resolver,"address").StartsWith("https://")&&!Json.Bool(resolver,"allowInsecure")),"bootstrap alternatives use HTTPS with certificate checks enabled");
                // Keep every test socket local; substitutes exercise the same
                // DNS race with a dead first resolver and a healthy second one.
                var stalled=Cores.FreePort();
                dnsConfig["servers"]=new[]{Json.Obj("address","127.0.0.1","port",stalled,"timeoutMs",4000),Json.Obj("address","127.0.0.1","port",dns.Port,"timeoutMs",4000)};
                var socketOptions=(Dictionary<string,object>)((Dictionary<string,object>)bound["streamSettings"])["sockopt"];
                Assert(Json.Str(socketOptions,"domainStrategy")=="ForceIPv4v6","failed bootstrap cannot silently re-enter Windows DNS; IPv6-only servers retain a fallback");
                var pool=new RoutingPool(config,exe,folder,Cores.FreePort());pool.Build(config,profiles,"a","manual","source");
                var outbounds=Json.Items(config["outbounds"]).Cast<Dictionary<string,object>>().ToArray();
                var bootstrap=outbounds.Single(outbound=>Json.Str(outbound,"tag")=="bootstrap-direct");
                Assert(Json.Str((Dictionary<string,object>)((Dictionary<string,object>)bootstrap["streamSettings"])["sockopt"],"interface")==loopback,"pool preserves the separate bound DNS outbound");
                var rules=Json.Items(((Dictionary<string,object>)config["routing"])["rules"]).Cast<Dictionary<string,object>>().ToArray();
                Assert(Json.Str(rules[0],"outboundTag")=="bootstrap-direct","bootstrap DNS is routed before probe/private/split rules");
                // Poison the ordinary direct outbound. The bootstrap must remain
                // independent, and the dedicated probe must still use the VPN.
                var direct=outbounds.Single(outbound=>Json.Str(outbound,"tag")=="direct");direct["protocol"]="blackhole";direct.Remove("streamSettings");
                var observer=(Dictionary<string,object>)config["observatory"];observer["probeURL"]="http://traffic.example.test/generate_204";observer["probeInterval"]="1h";
                config["log"]=Json.Obj("loglevel","debug");var log=new List<string>();
                var file=Path.Combine(folder,"xray.json");File.WriteAllText(file,Json.Write(config));Cores.Check(exe,"run -test -config \""+file+"\"");
                core=Cores.StartCore(exe,"run -config \""+file+"\"",null,line=>{lock(log){log.Add(line);if(log.Count>100)log.RemoveAt(0);}});
                using(var deadline=new CancellationTokenSource(5000))await Cores.WaitPort(core,probe,deadline.Token);
                var watch=Stopwatch.StartNew();
                Assert(await Health(probe),"domain transport connects using independent bootstrap DNS with ordinary direct traffic blocked");
                Assert(watch.ElapsedMilliseconds<2500,"healthy bootstrap resolver wins without waiting for the blocked first resolver");
                Assert(dns.Has("server-a.vyrax.invalid"),"transport hostname reaches the bootstrap resolver");
                Assert(!dns.Has("traffic.example.test"),"application destination hostname stays inside VLESS instead of bootstrap DNS");
                Assert(server.HttpRequests>0,"HTTP verification crosses the real VLESS transport");
                var processId=core.Id;
                var added=new[]{profiles[0],Profile("b","server-b.vyrax.invalid",server.Port)};
                await pool.Select(added,"b","manual","source",CancellationToken.None);
                Assert(await Health(probe)&&dns.Has("server-b.vyrax.invalid"),"new domain added during a live session uses the same bootstrap path");
                var list=Json.Read(await pool.Command("lso --json",CancellationToken.None));
                var installed=Json.Write(list);
                Assert(installed.Contains(RoutingPool.Tag(added[1],loopback)),"live API installs the outbound with its uplink binding");
                Assert(core.Id==processId&&!core.HasExited,"live server switch keeps the existing core running");
                var revision=pool.Version;
                await pool.Select(added,"b","manual","source",CancellationToken.None);
                Assert(pool.Version==revision,"unchanged refresh stays a no-op with bound outbounds");
                if(ipv6Available) {
                    var ipv6Added=new[]{added[0],added[1],Profile("v6","server-v6.vyrax.invalid",ipv6Server.Port)};
                    await pool.Select(ipv6Added,"v6","manual","source",CancellationToken.None);
                    try{Assert(await Health(probe,6000)&&ipv6Server.HttpRequests>0,"an IPv6-only transport domain connects through the IPv6 bootstrap fallback");}
                    catch{lock(log)foreach(var line in log.Skip(Math.Max(0,log.Count-45)))Console.WriteLine(line);throw;}
                }
            } finally {if(core!=null){if(!core.HasExited){core.Kill();core.WaitForExit(2000);}core.Dispose();}Directory.Delete(folder,true);}
        }
    }
    static Dictionary<string,object> Profile(string id,string host,int port){return Json.Obj("id",id,"sourceId","source","protocol","vless","host",host,"port",port,"uuid","00000000-0000-4000-8000-000000000001");}
    static async Task<bool> Health(int port,int timeoutMs=5000) {
        using(var handler=new HttpClientHandler{UseProxy=true,Proxy=new WebProxy("http://127.0.0.1:"+port),AllowAutoRedirect=false})
        using(var client=new HttpClient(handler){Timeout=TimeSpan.FromMilliseconds(timeoutMs)})
        using(var response=await client.GetAsync("http://traffic.example.test/generate_204"))return response.StatusCode==HttpStatusCode.NoContent;
    }
    static async Task Exact(NetworkStream stream,byte[] buffer){for(int at=0;at<buffer.Length;){int count=await stream.ReadAsync(buffer,at,buffer.Length-at);if(count==0)throw new IOException();at+=count;}}
    sealed class DnsCapture:IDisposable {
        readonly UdpClient socket=new UdpClient(new IPEndPoint(IPAddress.Loopback,0));
        public readonly HashSet<string> Queries=new HashSet<string>();
        public bool Has(string host){lock(Queries)return Queries.Contains(host);}
        public int Port{get{return ((IPEndPoint)socket.Client.LocalEndPoint).Port;}}
        public DnsCapture(){Listen();}
        async void Listen(){while(true)try {
            var packet=await socket.ReceiveAsync();var query=packet.Buffer;int at=12;var labels=new List<string>();
            while(query[at]!=0){int length=query[at++];labels.Add(Encoding.ASCII.GetString(query,at,length));at+=length;}
            at++;int type=query[at]*256+query[at+1];at+=4;var host=String.Join(".",labels);lock(Queries)Queries.Add(host);
            var ipv6=host.StartsWith("server-v6.");var hasAnswer=(type==1&&!ipv6)||(type==28&&ipv6);
            var answer=new List<byte>(query.Take(at));answer[2]=0x81;answer[3]=0x80;answer[6]=0;answer[7]=(byte)(hasAnswer?1:0);answer[8]=answer[9]=answer[10]=answer[11]=0;
            if(hasAnswer){var address=(ipv6?IPAddress.IPv6Loopback:IPAddress.Loopback).GetAddressBytes();answer.AddRange(new byte[]{0xc0,0x0c,0,(byte)type,0,1,0,0,0,60,0,(byte)address.Length});answer.AddRange(address);}
            var bytes=answer.ToArray();await socket.SendAsync(bytes,bytes.Length,packet.RemoteEndPoint);
        }catch{return;}}
        public void Dispose(){socket.Close();}
    }
    sealed class VlessCapture:IDisposable {
        readonly TcpListener listener;readonly CancellationTokenSource stop=new CancellationTokenSource();
        public int HttpRequests;
        public int Port{get{return ((IPEndPoint)listener.LocalEndpoint).Port;}}
        public VlessCapture(bool ipv6=false){listener=new TcpListener(ipv6?IPAddress.IPv6Loopback:IPAddress.Loopback,0);listener.Start();Accept();}
        async void Accept(){while(!stop.IsCancellationRequested)try{Handle(await listener.AcceptTcpClientAsync());}catch{return;}}
        async void Handle(TcpClient peer){using(peer)using(stop.Token.Register(()=>peer.Close()))try {
            var stream=peer.GetStream();var header=new byte[18];await Exact(stream,header);
            if(header[0]!=0)throw new IOException();await Exact(stream,new byte[header[17]]);
            var request=new byte[4];await Exact(stream,request);if(request[0]!=1)throw new IOException();
            int size=request[3]==1?4:request[3]==3?16:0;
            if(request[3]==2){var length=new byte[1];await Exact(stream,length);size=length[0];}
            await Exact(stream,new byte[size]);await stream.WriteAsync(new byte[]{0,0},0,2);
            var text=new StringBuilder();var b=new byte[1];
            while(text.Length<8192&&!text.ToString().EndsWith("\r\n\r\n")){await Exact(stream,b);text.Append((char)b[0]);}
            Interlocked.Increment(ref HttpRequests);
            var response=Encoding.ASCII.GetBytes("HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");await stream.WriteAsync(response,0,response.Length);
        }catch{} }
        public void Dispose(){stop.Cancel();listener.Stop();stop.Dispose();}
    }
}
