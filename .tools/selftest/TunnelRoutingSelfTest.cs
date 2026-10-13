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

// Exercise the real sing-box routing engine under each Windows process name.
// Loopback SOCKS listeners stand in for both outbounds: no VPN or internet needed.
public static class TunnelRoutingSelfTest {
    public static int Main(string[] args) {
        try { Run(args[0],args[1]).GetAwaiter().GetResult();return 0; }
        catch(Exception e) { Console.WriteLine("FAIL: "+e.Message);return 1; }
    }

    static async Task Run(string core,string expected) {
        var folder=Path.Combine(Path.GetTempPath(),"vyrax-routing-"+Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(folder);
        var proxy=new TcpListener(IPAddress.Loopback,0);
        var direct=new TcpListener(IPAddress.Loopback,0);
        Process process=null;
        var output=new StringBuilder();
        try {
            proxy.Start();direct.Start();
            var proxyPort=((IPEndPoint)proxy.LocalEndpoint).Port;
            var directPort=((IPEndPoint)direct.LocalEndpoint).Port;
            var inboundPort=Cores.FreePort();
            var config=(Dictionary<string,object>)Config.Tun(proxyPort,1280);
            var file=Path.Combine(folder,"tun.json");
            File.WriteAllText(file,Json.Write(config));
            Cores.Check(core,"check -c \""+file+"\"");

            config["inbounds"]=new[]{Json.Obj("type","mixed","tag","tun-in","listen","127.0.0.1","listen_port",inboundPort)};
            config["outbounds"]=new[]{
                Json.Obj("type","socks","tag","proxy","server","127.0.0.1","server_port",proxyPort,"version","5"),
                Json.Obj("type","socks","tag","direct","server","127.0.0.1","server_port",directPort,"version","5")};
            File.WriteAllText(file,Json.Write(config));
            process=Cores.StartCore(core,"run -c \""+file+"\"",null,line=>{lock(output)output.AppendLine(line);});
            using(var timeout=new CancellationTokenSource(5000))await Cores.WaitPort(process,inboundPort,timeout.Token);

            var proxied=proxy.AcceptTcpClientAsync();
            var bypassed=direct.AcceptTcpClientAsync();
            using(var client=new TcpClient()) {
                await client.ConnectAsync(IPAddress.Loopback,inboundPort);
                var request=Encoding.ASCII.GetBytes("CONNECT 203.0.113.10:443 HTTP/1.1\r\nHost: 203.0.113.10:443\r\n\r\n");
                await client.GetStream().WriteAsync(request,0,request.Length);
                var winner=await Task.WhenAny(proxied,bypassed,Task.Delay(5000));
                var actual=winner==proxied?"proxy":winner==bypassed?"direct":"timeout";
                if(winner==proxied)proxied.Result.Dispose();
                if(winner==bypassed)bypassed.Result.Dispose();
                if(actual!=expected) {
                    lock(output)Console.WriteLine(output.ToString());
                    throw new Exception(Path.GetFileName(Process.GetCurrentProcess().MainModule.FileName)+" used "+actual+"; expected "+expected);
                }
                Console.WriteLine("PASS: "+Path.GetFileName(Process.GetCurrentProcess().MainModule.FileName)+" -> "+actual);
            }
        } finally {
            if(process!=null){if(!process.HasExited){process.Kill();process.WaitForExit();}process.Dispose();}
            proxy.Stop();direct.Stop();
            Directory.Delete(folder,true);
        }
    }
}
