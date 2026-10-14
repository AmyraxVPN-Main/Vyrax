using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.NetworkInformation;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Principal;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Vyrax {
/* موتور اتصال: Xray برای پروتکل، و در حالت VPN کامل sing-box برای رابط TUN. */
public sealed class Engine : IDisposable, IConnectionEngine, ISelectionEngine {
    readonly Store store;readonly ProxySettings proxy;readonly ChildJob job;readonly SemaphoreSlim gate=new SemaphoreSlim(1,1);
    readonly string coreRoot;Process xray,tun;CancellationTokenSource session;string configFolder;int metrics;bool connected;bool viaHelper;int tunCheckBusy;string profileId="";string exitIp="";DateTime since;long lastUp,lastDown;DateTime lastSample;
    readonly ProxyShare share=new ProxyShare();int healthPort,subscriptionPort,healthFailures;DateTime nextHealth;
    public IWebProxy ControlProxy {get{return connected&&subscriptionPort>0?new WebProxy("http://127.0.0.1:"+subscriptionPort):null;}}
    RoutingPool routingPool;DateTime nextSelection;string[] activeTargets=new string[0];
    public event Action<object> Changed;
    public static bool Elevated { get { return Cores.Elevated; } }
    public Engine(Store value,string cores) { store=value;coreRoot=cores;proxy=new ProxySettings(store.Root);job=new ChildJob(); }
    public object Snapshot() { return Json.Obj("status",connected?"connected":"disconnected","profileId",profileId,"since",connected?since.ToString("o"):null,"elevated",Elevated,"exit",connected?exitIp:null,"share",connected?share.Snapshot():null,"selectionMode",routingPool==null?"manual":routingPool.Mode,"activeTargets",activeTargets); }

    /* آدرس سروری که به آن وصل شده‌ایم. برای کانفیگ‌های تانل‌شده این همان آی‌پی
       نهایی نیست (شانهٔ اول تونل است) و به همین دلیل هم «سرور» نامیده می‌شود. */
    static async Task<string> Resolve(string host) {
        if(String.IsNullOrEmpty(host))return "";
        IPAddress parsed;
        if(IPAddress.TryParse(host,out parsed))return parsed.ToString();
        try {
            var task=Dns.GetHostAddressesAsync(host);
            if(await Task.WhenAny(task,Task.Delay(3000))!=task)return "";
            var all=await task;
            foreach(var a in all) if(a.AddressFamily==AddressFamily.InterNetwork) return a.ToString();
            foreach(var a in all) return a.ToString();
        } catch { }
        return "";
    }
    // The display address is optional metadata, never a connection prerequisite.
    void UpdateExit(string host) {
        IPAddress address;
        exitIp=IPAddress.TryParse(host,out address)?address.ToString():"";
        if(exitIp.Length==0)ResolveExit(host,session,profileId);
    }
    async void ResolveExit(string host,CancellationTokenSource owner,string selected) {
        try {
            var address=await Resolve(host);
            if(!String.IsNullOrEmpty(address)&&owner==session&&connected&&profileId==selected) {
                exitIp=address;Emit("connected","","",true);
            }
        } catch { }
    }
    void Emit(string status,string message="",string stage="",bool switched=false) { var value=(Dictionary<string,object>)Snapshot();value["event"]="state";value["status"]=status;value["message"]=message;value["stage"]=stage;value["switched"]=switched;if(Changed!=null)Changed(value); }
    /* FreePort / StartCore / Check / WaitPort به native/Cores.cs منتقل شدند تا
       VyraxHelper.exe بتواند فقط همان‌ها را کامپایل کند و این فایل را نکشد. */

    /* نامِ رابطِ TUN دستِ ما نیست: همان است که Json.Config.Tun می‌سازد. */
    const string TunName="Vyrax";

    /* خطوطِ خروجیِ هسته (خصوصاً stderr) اینجا جمع می‌شوند تا اگر تونل بالا نیامد
       دلیلش را داشته باشیم. سرِ لیست مهم است — ساختِ رابط و تصمیمِ مسیرها آنجا
       نوشته می‌شود — و دُمِ آن هم (خطاهای آخر). اگر فقط دُم را نگه داریم سرنخِ
       اصلی را از دست می‌دهیم، پس هر دو نگه داشته می‌شوند. */
    readonly object coreLock=new object();
    readonly List<string> coreHead=new List<string>(),coreTail=new List<string>(),coreErrors=new List<string>();
    int coreLines;
    void LogLine(string line){
        lock(coreLock){
            coreLines++;
            if(coreHead.Count<150)coreHead.Add(line);
            else { coreTail.Add(line); if(coreTail.Count>50)coreTail.RemoveAt(0); }
            // Busy DNS/connection messages must not evict the actual core error.
            if(line.IndexOf("ERROR",StringComparison.OrdinalIgnoreCase)>=0||line.IndexOf("WARN",StringComparison.OrdinalIgnoreCase)>=0) {
                coreErrors.Add(line);if(coreErrors.Count>80)coreErrors.RemoveAt(0);
            }
        }
    }


    public async Task<object> Connect(Dictionary<string,object> profile,string mode,int mtu,Dictionary<string,object> settings=null) {
        Config.Validate(profile);
        Preferences.Validate(settings);
        if(mode!="proxy"&&mode!="tun")throw new Exception("err.mode");
        /* TUN دیگر به مدیر بودنِ خودمان مشروط نیست: اگر مدیر نباشیم، هلپرِ ممتاز
           هسته را بالا می‌آورد. ردکردنِ پنجرهٔ UAC به‌صورت err.adminDeclined برمی‌گردد. */
        await gate.WaitAsync();
        CancellationTokenSource deadline=null,linked=null;
        try {
            StopInner();
            lock(coreLock){ coreHead.Clear();coreTail.Clear();coreErrors.Clear();coreLines=0; }
            if(session!=null)session.Dispose();
            session=new CancellationTokenSource();
            /* هیچ اتصالی نباید بی‌پایان بماند: یک مهلت کلی روی کل کار می‌گذاریم
               تا رابط کاربری هیچ‌وقت روی «در حال اتصال» گیر نکند. */
            deadline=new CancellationTokenSource(TimeSpan.FromSeconds(35));
            linked=CancellationTokenSource.CreateLinkedTokenSource(session.Token,deadline.Token);
            var token=linked.Token;

            profileId=Json.Str(profile,"id");
            Emit("connecting","","stage.start");

            var uplink=mode=="tun"?NetworkUplink.Capture():null;
            if(uplink!=null)LogLine("transport uplink: "+uplink.Name+"; bootstrap DNS: "+String.Join(", ",uplink.Dns));

            configFolder=Path.Combine(store.Root,"runtime-"+Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(configFolder);Store.Restrict(configFolder);
            int socks=Cores.FreePort(),http=Cores.FreePort();metrics=Cores.FreePort();
            healthPort=Cores.FreePort();subscriptionPort=Cores.FreePort();healthFailures=0;
            var sharePort=Json.Bool(settings,"proxyShare")?Cores.FreePort():0;
            var file=Path.Combine(configFolder,"xray.json");
            var config=(Dictionary<string,object>)Config.Xray(profile,socks,http,metrics,settings,healthPort,sharePort,uplink==null?null:uplink.Name,uplink==null?null:uplink.Dns,subscriptionPort);
            object catalog;
            if(settings!=null&&settings.TryGetValue("_catalog",out catalog)) {
                routingPool=new RoutingPool(config,Path.Combine(coreRoot,"xray.exe"),configFolder,Cores.FreePort());
                routingPool.Build(config,RoutingPool.Catalog(settings,profile),profileId,Json.Str(settings,"_selection","manual"),Json.Str(settings,"_source"));
                activeTargets=new[]{profileId};nextSelection=DateTime.UtcNow.AddSeconds(3);
            }
            File.WriteAllText(file,Json.Write(config),new UTF8Encoding(false));

            Emit("connecting","","stage.core");
            var exe=Path.Combine(coreRoot,"xray.exe");
            await Task.Run(()=>Cores.Check(exe,"run -test -config \""+file+"\""));token.ThrowIfCancellationRequested();
            if(sharePort>0)share.Enable(exe,sharePort);

            Emit("connecting","","stage.handshake");
            xray=Cores.StartCore(exe,"run -config \""+file+"\"",job,line=>LogLine("xray: "+line));
            await Cores.WaitPort(xray,http,token);

            Emit("connecting","","stage.verify");
            await VerifyProxy(healthPort,token);

            if(mode=="tun") {
                if(Elevated) {
                    /* خودمان با دسترسی مدیر اجرا شده‌ایم؛ همان مسیر درون‌برنامه‌ای */
                    Emit("connecting","","stage.tunnel");
                    var tf=Path.Combine(configFolder,"tun.json");
                    File.WriteAllText(tf,Json.Write(Config.Tun(socks,mtu)),new UTF8Encoding(false));
                    var te=Path.Combine(coreRoot,"sing-box.exe");
                    await Task.Run(()=>Cores.Check(te,"check -c \""+tf+"\""));token.ThrowIfCancellationRequested();
                    tun=Cores.StartCore(te,"run -c \""+tf+"\"",job,LogLine);
                } else {
                    /* رابط بی‌دسترسی می‌ماند (توصیهٔ خودِ مایکروسافت برای WebView2)؛
                       فقط هستهٔ TUN را هلپرِ ممتاز بالا می‌آورد و برای اتصال‌های
                       بعدی مقیم می‌ماند، پس در هر اجرا حداکثر یک UAC می‌بینیم.

                       مهلتِ ۳۵ ثانیه‌ایِ بالا برای «بالا آمدنِ هسته» است، نه برای
                       فکر کردنِ کاربر پشتِ پنجرهٔ UAC — پس اینجا تازه‌اش می‌کنیم. */
                    Emit("connecting","","stage.admin");
                    deadline.Dispose();linked.Dispose();
                    deadline=new CancellationTokenSource(TimeSpan.FromSeconds(180));
                    linked=CancellationTokenSource.CreateLinkedTokenSource(session.Token,deadline.Token);
                    token=linked.Token;
                    viaHelper=true;
                    await Task.Run(()=>HelperClient.StartTun(socks,mtu));
                    token.ThrowIfCancellationRequested();
                }
                /* تا اینجا فقط می‌دانیم «هسته بالا آمد». «متصل» یعنی رابطِ TUN واقعاً
                   ساخته شده باشد و از داخلِ همان رابط ترافیک رد شده باشد؛ وگرنه
                   همان «وصل است ولی کار نمی‌کند» می‌شود که دیدی.

                   مهلتِ این مرحله را جدا می‌کنیم: ساختِ رابط و تستِ عبورِ ترافیک
                   به مهلتِ ۳۵ ثانیه‌ایِ بالا آمدنِ هسته اضافه می‌شود، وگرنه نتیجه
                   «اتصال طول کشید» می‌شد نه «تونل بالا نیامد». */
                Emit("connecting","","stage.tunnel");
                linked.Dispose();deadline.Dispose();
                deadline=new CancellationTokenSource(TimeSpan.FromSeconds(90));
                linked=CancellationTokenSource.CreateLinkedTokenSource(session.Token,deadline.Token);
                token=linked.Token;
                await WaitTun(token);
                await ProbeTun(token);
                WriteTunnelLog("ok");
            } else {
                Emit("connecting","","stage.proxy");
                token.ThrowIfCancellationRequested();
                proxy.Enable(http);
            }
            connected=true;since=DateTime.UtcNow;lastUp=lastDown=0;lastSample=since;nextHealth=since.AddSeconds(30);
            UpdateExit(Json.Str(profile,"host"));
            token.ThrowIfCancellationRequested();
            Emit("connected");return Snapshot();
        } catch(OperationCanceledException) {
            var byUser=session!=null&&session.IsCancellationRequested;
            if(mode=="tun")WriteTunnelLog(byUser?"cancelled":"timeout");
            StopInner();
            if(byUser){ Emit("disconnected");return Snapshot(); }
            Emit("disconnected","err.timeout");
            throw new Exception("err.timeout");
        }
        catch(Exception e) {
            if(mode=="tun"){LogLine("connect failed: "+e.GetBaseException().Message);WriteTunnelLog("failed");}
            StopInner();Emit("disconnected");throw;
        }
        finally { if(linked!=null)linked.Dispose(); if(deadline!=null)deadline.Dispose(); gate.Release(); }
    }

    /* --- اثباتِ واقعیِ تونل -------------------------------------------------
       نسخهٔ قبلی بعد از بالا آوردنِ sing-box فقط ۱٫۴ ثانیه صبر می‌کرد و اگر پروسه
       نمی‌مرد، اتصال را موفق اعلام می‌کرد. یعنی اگر sing-box زنده می‌ماند ولی
       رابطِ TUN بالا نمی‌آمد، یا مسیرها و DNS کار نمی‌کردند، رابط «محافظت‌شده»
       نشان می‌داد و هیچ ترافیکی رد نمی‌شد — دقیقاً «وصل است ولی کار نمی‌کند».

       حالا دو چیز جدا بررسی می‌شود:
         ۱) رابطِ Vyrax واقعاً ساخته شده و آدرس IPv4 گرفته باشد.
         ۲) از همان آدرس، یک دست‌دادنِ TLS به بیرون برقرار شود. سوکت به آدرسِ
            محلیِ تونل بسته می‌شود تا درخواست وارد رابط TUN شود.
       چند سرویس مستقل با نام TLS درست امتحان می‌شوند. ترافیکِ خودِ Vyrax هم
       باید به خروجی proxy برود؛ bind به آدرس TUN به‌تنهایی این را تضمین نمی‌کند. */

    static IPAddress TunAddress() {
        try {
            foreach(var ni in NetworkInterface.GetAllNetworkInterfaces()) {
                if(ni.OperationalStatus!=OperationalStatus.Up)continue;
                if(ni.Name!=TunName&&ni.Description!=TunName)continue;
                foreach(var ua in ni.GetIPProperties().UnicastAddresses)
                    if(ua.Address.AddressFamily==AddressFamily.InterNetwork&&!IPAddress.IsLoopback(ua.Address))return ua.Address;
            }
        } catch { }
        return null;
    }

    async Task WaitTun(CancellationToken token) {
        for(int i=0;i<150;i++) {                        /* ۱۵ ثانیه */
            token.ThrowIfCancellationRequested();
            if(tun!=null&&tun.HasExited)throw FailTunnel();
            if(TunAddress()!=null)return;
            await Task.Delay(100,token);
        }
        throw FailTunnel();
    }

    async Task ProbeTun(CancellationToken token) {
        var local=TunAddress();
        if(local==null)throw FailTunnel();
        if(tun!=null&&tun.HasExited)throw FailTunnel();
        var targets=new[]{new[]{"1.1.1.1","cloudflare-dns.com"},new[]{"8.8.8.8","dns.google"},new[]{"9.9.9.9","dns.quad9.net"}};
        var checks=targets.Select(target=>new Func<CancellationToken,Task>(async stop=>{
            try {await ProbeTls(local,new IPEndPoint(IPAddress.Parse(target[0]),443),target[1],stop);}
            catch(OperationCanceledException){throw;}
            catch(Exception e){LogLine("probe "+target[0]+" ("+target[1]+"): "+e.GetBaseException().Message);throw;}
        })).ToArray();
        var winner=await FirstHealthy(checks,token);
        if(winner<0)throw FailTunnel(true);
        LogLine("probe "+targets[winner][0]+" ("+targets[winner][1]+") via "+local+": TLS verified");
    }

    // Race independent checks; close and await losing probes before returning.
    // A blocked first target must not delay a healthy second target.
    internal static async Task<int> FirstHealthy(Func<CancellationToken,Task>[] checks,CancellationToken token) {
        token.ThrowIfCancellationRequested();
        using(var stop=CancellationTokenSource.CreateLinkedTokenSource(token)) {
            var tasks=checks.Select((check,index)=>TryHealth(check,index,stop.Token)).ToArray();
            var pending=tasks.ToList();
            int winner=-1;
            try {
                while(pending.Count>0&&!token.IsCancellationRequested) {
                    var done=await Task.WhenAny(pending);pending.Remove(done);
                    var result=await done;
                    if(result>=0){winner=result;break;}
                }
            } finally {stop.Cancel();}
            await Task.WhenAll(tasks);
            token.ThrowIfCancellationRequested();return winner;
        }
    }
    static async Task<int> TryHealth(Func<CancellationToken,Task> check,int index,CancellationToken token) {
        try {await check(token);return index;}catch{return -1;}
    }

    // Close the socket on timeout/cancellation and await the operation so no
    // abandoned connect/TLS tasks can write into a later connection's log.
    internal static async Task ProbeTls(IPAddress local,IPEndPoint target,string host,CancellationToken token,int timeoutMs=12000) {
        token.ThrowIfCancellationRequested();
        using(var socket=new Socket(AddressFamily.InterNetwork,SocketType.Stream,ProtocolType.Tcp))
        using(var deadline=CancellationTokenSource.CreateLinkedTokenSource(token)) {
            socket.Bind(new IPEndPoint(local,0));
            deadline.CancelAfter(timeoutMs);
            var stage="TCP connect";
            using(deadline.Token.Register(()=>socket.Dispose())) {
                try {
                    await socket.ConnectAsync(target);
                    stage="TLS handshake";
                    using(var ssl=new SslStream(new NetworkStream(socket,false),false)) {
                        // This host targets .NET Framework: the old SslStream
                        // overload can default to TLS 1.0 despite HttpClient settings.
                        await ssl.AuthenticateAsClientAsync(host,null,SslProtocols.Tls12,false);
                    }
                    token.ThrowIfCancellationRequested();
                    if(deadline.IsCancellationRequested)throw new TimeoutException(stage+" timed out");
                } catch {
                    token.ThrowIfCancellationRequested();
                    if(deadline.IsCancellationRequested)throw new TimeoutException(stage+" timed out");
                    throw;
                }
            }
        }
    }

    /* تونلِ دیگری روی همین دستگاه؟ دو تونلِ سراسریِ همزمان بر سرِ مسیرِ پیش‌فرض و
       DNS با هم دعوا می‌کنند و نتیجه‌اش همین «وصل ولی بی‌ترافیک» است. فقط تشخیص
       می‌دهیم تا پیامِ خطا گویا باشد — جلوی کسی را نمی‌گیریم. */
    static string OtherTunnel() {
        try {
            foreach(var ni in NetworkInterface.GetAllNetworkInterfaces()) {
                if(ni.OperationalStatus!=OperationalStatus.Up)continue;
                if(ni.Name==TunName||ni.Description==TunName)continue;
                var text=(ni.Name+" "+ni.Description).ToLowerInvariant();
                if(text.IndexOf("tun")<0&&text.IndexOf("wireguard")<0&&text.IndexOf("tap-")<0)continue;
                if(ni.GetIPProperties().GatewayAddresses.Count==0)continue;
                return ni.Name;
            }
        } catch { }
        return null;
    }

    /* اگر تونل بالا نیامد، سرنخ‌ها جایی نوشته می‌شوند که پس از پاک‌شدنِ پوشهٔ موقت
       باقی بمانند — از جمله دلیلِ واقعی که خودِ sing-box روی stderr می‌نویسد. */
    Exception FailTunnel(bool traffic=false) {
        return new Exception(OtherTunnel()!=null?"err.tunBusy":traffic?"err.tunnelTraffic":"err.tunnel");
    }

    /* گزارشِ هر تلاشِ TUN — چه موفق باشد چه ناموفق. اگر روزی رابط «متصل» شد ولی باز
       هم کار نکرد، همین فایل می‌گوید کدام مرحله سالم بود و کدام نبود. */
    void WriteTunnelLog(string result) {
        try {
            var address=TunAddress();
            var text=new StringBuilder();
            text.AppendLine("Vyrax — tun attempt: "+result);
            text.AppendLine("time      : "+DateTime.UtcNow.ToString("u"));
            text.AppendLine("elevated  : "+Elevated);
            text.AppendLine("viaHelper : "+viaHelper);
            text.AppendLine("coreAlive : "+(tun!=null&&!tun.HasExited));
            text.AppendLine("tunIface  : "+(address==null?"missing":address.ToString()));
            text.AppendLine("otherTun  : "+(OtherTunnel()??"none"));
            text.AppendLine("gateways  : "+Gateways());
            text.AppendLine("--- core output ---");
            lock(coreLock) {
                foreach(var line in coreHead) text.AppendLine(line);
                var skipped=coreLines-coreHead.Count-coreTail.Count;
                if(skipped>0)text.AppendLine("... ("+skipped+" lines omitted) ...");
                foreach(var line in coreTail) text.AppendLine(line);
                var errors=coreErrors.Where(line=>!coreHead.Contains(line)&&!coreTail.Contains(line)).ToArray();
                if(errors.Length>0){text.AppendLine("--- retained core errors ---");foreach(var line in errors)text.AppendLine(line);}
            }
            File.WriteAllText(Path.Combine(store.Root,"last-tunnel.log"),text.ToString(),new UTF8Encoding(false));
        } catch { }
    }

    /* کدام رابط‌ها مسیرِ پیش‌فرضِ IPv4 دارند — برای دیدنِ دعوای دو تونل روی مسیر. */
    static string Gateways() {
        try {
            var parts=new List<string>();
            foreach(var ni in NetworkInterface.GetAllNetworkInterfaces()) {
                if(ni.OperationalStatus!=OperationalStatus.Up)continue;
                foreach(var gw in ni.GetIPProperties().GatewayAddresses)
                    if(gw.Address.AddressFamily==AddressFamily.InterNetwork)parts.Add(ni.Name+" via "+gw.Address);
            }
            return parts.Count==0?"none":String.Join(" | ",parts.ToArray());
        } catch { return "?"; }
    }

    /* راه‌اندازی تونل فقط وقتی «متصل» حساب می‌شود که واقعاً ترافیکی از آن رد شده باشد.
       چند نقطهٔ پایانی را امتحان می‌کنیم و هر پاسخ سالمی (۲۰۴ یا ۲۰۰) را قبول می‌کنیم،
       چون روی شبکه‌های فیلترشده ممکن است بعضی از این‌ها در دسترس نباشند. */
    static async Task VerifyProxy(int port,CancellationToken token) {
        using(var handler=new HttpClientHandler{UseProxy=true,Proxy=new WebProxy("http://127.0.0.1:"+port),AllowAutoRedirect=false,UseCookies=false,MaxConnectionsPerServer=4,SslProtocols=SslProtocols.Tls12})
        using(var client=new HttpClient(handler){Timeout=TimeSpan.FromSeconds(5)}) {
            var urls=new[]{
                "https://www.gstatic.com/generate_204",
                "https://cp.cloudflare.com/generate_204",
                "https://www.msftconnecttest.com/connecttest.txt",
                "https://captive.apple.com/hotspot-detect.html"
            };
            var checks=urls.Select(url=>new Func<CancellationToken,Task>(async stop=>{
                using(var r=await client.GetAsync(url,HttpCompletionOption.ResponseHeadersRead,stop))
                    if(r.StatusCode!=HttpStatusCode.NoContent&&r.StatusCode!=HttpStatusCode.OK)throw new HttpRequestException("Unexpected health response");
            })).ToArray();
            if(await FirstHealthy(checks,token)>=0)return;
        }
        throw new Exception("err.verify");
    }

    void StopInner() {
        connected=false;exitIp="";
        routingPool=null;activeTargets=new string[0];
        try {share.Dispose();}catch(Exception e){LogLine("share cleanup: "+e.Message);}
        /* هستهٔ TUN در حالت VPN دستِ هلپر است، نه دستِ ما */
        if(viaHelper){ viaHelper=false; try { HelperClient.Stop(); } catch { } }
        foreach(var p in new[]{tun,xray}) if(p!=null){ try{ if(!p.HasExited){p.Kill();p.WaitForExit(2000);} }catch{} p.Dispose(); }
        tun=xray=null;
        proxy.Recover();
        if(configFolder!=null&&Directory.Exists(configFolder)){ try{ Directory.Delete(configFolder,true); }catch{} }
        configFolder=null;
    }

    public async Task<object> Disconnect(){
        if(session!=null)session.Cancel();
        await gate.WaitAsync();
        try { StopInner();profileId="";Emit("disconnected");return Snapshot(); } finally { gate.Release(); }
    }

    public async Task<object> Select(Dictionary<string,object>[] profiles,string selected,string mode,string source) {
        await gate.WaitAsync();
        try {
            if(!connected||routingPool==null||session==null)throw new Exception("err.routingUnavailable");
            await routingPool.Select(profiles,selected,mode,source,session.Token);
            var previousId=profileId;
            profileId=routingPool.SelectedId;
            var chosen=profiles.First(p=>Json.Str(p,"id")==profileId);
            if(previousId!=profileId||String.IsNullOrEmpty(exitIp))UpdateExit(Json.Str(chosen,"host"));
            activeTargets=new[]{profileId};nextSelection=DateTime.UtcNow;
            Emit("connected","","",true);return Snapshot();
        } finally {gate.Release();}
    }

    public async Task Poll() {
        if(!connected)return;
        var current=session;
        /* در حالت VPN پروسهٔ هسته دستِ ما نیست، پس زنده‌بودنش را از هلپر می‌پرسیم.
           پرسیدن روی نخِ رابط نباشد و اگر دورِ قبلی هنوز تمام نشده، این دور را رد
           می‌کنیم تا هر ثانیه یک درخواست روی هم تلنبار نشود. */
        var tunDown=false;
        if(viaHelper) {
            if(Interlocked.CompareExchange(ref tunCheckBusy,1,0)==0) {
                try { tunDown=!await Task.Run(()=>HelperClient.TunAlive()); }
                finally { Interlocked.Exchange(ref tunCheckBusy,0); }
            }
        } else tunDown=tun!=null&&tun.HasExited;
        if(current!=session||!connected)return;
        if(xray==null||xray.HasExited||tunDown){ await Disconnect();Emit("disconnected","err.coreStopped");return; }
        if(routingPool!=null&&routingPool.Mode!="manual"&&DateTime.UtcNow>=nextSelection) {
            nextSelection=DateTime.UtcNow.AddSeconds(10);var pool=routingPool;var version=pool.Version;
            try {
                var targets=await pool.Targets(current.Token);
                if(current==session&&connected&&pool==routingPool&&version==pool.Version&&targets.Length>0) {
                    if(targets[0]!=profileId){activeTargets=targets;profileId=targets[0];UpdateExit(Json.Str(pool.Profile(targets[0]),"host"));Emit("connected","","",true);}
                    else activeTargets=targets;
                }
            } catch { }
        }
        if(DateTime.UtcNow>=nextHealth) {
            nextHealth=DateTime.UtcNow.AddSeconds(30);
            var healthy=false;
            try {await VerifyProxy(healthPort,current.Token);healthy=true;}
            catch(OperationCanceledException){return;}
            catch { }
            if(current!=session||!connected)return;
            healthFailures=healthy?0:healthFailures+1;
            if(healthFailures>=2){await Disconnect();Emit("disconnected","err.verify");return;}
        }
        try {
            using(var handler=new HttpClientHandler{UseProxy=false})
            using(var client=new HttpClient(handler){Timeout=TimeSpan.FromSeconds(1)}) {
                var data=Json.Read(await client.GetStringAsync("http://127.0.0.1:"+metrics+"/debug/vars"));
                object raw;if(!data.TryGetValue("stats",out raw))return;
                var stats=raw as Dictionary<string,object>;if(stats==null)return;
                object outboundRaw,proxyRaw;
                var outbound=stats.TryGetValue("outbound",out outboundRaw)?outboundRaw as Dictionary<string,object>:null;
                var proxyStats=outbound!=null&&outbound.TryGetValue("proxy",out proxyRaw)?proxyRaw as Dictionary<string,object>:null;
                if(outbound==null)return;
                long up=0,down=0;
                foreach(var pair in outbound)if(pair.Key=="proxy"||pair.Key.StartsWith("node-")) {var values=pair.Value as Dictionary<string,object>;if(values!=null){up+=Value(values,"uplink");down+=Value(values,"downlink");}}
                var now=DateTime.UtcNow;var seconds=Math.Max(.1,(now-lastSample).TotalSeconds);
                if(Changed!=null)Changed(Json.Obj("event","stats","up",up,"down",down,"upRate",Math.Max(0,(up-lastUp)/seconds),"downRate",Math.Max(0,(down-lastDown)/seconds)));
                lastUp=up;lastDown=down;lastSample=now;
            }
        } catch { }
    }

    static long Value(Dictionary<string,object> d,string name){ object raw;if(!d.TryGetValue(name,out raw))return 0;long v;return long.TryParse(Convert.ToString(raw),out v)?v:0; }

    static readonly HttpClient subscriptionClient=CreateSubscriptionClient();
    static HttpClient CreateSubscriptionClient(int port=0) {
        var handler=new HttpClientHandler{UseProxy=port>0,Proxy=port>0?new WebProxy("http://127.0.0.1:"+port):null,AllowAutoRedirect=false,UseCookies=false,AutomaticDecompression=DecompressionMethods.GZip|DecompressionMethods.Deflate,MaxConnectionsPerServer=8,SslProtocols=SslProtocols.Tls12};
        var client=new HttpClient(handler){Timeout=Timeout.InfiniteTimeSpan};
        client.DefaultRequestHeaders.UserAgent.ParseAdd("Vyrax/"+typeof(Engine).Assembly.GetName().Version.ToString(3));
        return client;
    }
    public async Task<object> FetchSubscription(string url) {
        if(!connected)return await Fetch(url);
        // Xray's process already bypasses our TUN. Its dedicated local inbound
        // reaches subscription panels over the uplink without routing user apps
        // outside the VPN or changing their connections.
        using(var direct=CreateSubscriptionClient(subscriptionPort))
        using(var routed=CreateSubscriptionClient(healthPort)) {
            try{return await FetchUsing(url,direct,4);}
            catch(Exception error) {
                if(error.Message=="err.subUrl"||error.Message=="err.subRedirect"||error.Message=="err.subSize")throw;
            }
            return await FetchUsing(url,routed,12);
        }
    }
    /* Reuse transport connections, never cached subscription contents. */
    public static Task<object> Fetch(string url) { return FetchUsing(url,subscriptionClient,20); }
    internal static async Task<object> FetchUsing(string url,HttpClient transport,int seconds) {
        Uri u;
        if(!Uri.TryCreate(url,UriKind.Absolute,out u)||(u.Scheme!="http"&&u.Scheme!="https")||!String.IsNullOrEmpty(u.UserInfo))throw new Exception("err.subUrl");
        using(var deadline=new CancellationTokenSource(TimeSpan.FromSeconds(seconds))) {
            for(int redirect=0;redirect<5;redirect++) {
                using(var r=await transport.GetAsync(u,HttpCompletionOption.ResponseHeadersRead,deadline.Token)) {
                    if((int)r.StatusCode>=300&&(int)r.StatusCode<400) {
                        var next=r.Headers.Location;
                        if(next==null)throw new Exception("err.subRedirect");
                        var previousScheme=u.Scheme;
                        u=next.IsAbsoluteUri?next:new Uri(u,next);
                        if((u.Scheme!="https"&&u.Scheme!="http")||!String.IsNullOrEmpty(u.UserInfo)||(previousScheme=="https"&&u.Scheme!="https"))throw new Exception("err.subRedirect");
                        continue;
                    }
                    if(!r.IsSuccessStatusCode)throw new Exception("err.subFailed");
                    using(var input=await r.Content.ReadAsStreamAsync())
                    using(var output=new MemoryStream()) {
                        var buffer=new byte[16384];int n;
                        while((n=await input.ReadAsync(buffer,0,buffer.Length,deadline.Token))>0) {
                            if(output.Length+n>4*1024*1024)throw new Exception("err.subSize");
                            output.Write(buffer,0,n);
                        }
                        return Json.Obj("text",Encoding.UTF8.GetString(output.ToArray()),"userInfo",Header(r,"subscription-userinfo"),"title",Header(r,"profile-title"),"disposition",Header(r,"content-disposition"));
                    }
                }
            }
        }
        throw new Exception("err.subLoop");
    }

    static string Header(HttpResponseMessage response,string name) {IEnumerable<string> values;if(!response.Headers.TryGetValues(name,out values)&&!response.Content.Headers.TryGetValues(name,out values))return "";var text=String.Join(";",values);return text.Length<=8192?text:"";}

    /* URLTest از داخل هر کانفیگ؛ شروع هسته جزو عدد تأخیر نیست.
       هستهٔ موقت و ورودیِ probe مستقل از اتصالِ فعال و قوانین bypass هستند. */
    public static async Task<object> RealDelay(Dictionary<string,object> profile,string coreRoot) {
        Config.Validate(profile);
        var folder=Path.Combine(Path.GetTempPath(),"vyrax-delay-"+Guid.NewGuid().ToString("N"));
        Process core=null;ChildJob guard=null;
        try {
            Directory.CreateDirectory(folder);
            int socks=Cores.FreePort(),http=Cores.FreePort(),metrics=Cores.FreePort(),probe=Cores.FreePort();
            var file=Path.Combine(folder,"xray.json");
            File.WriteAllText(file,Json.Write(Config.Xray(profile,socks,http,metrics,null,probe)),new UTF8Encoding(false));

            var exe=Path.Combine(coreRoot,"xray.exe");
            if(!File.Exists(exe))throw new Exception("err.coreMissing");
            guard=new ChildJob();
            core=Cores.StartCore(exe,"run -config \""+file+"\"",guard);

            var up=false;
            for(int i=0;i<40&&!up;i++) {
                if(core.HasExited)break;
                using(var c=new TcpClient()){ try { await c.ConnectAsync("127.0.0.1",probe);up=true; } catch { } }
                if(!up)await Task.Delay(100);
            }
            if(!up)return Json.Obj("latency",null);

            return Json.Obj("latency",await DelayProbe.Measure(probe));
        } catch { return Json.Obj("latency",null); }
        finally {
            if(core!=null){ try { if(!core.HasExited){core.Kill();core.WaitForExit(1500);} } catch { } core.Dispose(); }
            if(guard!=null){ try { guard.Dispose(); } catch { } }
            try { if(Directory.Exists(folder))Directory.Delete(folder,true); } catch { }
        }
    }

    /* بررسی دسترسی TCP؛ تأخیر تقریبی برمی‌گرداند. */
    public static async Task<object> Ping(Dictionary<string,object> p) {
        Config.Validate(p);
        var watch=Stopwatch.StartNew();
        using(var c=new TcpClient()) {
            var task=c.ConnectAsync(Json.Str(p,"host"),Json.Int(p,"port"));
            if(await Task.WhenAny(task,Task.Delay(4000))!=task)return Json.Obj("latency",null);
            try { await task;return Json.Obj("latency",watch.ElapsedMilliseconds); } catch { return Json.Obj("latency",null); }
        }
    }

    /* کشورِ هر میزبان: اگر IP باشد مستقیم، وگرنه اول دامنه را resolve می‌کنیم.
       همه‌چیز آفلاین و روی همین دستگاه. */
    public static async Task<object> GeoLookup(Geo geo,string[] hosts) {
        var result=Json.Obj();
        foreach(var host in hosts) {
            if(String.IsNullOrEmpty(host))continue;
            var direct=geo.Lookup(host);
            if(direct!=null){ result[host]=direct;continue; }
            if(host.Contains(":")){ result[host]=null;continue; }   /* IPv6 پوشش داده نمی‌شود */
            try {
                var deadline=Task.Delay(4000);
                var lookup=Dns.GetHostAddressesAsync(host);
                var done=await Task.WhenAny(lookup,deadline);
                if(done!=lookup){ result[host]=null;continue; }
                var address=lookup.Result.FirstOrDefault(a=>a.AddressFamily==AddressFamily.InterNetwork);
                result[host]=address!=null?geo.Lookup(address.ToString()):null;
            } catch { result[host]=null; }
        }
        return result;
    }

    public void Dispose(){ if(session!=null)session.Cancel();StopInner();HelperClient.Shutdown();job.Dispose(); }
}
}
