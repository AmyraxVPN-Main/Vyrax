using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Vyrax;

public static class DelayProbeSelfTest {
    static int checks;
    const string Url="http://delay.example.test/generate_204";
    static void Assert(bool ok,string label) { if(!ok)throw new Exception(label);checks++;Console.WriteLine("PASS: "+label); }
    public static int Main(string[] args) {
        try { Run(args[0]).GetAwaiter().GetResult();Console.WriteLine(checks+" delay checks passed");return 0; }
        catch(Exception e) { Console.WriteLine(e);return 1; }
    }
    static async Task Run(string xray) {
        Assert(DelayProbe.TestUrl=="https://www.gstatic.com/generate_204"&&DelayProbe.TimeoutMilliseconds==8000,"FlClash default URL and timeout");
        await HttpCase("warm",204);
        await HttpCase("redirect",302);
        await HttpCase("error-status",503);
        await HttpCase("first-timeout",204);
        await HttpCase("repeat-timeout",204);
        await InvalidTls();
        await CoreRoute(xray);
    }
    static async Task<string> Header(NetworkStream stream) {
        var result=new StringBuilder();var one=new byte[1];
        while(result.Length<8192&&!result.ToString().EndsWith("\r\n\r\n")) {
            if(await stream.ReadAsync(one,0,1)==0)throw new Exception("peer closed before headers");
            result.Append((char)one[0]);
        }
        return result.ToString();
    }
    static async Task Reply(NetworkStream stream,int status) {
        var bytes=Encoding.ASCII.GetBytes("HTTP/1.1 "+status+" Test\r\nContent-Length: 0\r\nConnection: keep-alive\r\n"+
            (status==302?"Location: http://redirect.example.test/never-fetch\r\n":"")+"\r\n");
        await stream.WriteAsync(bytes,0,bytes.Length);
    }
    static async Task HttpCase(string mode,int status) {
        var listener=new TcpListener(IPAddress.Loopback,0);listener.Start();
        try {
            var task=DelayProbe.Measure(((IPEndPoint)listener.LocalEndpoint).Port,Url,mode.Contains("timeout")?600:3000);
            var accept=listener.AcceptTcpClientAsync();
            if(await Task.WhenAny(accept,Task.Delay(3000))!=accept)throw new Exception("proxy not used");
            using(var peer=await accept) {
                var stream=peer.GetStream();
                Assert((await Header(stream)).StartsWith("HEAD "+Url+" HTTP/1.1"),mode+": HEAD uses requested URL through proxy");
                if(mode=="first-timeout") {
                    Assert(await task==null,"stalled first response returns Timeout");
                    return;
                }
                var wall=Stopwatch.StartNew();
                await Task.Delay(220);await Reply(stream,status);
                Assert((await Header(stream)).StartsWith("HEAD "+Url+" HTTP/1.1"),mode+": second HEAD reuses connection and does not follow redirects");
                if(mode!="repeat-timeout") { await Task.Delay(35);await Reply(stream,status); }
                var result=await task;
                Assert(result.HasValue&&result.Value>0,mode+": received response has positive delay");
                if(mode=="warm") Assert(result.Value+120<wall.ElapsedMilliseconds,"unified delay excludes initial request time");
                if(mode=="repeat-timeout") Assert(result.Value>=200&&result.Value<500,"failed repeat keeps successful first measurement");
            }
        } finally { listener.Stop(); }
    }
    static async Task InvalidTls() {
        var listener=new TcpListener(IPAddress.Loopback,0);listener.Start();
        try {
            var task=DelayProbe.Measure(((IPEndPoint)listener.LocalEndpoint).Port,"https://delay.example.test/generate_204",1200);
            using(var peer=await listener.AcceptTcpClientAsync()) {
                var stream=peer.GetStream();
                Assert((await Header(stream)).StartsWith("CONNECT delay.example.test:443"),"HTTPS tunnels through the selected proxy");
                var reply=Encoding.ASCII.GetBytes("HTTP/1.1 200 Connection established\r\n\r\n");await stream.WriteAsync(reply,0,reply.Length);
                var hello=new byte[4096];var n=await stream.ReadAsync(hello,0,hello.Length);
                Assert(n>11&&hello[0]==22&&hello[9]==3&&hello[10]==3,"TLS 1.2 is offered");
                Assert(Encoding.ASCII.GetString(hello,0,n).Contains("delay.example.test"),"test target is sent as TLS SNI");
                var invalid=Encoding.ASCII.GetBytes("HTTP/1.1 200 OK\r\n\r\n");await stream.WriteAsync(invalid,0,invalid.Length);
                Assert(await task==null,"plain TCP / invalid TLS cannot pass HTTPS delay test");
            }
        } finally { listener.Stop(); }
    }
    static async Task Exact(NetworkStream stream,byte[] bytes) {
        int at=0;while(at<bytes.Length){int n=await stream.ReadAsync(bytes,at,bytes.Length-at);if(n==0)throw new Exception("incomplete SOCKS request");at+=n;}
    }
    static async Task CoreRoute(string xray) {
        // Real bundled Xray and production routing; outbound capture stays on
        // loopback. The reserved destination is never reached on the Internet.
        var listener=new TcpListener(IPAddress.Loopback,0);listener.Start();
        var folder=Path.Combine(Path.GetTempPath(),"vyrax-delay-test-"+Guid.NewGuid().ToString("N"));Process core=null;
        Directory.CreateDirectory(folder);
        try {
            var p=Json.Obj("protocol","vless","host","127.0.0.1","port",443,"uuid","00000000-0000-4000-8000-000000000001");
            int probe=Cores.FreePort();
            var config=(System.Collections.Generic.Dictionary<string,object>)Config.Xray(p,Cores.FreePort(),Cores.FreePort(),Cores.FreePort(),null,probe);
            config["outbounds"]=new[]{Json.Obj("tag","proxy","protocol","socks","settings",Json.Obj("servers",new[]{Json.Obj("address","127.0.0.1","port",((IPEndPoint)listener.LocalEndpoint).Port)})),Json.Obj("tag","direct","protocol","blackhole")};
            var file=Path.Combine(folder,"xray.json");File.WriteAllText(file,Json.Write(config));core=Cores.StartCore(xray,"run -config \""+file+"\"",null);
            using(var deadline=new CancellationTokenSource(5000))await Cores.WaitPort(core,probe,deadline.Token);
            var task=DelayProbe.Measure(probe,"http://198.51.100.42/generate_204",4000);
            // Xray's plain HTTP inbound creates an outbound for each request.
            // HTTPS in production uses a pooled CONNECT/TLS tunnel instead.
            for(int i=0;i<2;i++) {
            var accept=listener.AcceptTcpClientAsync();
            if(await Task.WhenAny(task,accept)!=accept)throw new Exception("Xray did not route through the tested outbound");
            using(var peer=await accept) {
                var stream=peer.GetStream();var greeting=new byte[2];await Exact(stream,greeting);var methods=new byte[greeting[1]];await Exact(stream,methods);
                await stream.WriteAsync(new byte[]{5,0},0,2);var header=new byte[4];await Exact(stream,header);
                Assert(header[0]==5&&header[1]==1&&header[3]==1,"delay probe reaches the configured outbound through real Xray");
                var address=new byte[6];await Exact(stream,address);
                Assert(address[0]==198&&address[1]==51&&address[2]==100&&address[3]==42&&address[4]==0&&address[5]==80,"Xray forwards the intended URL destination");
                var bound=new byte[]{5,0,0,1,127,0,0,1,0,80};await stream.WriteAsync(bound,0,bound.Length);
                Assert((await Header(stream)).StartsWith("HEAD /generate_204 HTTP/1.1"),"Xray carries HEAD "+(i+1));await Task.Delay(25);await Reply(stream,204);
            }
            }
            Assert((await task).HasValue,"real core returns the unified HTTP delay");
        } finally {
            if(core!=null){if(!core.HasExited){core.Kill();core.WaitForExit(1500);}core.Dispose();}
            listener.Stop();Directory.Delete(folder,true);
        }
    }
}
