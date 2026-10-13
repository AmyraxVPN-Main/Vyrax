using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Net.Security;
using System.Security.Authentication;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Vyrax;

public static class SettingsSelfTest {
    static int checks;
    static void Assert(bool ok,string name) {if(!ok)throw new Exception(name);checks++;Console.WriteLine("PASS: "+name);}
    static Dictionary<string,object> Profile() {return Json.Obj("id","test-a","protocol","vless","host","127.0.0.1","port",443,"uuid","00000000-0000-4000-8000-000000000001");}
    public static int Main(string[] args) {try {Run(args[0],args[1]).GetAwaiter().GetResult();Console.WriteLine(checks+" settings checks passed");return 0;}catch(Exception e){Console.WriteLine(e);return 1;}}
    static async Task Run(string xray,string sing) {
        var migrated=Preferences.Normalize(Json.Obj("autoConnect",true,"autoReconnect",true));
        Assert(!Json.Bool(migrated,"autoConnect")&&!Json.Bool(migrated,"autoReconnect"),"legacy disabled defaults stay off");
        var normalized=Preferences.Addresses(Json.Obj("list","*.Example.com\nexample.com\n203.0.113.0/24\n2001:db8::/32"),"list");
        Assert(normalized.Length==3&&normalized[0]=="example.com","domain/IP/CIDR parsing and deduplication");
        foreach(var text in new[]{"https://example.com/path","203.0.113.0/33","bad_domain.com","user@example.com"}) {
            var rejected=false;try{Preferences.Addresses(Json.Obj("list",text),"list");}catch{rejected=true;}
            Assert(rejected,"reject invalid rule "+text);
        }
        var settings=Json.Obj("preferencesVersion",1,"autoConnect",true,"autoReconnect",true);
        var fake=new FakeEngine();var clock=DateTime.UtcNow;var session=new ConnectionSession(fake,()=>clock);
        var second=Profile();second["id"]="test-b";
        var saved=Json.Read(Json.Write(Json.Obj("profiles",new object[]{Profile(),second},"selectedId","test-b","settings",settings,"selectionMode","fastest","activeSourceId","one")));
        await session.Start(saved);await session.Start(saved);
        Assert(fake.Connects==1&&fake.LastId=="test-b","autoconnect restores chosen server exactly once");
        Assert(Json.Items(fake.LastOptions["_catalog"]).Length==2&&Json.Str(fake.LastOptions,"_selection")=="fastest"&&Json.Str(fake.LastOptions,"_source")=="one","autoconnect restores decoded catalog and automatic scope");
        await session.Select(new[]{Profile(),second},"test-b","manual","one");
        session.Update(settings);
        fake.Drop=true;await session.Poll();
        Assert(Json.Str((Dictionary<string,object>)session.Snapshot(),"status")=="connecting","unexpected drop schedules reconnect");
        clock=clock.AddSeconds(3);await session.Poll();
        Assert(fake.Connects==2,"reconnect after backoff");
        Assert(fake.LastId=="test-b"&&Json.Str(fake.LastOptions,"_selection")=="manual"&&Json.Str(fake.LastOptions,"_source")=="one","manual selection remains pinned through settings save and reconnect");
        await session.Disconnect();clock=clock.AddMinutes(1);await session.Poll();
        Assert(fake.Connects==2,"manual disconnect prevents reconnect");
        fake.Fail=true;await session.Connect(Profile(),settings);clock=clock.AddSeconds(3);await session.Poll();
        Assert(fake.Connects==4,"failed attempt retries");
        session.Update(Json.Obj("preferencesVersion",1,"autoReconnect",false));clock=clock.AddMinutes(1);await session.Poll();
        Assert(fake.Connects==4&&Json.Str((Dictionary<string,object>)session.Snapshot(),"status")=="disconnected","turning retry off cancels pending attempt");
        fake.Fail=false;fake.Pending=new TaskCompletionSource<object>();
        var pending=session.Connect(Profile(),settings);await session.Disconnect();fake.Pending.SetResult(fake.Snapshot());await pending;
        clock=clock.AddMinutes(1);await session.Poll();Assert(fake.Connects==5,"cancel in-flight connect does not retry");
        var storeDir=Path.Combine(Path.GetTempPath(),"vyrax-preferences-"+Guid.NewGuid().ToString("N"));
        try {var store=new Store(storeDir);store.Save(saved);var reloaded=store.Load();Assert(Json.Bool((Dictionary<string,object>)reloaded["settings"],"autoConnect"),"settings persist through encrypted store");}
        finally {Directory.Delete(storeDir,true);}
        foreach(var mode in new[]{"split","bypass","off"}) {
            foreach(var chain in new[]{false,true})await Routing(xray,sing,mode,chain);
        }
    }
    sealed class FakeEngine : IConnectionEngine, ISelectionEngine {
        public event Action<object> Changed;
        public int Connects;public string LastId;public Dictionary<string,object> LastOptions;public bool Drop,Fail,On;public TaskCompletionSource<object> Pending;
        public object Snapshot(){return Json.Obj("status",On?"connected":"disconnected");}
        public async Task<object> Connect(Dictionary<string,object> profile,string mode,int mtu,Dictionary<string,object> options){Connects++;LastId=Json.Str(profile,"id");LastOptions=new Dictionary<string,object>(options);if(Pending!=null)return await Pending.Task;if(Fail)throw new Exception("err.verify");On=true;return Snapshot();}
        public Task<object> Select(Dictionary<string,object>[] profiles,string selected,string mode,string source){return Task.FromResult<object>(Json.Obj("status","connected","profileId",selected));}
        public Task<object> Disconnect(){On=false;if(Changed!=null)Changed(Json.Obj("event","state","status","disconnected"));return Task.FromResult(Snapshot());}
        public async Task Poll(){if(Drop){Drop=false;await Disconnect();}}
    }
    static async Task Routing(string xray,string sing,string mode,bool chain) {
        var folder=Path.Combine(Path.GetTempPath(),"vyrax-preference-routing-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(folder);
        var proxy=new TcpListener(IPAddress.Loopback,0);var direct=new TcpListener(IPAddress.Loopback,0);
        Process process=null,tunnel=null;
        try {
            proxy.Start();direct.Start();
            int socks=Cores.FreePort(),http=Cores.FreePort(),metrics=Cores.FreePort(),probe=Cores.FreePort(),share=Cores.FreePort();
            var options=Json.Obj("splitTunneling",mode=="split","bypassSites",mode=="bypass","splitAddresses",new[]{"example.com","203.0.113.0/24","2001:db8::/32"},"bypassAddresses",new[]{"example.com","203.0.113.0/24","2001:db8::/32"});
            var config=(Dictionary<string,object>)Config.Xray(Profile(),socks,http,metrics,options,probe,share);
            var path=Path.Combine(folder,"xray.json");File.WriteAllText(path,Json.Write(config));Cores.Check(xray,"run -test -config \""+path+"\"");
            // Real Xray inbound/routing/sniffing, with local capture endpoints in
            // place of remote outbounds. No system proxy, firewall or TUN changes.
            config["outbounds"]=new[]{Socks("proxy",((IPEndPoint)proxy.LocalEndpoint).Port),Socks("direct",((IPEndPoint)direct.LocalEndpoint).Port)};
            File.WriteAllText(path,Json.Write(config));process=Cores.StartCore(xray,"run -config \""+path+"\"",null);
            using(var timeout=new CancellationTokenSource(5000))await Cores.WaitPort(process,http,timeout.Token);
            int inbound=http;
            if(chain) {
                inbound=Cores.FreePort();var tun=(Dictionary<string,object>)Config.Tun(socks,1280);
                tun["inbounds"]=new[]{Json.Obj("type","mixed","tag","tun-in","listen","127.0.0.1","listen_port",inbound)};
                var tf=Path.Combine(folder,"tun.json");File.WriteAllText(tf,Json.Write(tun));
                tunnel=Cores.StartCore(sing,"run -c \""+tf+"\"",null);
                using(var timeout=new CancellationTokenSource(5000))await Cores.WaitPort(tunnel,inbound,timeout.Token);
            }
            var label=mode+(chain?" via sing-box":" via HTTP");
            foreach(var target in new[]{"example.com","sub.example.com","203.0.113.8","[2001:db8::1]","unlisted.invalid","notexample.com"}) {
                bool listed=target!="unlisted.invalid"&&target!="notexample.com";
                string expected=mode=="split"?(listed?"proxy":"direct"):mode=="bypass"?(listed?"direct":"proxy"):"proxy";
                await Route(inbound,target,proxy,direct,expected,label);
            }
            await Route(probe,"unlisted.invalid",proxy,direct,"proxy",label+" health probe");
            await Route(share,"example.com",proxy,direct,mode=="bypass"?"direct":"proxy",label+" shared HTTP");
            await Sniff(inbound,proxy,direct,mode=="bypass"?"direct":"proxy",label);
        } finally {
            foreach(var child in new[]{tunnel,process})if(child!=null){if(!child.HasExited){child.Kill();child.WaitForExit();}child.Dispose();}
            proxy.Stop();direct.Stop();Directory.Delete(folder,true);
        }
    }
    static object Socks(string tag,int port){return Json.Obj("tag",tag,"protocol","socks","settings",Json.Obj("servers",new[]{Json.Obj("address","127.0.0.1","port",port)}));}
    static async Task Sniff(int port,TcpListener proxy,TcpListener direct,string expected,string label) {
        using(var client=new TcpClient())
        using(var timeout=new CancellationTokenSource(6000))
        using(timeout.Token.Register(()=>client.Close())) {
            await client.ConnectAsync(IPAddress.Loopback,port);
            var stream=client.GetStream();
            var bytes=Encoding.ASCII.GetBytes("CONNECT 203.0.114.10:443 HTTP/1.1\r\nHost: 203.0.114.10:443\r\n\r\n");await stream.WriteAsync(bytes,0,bytes.Length);
            var header=new StringBuilder();var single=new byte[1];
            while(header.Length<4096&&!header.ToString().EndsWith("\r\n\r\n")){if(await stream.ReadAsync(single,0,1)==0)throw new Exception("proxy closed before TLS");header.Append((char)single[0]);}
            using(var ssl=new SslStream(stream,false)) {
                var handshake=ssl.AuthenticateAsClientAsync("sub.example.com",null,SslProtocols.Tls12,false);
                var until=DateTime.UtcNow.AddSeconds(5);
                while(!proxy.Pending()&&!direct.Pending()&&DateTime.UtcNow<until)await Task.Delay(10);
                var actual=proxy.Pending()?"proxy":direct.Pending()?"direct":"timeout";
                if(proxy.Pending())proxy.AcceptTcpClient().Dispose();if(direct.Pending())direct.AcceptTcpClient().Dispose();
                client.Close();try{await handshake;}catch{ }
                Assert(actual==expected,label+" IP destination uses TLS domain -> "+expected+" (actual "+actual+")");
            }
        }
    }
    static async Task Route(int port,string target,TcpListener proxy,TcpListener direct,string expected,string label) {
        using(var client=new TcpClient()) {
            await client.ConnectAsync(IPAddress.Loopback,port);
            var bytes=Encoding.ASCII.GetBytes("CONNECT "+target+":443 HTTP/1.1\r\nHost: "+target+":443\r\n\r\n");await client.GetStream().WriteAsync(bytes,0,bytes.Length);
            var until=DateTime.UtcNow.AddSeconds(5);
            while(!proxy.Pending()&&!direct.Pending()&&DateTime.UtcNow<until)await Task.Delay(10);
            string actual=proxy.Pending()?"proxy":direct.Pending()?"direct":"timeout";
            if(proxy.Pending())proxy.AcceptTcpClient().Dispose();if(direct.Pending())direct.AcceptTcpClient().Dispose();
            Assert(actual==expected,label+" "+target+" -> "+expected+" (actual "+actual+")");
        }
    }
}
