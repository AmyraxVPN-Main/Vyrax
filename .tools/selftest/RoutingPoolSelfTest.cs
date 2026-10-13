using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Vyrax;

public static class RoutingPoolSelfTest {
    static int checks;
    static void Assert(bool ok,string name){if(!ok)throw new Exception(name);checks++;Console.WriteLine("PASS: "+name);}
    static Dictionary<string,object> Profile(string id,string source,int port) {return Json.Obj("id",id,"name",id,"sourceId",source,"protocol","vless","host","127.0.0.1","port",port,"uuid","00000000-0000-4000-8000-000000000001");}
    public static int Main(string[] args) {try{Run(args[0]).GetAwaiter().GetResult();Console.WriteLine(checks+" routing pool checks passed");return 0;}catch(Exception e){Console.WriteLine(e);return 1;}}
    static async Task Run(string exe) {
        var ports=new HashSet<int>();
        for(int i=0;i<48;i++){
            int port=Cores.FreePort();if(!ports.Add(port))throw new Exception("duplicate free port");
            var tcp=new TcpListener(IPAddress.Loopback,port);
            try{tcp.ExclusiveAddressUse=true;tcp.Start();using(var udp=new Socket(AddressFamily.InterNetwork,SocketType.Dgram,ProtocolType.Udp)){udp.ExclusiveAddressUse=true;udp.Bind(new IPEndPoint(IPAddress.Loopback,port));}}
            finally{tcp.Stop();}
        }
        Assert(true,"48 distinct local ports support both TCP and UDP bindings");
        using(var a=new Capture("A",70))using(var b=new Capture("B",280))using(var c=new Capture("C",10)) {
            var profiles=new[]{Profile("a","one",a.Port),Profile("b","one",b.Port),Profile("c","two",c.Port)};
            var loaded=Json.Read(Json.Write(Json.Obj("_catalog",profiles,"splitAddresses",new string[0])));
            Assert(RoutingPool.Catalog(loaded,profiles[0]).Length==3,"all profiles survive native JSON bridge decoding");
            Assert(Preferences.Addresses(loaded,"splitAddresses").Length==0,"decoded empty address arrays remain empty");
            var folder=Path.Combine(Path.GetTempPath(),"vyrax-pool-test-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(folder);Process core=null;
            try {
                int probe=Cores.FreePort(),api=Cores.FreePort();
                var config=(Dictionary<string,object>)Config.Xray(profiles[0],Cores.FreePort(),Cores.FreePort(),Cores.FreePort(),null,probe);
                var pool=new RoutingPool(config,exe,folder,api);pool.Build(config,profiles,"a","manual","one");
                var outbound=(List<object>)config["outbounds"];
                // Capture endpoints substitute only the protocol transport; all
                // pool rules, balancers, API updates and flow handling are real.
                for(int i=0;i<profiles.Length;i++)outbound[i]=Json.Obj("tag",RoutingPool.Tag(profiles[i]),"protocol","socks","settings",Json.Obj("servers",new[]{Json.Obj("address","127.0.0.1","port",new[]{a.Port,b.Port,c.Port}[i])}));
                var observer=(Dictionary<string,object>)config["observatory"];observer["probeURL"]="http://health.example.test/generate_204";observer["probeInterval"]="1s";
                var file=Path.Combine(folder,"pool.json");File.WriteAllText(file,Json.Write(config));Cores.Check(exe,"run -test -config \""+file+"\"");
                Assert(true,"production pool config accepted by bundled Xray");
                core=Cores.StartCore(exe,"run -config \""+file+"\"",null);
                using(var timeout=new CancellationTokenSource(5000)){await Cores.WaitPort(core,probe,timeout.Token);await Cores.WaitPort(core,api,timeout.Token);}
                var processId=core.Id;
                using(var held=await Tunnel(probe)) {
                    Assert(await Echo(held)=="A:ping","initial manual route uses A");
                    var revision=pool.Version;
                    var renamed=new Dictionary<string,object>(profiles[0]);renamed["name"]="Updated label";
                    await pool.Select(new[]{renamed,profiles[1],profiles[2]},"a","manual","one",CancellationToken.None);
                    Assert(pool.Version==revision,"unchanged subscription refresh skips live routing API commands");
                    Assert(Json.Str(pool.Profile("a"),"name")=="Updated label","unchanged refresh still updates display metadata");
                    Assert(await Echo(held)=="A:ping","unchanged refresh preserves active TCP streams");
                    await pool.Select(profiles,"b","manual","one",CancellationToken.None);
                    using(var fresh=await Tunnel(probe))Assert(await Echo(fresh)=="B:ping","manual switch sends new flows to B");
                    Assert(await Echo(held)=="A:ping","existing TCP flow survives switch to B");
                    Assert(pool.Mode=="manual","manual selection pins routing");
                    await pool.Select(profiles,"a","fastest","one",CancellationToken.None);
                    await WaitTarget(pool,"a");
                    using(var fresh=await Tunnel(probe))Assert(await Echo(fresh)=="A:ping","fastest selects lowest healthy RTT");
                    var targets=await pool.Targets(CancellationToken.None);
                    Assert(Array.IndexOf(targets,"c")<0,"faster server in another subscription is excluded");
                    await pool.Select(profiles,"a","balance","one",CancellationToken.None);
                    targets=await pool.Targets(CancellationToken.None);
                    Assert(targets.Length==2&&Array.IndexOf(targets,"a")>=0&&Array.IndexOf(targets,"b")>=0,"balance exposes two healthy fastest candidates");
                    var seen=new HashSet<string>();
                    for(int i=0;i<32&&seen.Count<2;i++)using(var fresh=await Tunnel(probe))seen.Add(await Echo(fresh));
                    Assert(seen.Contains("A:ping")&&seen.Contains("B:ping")&&!seen.Contains("C:ping"),"balance distributes new flows within the selected subscription");
                    Assert(await Echo(held)=="A:ping","existing flow survives automatic and balanced selections");
                    a.Alive=false;await pool.Select(profiles,"b","fastest","one",CancellationToken.None);await WaitTarget(pool,"b");
                    using(var fresh=await Tunnel(probe))Assert(await Echo(fresh)=="B:ping","failed fastest server is excluded automatically");
                    a.Alive=true;await pool.Select(profiles,"b","manual","one",CancellationToken.None);await Task.Delay(1400);
                    using(var fresh=await Tunnel(probe))Assert(await Echo(fresh)=="B:ping","manual choice remains pinned after a faster server recovers");
                    await pool.Select(profiles,"c","manual","two",CancellationToken.None);
                    using(var fresh=await Tunnel(probe))Assert(await Echo(fresh)=="C:ping","subscription selection switches the live route");
                    Assert(await Echo(held)=="A:ping","existing flow survives subscription switch");
                    bool rejected=false;try{await pool.Select(profiles,"c","fastest","missing",CancellationToken.None);}catch{rejected=true;}
                    Assert(rejected,"empty/unknown subscription selection is rejected");
                    using(var fresh=await Tunnel(probe))Assert(await Echo(fresh)=="C:ping","failed update leaves the prior route active");
                    var extended=new[]{profiles[0],profiles[1],profiles[2],Profile("new","two",c.Port)};
                    await pool.Select(extended,"c","manual","two",CancellationToken.None);
                    Assert((await pool.Command("lso --json",CancellationToken.None)).Contains(RoutingPool.Tag(extended[3])),"new subscription outbound is installed through the live API");
                    Assert(core.Id==processId&&!core.HasExited,"all changes keep the same core process and local listeners");
                    Assert(await Echo(held)=="A:ping","adding new outbounds leaves old streams intact");
                }
            } finally {if(core!=null){if(!core.HasExited){core.Kill();core.WaitForExit(1500);}core.Dispose();}Directory.Delete(folder,true);}
        }
    }
    static async Task WaitTarget(RoutingPool pool,string id) {
        var until=DateTime.UtcNow.AddSeconds(8);
        while(DateTime.UtcNow<until){var targets=await pool.Targets(CancellationToken.None);if(targets.Length==1&&targets[0]==id)return;await Task.Delay(120);}
        throw new Exception("automatic target did not become "+id);
    }
    static async Task<TcpClient> Tunnel(int port) {
        var peer=new TcpClient();await peer.ConnectAsync(IPAddress.Loopback,port);var stream=peer.GetStream();
        var text=Encoding.ASCII.GetBytes("CONNECT 198.51.100.42:8088 HTTP/1.1\r\nHost: 198.51.100.42:8088\r\n\r\n");await stream.WriteAsync(text,0,text.Length);
        var header=await Header(stream);if(!header.StartsWith("HTTP/1.1 200")){peer.Dispose();throw new Exception("CONNECT rejected");}return peer;
    }
    static async Task<string> Echo(TcpClient peer){var stream=peer.GetStream();var bytes=Encoding.ASCII.GetBytes("ping\n");await stream.WriteAsync(bytes,0,bytes.Length);return (await Line(stream)).Trim();}
    static async Task<string> Line(NetworkStream stream){var b=new byte[1];var text=new StringBuilder();while(text.Length<4096){if(await stream.ReadAsync(b,0,1)==0)throw new IOException();text.Append((char)b[0]);if(b[0]==10)return text.ToString();}throw new IOException();}
    static async Task<string> Header(NetworkStream stream){var text=new StringBuilder();while(text.Length<8192){text.Append(await Line(stream));if(text.ToString().EndsWith("\r\n\r\n"))return text.ToString();}throw new IOException();}
    static async Task Exact(NetworkStream stream,byte[] bytes){int at=0;while(at<bytes.Length){var n=await stream.ReadAsync(bytes,at,bytes.Length-at);if(n==0)throw new IOException();at+=n;}}
    sealed class Capture:IDisposable {
        readonly TcpListener server=new TcpListener(IPAddress.Loopback,0);readonly CancellationTokenSource stop=new CancellationTokenSource();readonly string name;readonly int delay;
        public bool Alive=true;public int Port{get{return ((IPEndPoint)server.LocalEndpoint).Port;}}
        public Capture(string label,int milliseconds){name=label;delay=milliseconds;server.Start();Accept();}
        async void Accept(){while(!stop.IsCancellationRequested){try{Handle(await server.AcceptTcpClientAsync());}catch{return;}}}
        async void Handle(TcpClient peer){using(peer)using(stop.Token.Register(()=>peer.Close()))try {
            var stream=peer.GetStream();var greeting=new byte[2];await Exact(stream,greeting);var methods=new byte[greeting[1]];await Exact(stream,methods);await stream.WriteAsync(new byte[]{5,0},0,2);
            var request=new byte[4];await Exact(stream,request);int size=request[3]==1?4:request[3]==4?16:0;
            if(request[3]==3){var length=new byte[1];await Exact(stream,length);size=length[0];}
            var address=new byte[size+2];await Exact(stream,address);var port=address[size]*256+address[size+1];
            var reply=new byte[]{5,(byte)(Alive?0:4),0,1,127,0,0,1,0,80};await stream.WriteAsync(reply,0,reply.Length);if(!Alive)return;
            if(port==8088){while(true){var line=await Line(stream);var output=Encoding.ASCII.GetBytes(name+":"+line);await stream.WriteAsync(output,0,output.Length);}}
            else {await Header(stream);await Task.Delay(delay,stop.Token);var response=Encoding.ASCII.GetBytes("HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");await stream.WriteAsync(response,0,response.Length);}
        }catch{} }
        public void Dispose(){stop.Cancel();server.Stop();stop.Dispose();}
    }
}
