// Read-only user-store diagnostics. Starts an isolated local Xray; no TUN,
// system proxy, saved preferences or installed process is changed.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using Vyrax;

public static class EndpointDiagnostics {
    public static int Main(string[] args) {try{Run(args[0],args[1],args.Length>2&&args[2]=="uplink").GetAwaiter().GetResult();return 0;}catch(Exception e){Console.WriteLine("Diagnostics failed: "+e.GetType().Name);return 1;}}
    static async Task Run(string core,string root,bool bindUplink) {
        var path=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Vyrax","profiles.bin");
        var saved=Json.Read(Encoding.UTF8.GetString(ProtectedData.Unprotect(File.ReadAllBytes(path),null,DataProtectionScope.CurrentUser)));
        var profiles=Json.Items(saved["profiles"]).OfType<Dictionary<string,object>>().ToArray();
        var selected=profiles.First(p=>Json.Str(p,"id")==Json.Str(saved,"selectedId"));
        var settings=(Dictionary<string,object>)saved["settings"];
        var folder=Path.GetFullPath(Path.Combine(root,"run-"+Guid.NewGuid().ToString("N")));
        if(!folder.StartsWith(Path.GetFullPath(root)+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase))throw new Exception();
        Directory.CreateDirectory(folder);Store.Restrict(folder);Process process=null;
        try {
            var uplink=bindUplink?NetworkUplink.Capture():null;
            Console.WriteLine(Json.Write(Json.Obj("transport",bindUplink?"bound-uplink":"system-default","time",DateTime.UtcNow.ToString("u"))));
            int probe=Cores.FreePort();
            var config=(Dictionary<string,object>)Config.Xray(selected,Cores.FreePort(),Cores.FreePort(),Cores.FreePort(),settings,probe,0,uplink==null?null:uplink.Name,uplink==null?null:uplink.Dns);
            config["log"]=Json.Obj("loglevel","debug");
            var diagnosticLines=new List<string>();
            var dnsAnswers=0;var dnsFailures=0;var dialFailures=0;var resolved=0;
            var pool=new RoutingPool(config,core,folder,Cores.FreePort());
            pool.Build(config,profiles,Json.Str(selected,"id"),Json.Str(saved,"selectionMode","manual"),Json.Str(saved,"activeSourceId"));
            var file=Path.Combine(folder,"xray.json");File.WriteAllText(file,Json.Write(config),new UTF8Encoding(false));
            Cores.Check(core,"run -test -config \""+file+"\"");process=Cores.StartCore(core,"run -config \""+file+"\"",null,line=>{
                if(line.Contains("app/dns:")||line.Contains("failed to dial")||line.Contains("dialing TCP")||line.Contains("failed to lookup")||line.Contains("replace destination")||line.Contains("failed to resolve ip")) {
                    // No provider hostname, address, token or credential is printed.
                    var safe=Regex.Replace(line,@"[0-9a-fA-F]{8}-[0-9a-fA-F-]{27,}","[id]");
                    safe=Regex.Replace(safe,@"\[[0-9a-fA-F:]+\](?::\d+)?","[address]");
                    safe=Regex.Replace(safe,@"(?:[a-zA-Z0-9_-]+\.)+[a-zA-Z0-9_-]+(?::\d+)?","[address]");
                    lock(diagnosticLines){
                        if(line.Contains("got answer"))dnsAnswers++;
                        if(line.Contains("failed to lookup")||line.Contains("failed to query"))dnsFailures++;
                        if(line.Contains("failed to dial"))dialFailures++;
                        if(line.Contains("replace destination"))resolved++;
                        diagnosticLines.Add(safe);if(diagnosticLines.Count>60)diagnosticLines.RemoveAt(0);
                    }
                }
            });
            using(var timeout=new CancellationTokenSource(6000))await Cores.WaitPort(process,probe,timeout.Token);
            var checks=new List<Task>();
            foreach(var url in new[]{"https://www.gstatic.com/generate_204","https://cp.cloudflare.com/generate_204","https://www.msftconnecttest.com/connecttest.txt","https://captive.apple.com/hotspot-detect.html"}) {
                var target=url;
                checks.Add(Report(new Uri(target).Host,async()=>{
                    using(var handler=new HttpClientHandler{UseProxy=true,Proxy=new WebProxy("http://127.0.0.1:"+probe),AllowAutoRedirect=false,SslProtocols=SslProtocols.Tls12})
                    using(var client=new HttpClient(handler){Timeout=TimeSpan.FromSeconds(8)})
                    using(var response=await client.GetAsync(target,HttpCompletionOption.ResponseHeadersRead)) {
                        if(response.StatusCode!=HttpStatusCode.OK&&response.StatusCode!=HttpStatusCode.NoContent)throw new Exception();
                    }
                }));
            }
            foreach(var pair in new[]{new[]{"1.1.1.1","cloudflare-dns.com"},new[]{"8.8.8.8","dns.google"},new[]{"9.9.9.9","dns.quad9.net"}}) {
                var target=pair;
                checks.Add(Report(target[1]+" (fixed IP)",async()=>{
                    using(var timeout=new CancellationTokenSource(8000))
                    using(var peer=new TcpClient())
                    using(timeout.Token.Register(()=>peer.Close())) {
                        await peer.ConnectAsync(IPAddress.Loopback,probe);
                        var stream=peer.GetStream();var request=Encoding.ASCII.GetBytes("CONNECT "+target[0]+":443 HTTP/1.1\r\nHost: "+target[0]+":443\r\n\r\n");
                        await stream.WriteAsync(request,0,request.Length,timeout.Token);
                        var header=new StringBuilder();var b=new byte[1];
                        while(!header.ToString().EndsWith("\r\n\r\n")){if(header.Length>8192||await stream.ReadAsync(b,0,1,timeout.Token)==0)throw new IOException();header.Append((char)b[0]);}
                        if(!header.ToString().StartsWith("HTTP/1.1 200"))throw new IOException();
                        using(var ssl=new SslStream(stream,false))await ssl.AuthenticateAsClientAsync(target[1],null,SslProtocols.Tls12,false);
                    }
                }));
            }
            await Task.WhenAll(checks);
            lock(diagnosticLines){Console.WriteLine(Json.Write(Json.Obj("dnsAnswerLogCount",dnsAnswers,"dnsFailureLogCount",dnsFailures,"dialFailureLogCount",dialFailures,"resolvedDestinationCount",resolved)));foreach(var line in diagnosticLines.Skip(Math.Max(0,diagnosticLines.Count-15)))Console.WriteLine(line);}
        } finally {if(process!=null){if(!process.HasExited){process.Kill();process.WaitForExit(2000);}process.Dispose();}Directory.Delete(folder,true);}
    }
    static async Task Report(string label,Func<Task> check) {
        var watch=Stopwatch.StartNew();bool healthy=false;string error="";
        try{await check();healthy=true;}catch(Exception e){error=e.GetType().Name;}
        Console.WriteLine(Json.Write(Json.Obj("target",label,"verified",healthy,"milliseconds",watch.ElapsedMilliseconds,"errorType",error)));
    }
}
