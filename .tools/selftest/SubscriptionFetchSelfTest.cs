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

public static class SubscriptionFetchSelfTest {
    public static int Main(string[] args) {
        try {Run(args[0]).GetAwaiter().GetResult();return 0;}catch(Exception e){Console.WriteLine(e);return 1;}
    }
    static async Task Run(string host) {
        var method=Assembly.LoadFrom(host).GetType("Vyrax.Engine").GetMethod("Fetch");
        var title="base64:"+Convert.ToBase64String(Encoding.UTF8.GetBytes("کاربر اصلی"));
        await Response(method,"Profile-Title: "+title+"\r\nSubscription-Userinfo: upload=1;download=2;total=100\r\n","title",title);
        await Response(method,"Content-Disposition: attachment; filename*=UTF-8''Amyrax-100GB-V2.txt\r\n","disposition","attachment; filename*=UTF-8''Amyrax-100GB-V2.txt");
        await Response(method,"Profile-Title: base64:U3Vic2NyaXB0aW9u\r\nContent-Disposition: attachment; filename=\"Amyrax-100GB-V2\"\r\n","disposition","attachment; filename=\"Amyrax-100GB-V2\"",true);
        await Reuse(method);
        Console.WriteLine("Native subscription headers and UTF-8 body checks passed");
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
