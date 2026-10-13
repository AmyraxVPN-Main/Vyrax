using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Net.Sockets;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Diagnostics;

public static class SubscriptionFetchSelfTest {
    public static int Main(string[] args) {
        try {Run(args[0],args.Length>1?args[1]:null).GetAwaiter().GetResult();return 0;}catch(Exception e){Console.WriteLine(e);return 1;}
    }
    static async Task Run(string host,string core) {
        var method=Assembly.LoadFrom(host).GetType("Vyrax.Engine").GetMethod("Fetch");
        var title="base64:"+Convert.ToBase64String(Encoding.UTF8.GetBytes("کاربر اصلی"));
        await Response(method,"Profile-Title: "+title+"\r\nSubscription-Userinfo: upload=1;download=2;total=100\r\n","title",title);
        await Response(method,"Content-Disposition: attachment; filename*=UTF-8''Amyrax-100GB-V2.txt\r\n","disposition","attachment; filename*=UTF-8''Amyrax-100GB-V2.txt");
        await Response(method,"Profile-Title: base64:U3Vic2NyaXB0aW9u\r\nContent-Disposition: attachment; filename=\"Amyrax-100GB-V2\"\r\n","disposition","attachment; filename=\"Amyrax-100GB-V2\"",true);
        await Reuse(method);
        if(core!=null)await ConnectedPaths(host,core);
        Console.WriteLine("Native subscription headers and UTF-8 body checks passed");
    }
    static int FreePort(){var socket=new TcpListener(IPAddress.Loopback,0);socket.Start();int port=((IPEndPoint)socket.LocalEndpoint).Port;socket.Stop();return port;}
    static async Task ConnectedPaths(string host,string core) {
        var assembly=Assembly.LoadFrom(host);var engineType=assembly.GetType("Vyrax.Engine");
        var folder=Path.Combine(Path.GetTempPath(),"vyrax-sub-connected-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(folder);
        var store=Activator.CreateInstance(assembly.GetType("Vyrax.Store"),new object[]{folder});
        var engine=Activator.CreateInstance(engineType,new object[]{store,Path.GetDirectoryName(core)});
        Process child=null;var origin=new TcpListener(IPAddress.Loopback,0);origin.Start();int hits=0;
        using(var cancel=new CancellationTokenSource(15000)) {
            var serving=Task.Run(async()=>{
                while(!cancel.IsCancellationRequested) {
                    TcpClient peer;try{peer=await origin.AcceptTcpClientAsync();}catch{break;}
                    using(peer)using(cancel.Token.Register(()=>peer.Close())) {
                        var stream=peer.GetStream();var request=new StringBuilder();var b=new byte[1];
                        while(!request.ToString().EndsWith("\r\n\r\n")){if(await stream.ReadAsync(b,0,1,cancel.Token)==0)break;request.Append((char)b[0]);}
                        hits++;var body=Encoding.UTF8.GetBytes("connected subscription");
                        var response=Encoding.ASCII.GetBytes("HTTP/1.1 200 OK\r\nProfile-Title: Connected fixture\r\nContent-Length: "+body.Length+"\r\nConnection: close\r\n\r\n");
                        await stream.WriteAsync(response,0,response.Length);await stream.WriteAsync(body,0,body.Length);
                    }
                }
            });
            try {
                for(int lane=0;lane<2;lane++) {
                    int direct=FreePort(),routed=FreePort();
                    var profile=new Dictionary<string,object>{{"protocol","vless"},{"host","127.0.0.1"},{"port",9},{"uuid","00000000-0000-4000-8000-000000000001"}};
                    var config=(Dictionary<string,object>)assembly.GetType("Vyrax.Config").GetMethod("Xray").Invoke(null,new object[]{profile,FreePort(),FreePort(),FreePort(),null,routed,0,null,null,direct});
                    var outbound=new Dictionary<string,object>{{"tag",lane==0?"direct":"proxy"},{"protocol","freedom"},{"settings",new Dictionary<string,object>{{"redirect","127.0.0.1:"+((IPEndPoint)origin.LocalEndpoint).Port}}}};
                    config["outbounds"]=new List<object>{outbound,new Dictionary<string,object>{{"tag",lane==0?"proxy":"direct"},{"protocol","blackhole"}}};
                    var file=Path.Combine(folder,"fixture.json");File.WriteAllText(file,(string)assembly.GetType("Vyrax.Json").GetMethod("Write").Invoke(null,new object[]{config}));
                    child=Process.Start(new ProcessStartInfo(core,"run -config \""+file+"\""){UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true});
                    for(int i=0;i<50;i++){using(var socket=new TcpClient()){try{await socket.ConnectAsync("127.0.0.1",direct);break;}catch{}}await Task.Delay(30);}
                    engineType.GetField("connected",BindingFlags.Instance|BindingFlags.NonPublic).SetValue(engine,true);
                    engineType.GetField("subscriptionPort",BindingFlags.Instance|BindingFlags.NonPublic).SetValue(engine,direct);
                    engineType.GetField("healthPort",BindingFlags.Instance|BindingFlags.NonPublic).SetValue(engine,routed);
                    var data=(Dictionary<string,object>)await (Task<object>)engineType.GetMethod("FetchSubscription").Invoke(engine,new object[]{"http://subscription.fixture/test"});
                    if(Convert.ToString(data["title"])!="Connected fixture"||hits!=lane+1)throw new Exception("connected subscription lane failed");
                    child.Kill();child.WaitForExit();child.Dispose();child=null;
                }
                Console.WriteLine("PASS: connected subscription uses uplink and falls back through core, without OS route/proxy changes");
            } finally {
                if(child!=null){if(!child.HasExited)child.Kill();child.Dispose();}
                engineType.GetField("connected",BindingFlags.Instance|BindingFlags.NonPublic).SetValue(engine,false);((IDisposable)engine).Dispose();
                cancel.Cancel();origin.Stop();serving.GetAwaiter().GetResult();Directory.Delete(folder,true);
            }
        }
    }
    static async Task Reuse(MethodInfo fetch) {
        var listener=new TcpListener(IPAddress.Loopback,0);listener.Start();
        try {
            using(var timeout=new CancellationTokenSource(7000)) {
                var port=((IPEndPoint)listener.LocalEndpoint).Port;
                var serve=Task.Run(async()=>{
                    using(var peer=await listener.AcceptTcpClientAsync())
                    using(timeout.Token.Register(()=>peer.Close())) {
                        var stream=peer.GetStream();
                        for(int i=0;i<2;i++) {
                            var request=new StringBuilder();var b=new byte[1];
                            while(!request.ToString().EndsWith("\r\n\r\n")) {if(request.Length>8192||await stream.ReadAsync(b,0,1,timeout.Token)==0)throw new Exception("transport was not reused");request.Append((char)b[0]);}
                            var body=Encoding.UTF8.GetBytes("fresh-response-"+i);
                            var header=Encoding.ASCII.GetBytes("HTTP/1.1 200 OK\r\nContent-Length: "+body.Length+"\r\nConnection: keep-alive\r\n\r\n");
                            await stream.WriteAsync(header,0,header.Length,timeout.Token);await stream.WriteAsync(body,0,body.Length,timeout.Token);
                        }
                    }
                });
                for(int i=0;i<2;i++) {
                    var result=(Dictionary<string,object>)await (Task<object>)fetch.Invoke(null,new object[]{"http://127.0.0.1:"+port+"/subscription"});
                    if(Convert.ToString(result["text"])!="fresh-response-"+i)throw new Exception("refresh returned stale cached contents");
                }
                await serve;
                Console.WriteLine("PASS: two refreshes reuse one transport connection and receive fresh response contents");
            }
        } finally {listener.Stop();}
    }
    static async Task Response(MethodInfo fetch,string headers,string key,string expected,bool compressed=false) {
        var listener=new TcpListener(IPAddress.Loopback,0);listener.Start();
        try {
            var endpoint=(IPEndPoint)listener.LocalEndpoint;
            using(var timeout=new CancellationTokenSource(7000)) {
                var body="#profile-title: کاربر اصلی\nvless://fixture";
                var bytes=Encoding.UTF8.GetBytes(body);
                if(compressed) {
                    using(var output=new MemoryStream()) {
                        using(var gzip=new GZipStream(output,CompressionMode.Compress,true))gzip.Write(bytes,0,bytes.Length);
                        bytes=output.ToArray();
                    }
                    headers+="Content-Encoding: gzip\r\n";
                }
                var serve=Task.Run(async()=>{
                    using(var client=await listener.AcceptTcpClientAsync())
                    using(timeout.Token.Register(()=>client.Close())) {
                        var stream=client.GetStream();var request=new StringBuilder();var b=new byte[1];
                        while(!request.ToString().EndsWith("\r\n\r\n")) {if(request.Length>8192||await stream.ReadAsync(b,0,1,timeout.Token)==0)throw new Exception("invalid request");request.Append((char)b[0]);}
                        var head=Encoding.ASCII.GetBytes("HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\n"+headers+"Content-Length: "+bytes.Length+"\r\nConnection: close\r\n\r\n");
                        await stream.WriteAsync(head,0,head.Length,timeout.Token);await stream.WriteAsync(bytes,0,bytes.Length,timeout.Token);
                    }
                });
                var result=(Dictionary<string,object>)await (Task<object>)fetch.Invoke(null,new object[]{"http://127.0.0.1:"+endpoint.Port+"/subscription"});
                await serve;
                if(Convert.ToString(result[key])!=expected||Convert.ToString(result["text"])!=body)throw new Exception("subscription response lost "+key+" or UTF-8 text");
                Console.WriteLine("PASS: native fetch preserves "+key+" and UTF-8 text"+(compressed?" from a compressed provider response":""));
            }
        } finally {listener.Stop();}
    }
}
