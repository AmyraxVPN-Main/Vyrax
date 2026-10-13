using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Security.AccessControl;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Vyrax {
/* پلِ حالت VPN کامل.
   TUN در ویندوز به دسترسی مدیر نیاز دارد، ولی میزبانِ رابط (WebView2) باید
   بدون دسترسی مدیر بماند — توصیهٔ خودِ مایکروسافت هم همین است. پس کارِ ممتاز در
   یک پروسهٔ کوچکِ جدا انجام می‌شود: VyraxHelper.exe.

   این فایل دو نیمه دارد:
     HelperServer — فقط داخل VyraxHelper.exe اجرا می‌شود؛ هستهٔ TUN را بالا می‌آورد.
     HelperClient — داخل خودِ برنامه؛ هلپر را با UAC بالا می‌آورد و با آن حرف می‌زند.

   ── مرزهای امنیتی، صادقانه ──────────────────────────────────────────────
   چه چیزی *هست*: نام لوله مخصوص همین کاربر است و DACL دارد؛ دستورها انگشت‌شمار و
   نوع‌دارند و هیچ‌کدام مسیر فایل نمی‌گیرد؛ کانفیگ را خودِ هلپر از روی عددها
   می‌سازد و در پوشه‌ای می‌نویسد که کاربرِ بی‌دسترسی نمی‌تواند بنویسد؛ هسته را از
   پوشهٔ خودش برمی‌دارد، نه از مسیری که طرفِ مقابل بدهد.

   چه چیزی *نیست*: این طراحی جلوی یک مهاجمِ هم‌کاربرِ مصمم را نمی‌گیرد. برنامه
   به‌صورت هر-کاربر نصب می‌شود، پس خودِ VyraxHelper.exe در پوشه‌ای نشسته که همان
   کاربر می‌تواند بنویسد و جایگزینش کند. هدف این است که مهاجم چیزی *بیشتر* از
   آنچه از قبل داشت به دست نیاورد، نه اینکه هیچ کاری نتواند بکند. راه‌حل واقعی
   نصبِ هلپر در مسیری است که کاربر نتواند بنویسد، که یعنی نصبِ ماشین‌گستر با UAC
   هنگام نصب — تصمیمی محصولی، نه جزئیات، و فعلاً بیرون از این کار.

   عمداً «اثر انگشتِ هسته‌ها» را پیاده نکردیم: خودِ هلپر به همان اندازه قابل
   جایگزینی است، پس قفل‌کردن فقط هسته‌ها آن مسیر را نمی‌بندد ولی یک حالت خرابی
   تازه می‌سازد (هر بار به‌روزرسانی هسته‌ها باید اثر انگشت را دستی عوض کنیم). */
public static class Helper {
    /* نام لوله باید مخصوص همین کاربر باشد: برخلاف mutex، لوله‌های نام‌دار در یک
       فضای سراسریِ ماشین‌اند و نامِ ثابت بین کاربران/نشست‌ها تصادم می‌کند. */
    public static string PipeName() {
        using(var sha=SHA256.Create()) {
            var sid=WindowsIdentity.GetCurrent().User.Value;
            var hash=sha.ComputeHash(Encoding.UTF8.GetBytes(sid));
            var sb=new StringBuilder("Vyrax-helper-",32);
            for(int i=0;i<8;i++)sb.Append(hash[i].ToString("x2"));
            return sb.ToString();
        }
    }

    /* پوشهٔ کاریِ هلپر. کاربرِ بی‌دسترسی نباید بتواند اینجا بنویسد، وگرنه همان
       مسابقهٔ نوشتن/خواندن برمی‌گردد که می‌خواهیم ببندیمش. */
    public static string Root() {
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),"Vyrax Helper");
    }

    public static string NewToken() {
        var bytes=new byte[32];
        using(var rng=new RNGCryptoServiceProvider()) rng.GetBytes(bytes);
        var sb=new StringBuilder(64);
        foreach(var b in bytes) sb.Append(b.ToString("x2"));
        return sb.ToString();
    }

    /* مقایسهٔ زمان‌ثابت. CryptographicOperations فقط در .NET Core هست، پس
       دستی می‌نویسیم؛ طول‌ها هم اول یکسان می‌شوند تا طول لو نرود. */
    public static bool SameSecret(string a,string b) {
        if(a==null||b==null)return false;
        var x=Encoding.UTF8.GetBytes(a);var y=Encoding.UTF8.GetBytes(b);
        int diff=x.Length^y.Length;
        for(int i=0;i<x.Length&&i<y.Length;i++)diff|=x[i]^y[i];
        return diff==0;
    }

    /* قالب پیام: ۴ بایت طول (big-endian) و بعد همان‌قدر UTF-8.
       یک بایتِ اضافه هم قبول نمی‌کنیم؛ Read می‌تواند کوتاه برگردد، پس حلقه لازم است. */
    public static void WriteFrame(Stream s,object message) {
        var body=Encoding.UTF8.GetBytes(Json.Write(message));
        if(body.Length==0||body.Length>MaxFrame) throw new Exception("err.helperFrame");
        var head=new byte[]{ (byte)(body.Length>>24),(byte)(body.Length>>16),(byte)(body.Length>>8),(byte)body.Length };
        s.Write(head,0,4);s.Write(body,0,body.Length);s.Flush();
    }

    public static readonly int MaxFrame=1024*1024;

    public static Dictionary<string,object> ReadFrame(Stream s) {
        var head=new byte[4];
        if(!ReadFull(s,head,4))return null;              // صفر بایت = طرف مقابل رفت
        int n=(head[0]<<24)|(head[1]<<16)|(head[2]<<8)|head[3];
        if(n<=0||n>MaxFrame)throw new Exception("err.helperFrame");
        var body=new byte[n];
        if(!ReadFull(s,body,n))return null;
        return Json.Read(Encoding.UTF8.GetString(body));
    }

    static bool ReadFull(Stream s,byte[] buffer,int count) {
        int at=0;
        while(at<count) {
            int got;
            try { got=s.Read(buffer,at,count-at); } catch(IOException) { return false; }
            if(got<=0) return at==0?false:false;          // لوله بسته شد
            at+=got;
        }
        return true;
    }
}

/* ───────────────────────── نیمهٔ هلپر (ممتاز) ───────────────────────── */
public static class HelperServer {
    static Process core;
    static ChildJob job;
    static string sessionFolder;

    public static int Run(string[] args) {
        HideConsole();
        /* اول از همه: بدونِ دسترسی مدیر این پروسه کاری نمی‌تواند بکند — و مهم‌تر،
           نباید پوشهٔ %ProgramData% را بسازد. اگر بدونِ مدیر ساخته شود مالکش کاربرِ
           عادی می‌شود، و چون مالک همیشه می‌تواند با WRITE_DAC قفل را باز کند،
           PrepareRoot بعد از آن برای همیشه رد می‌کند و TUN تا حذفِ دستیِ آن پوشه
           از کار می‌افتد. پس پیش از دست‌زدن به فایل‌سیستم برمی‌گردیم. */
        if(!Cores.Elevated) return 1;
        var pipeName=Arg(args,"--pipe");
        var token=Arg(args,"--token");
        if(String.IsNullOrEmpty(pipeName)||String.IsNullOrEmpty(token)) return 2;

        job=new ChildJob();
        try {
            PrepareRoot();
        } catch {
            return 3;                                     // پوشه امن نشد → بالا نیا
        }

        try {
            var security=PipeSecurity();
            var pipe=new NamedPipeServerStream(
                pipeName,PipeDirection.InOut,1,PipeTransmissionMode.Byte,
                PipeOptions.None,Helper.MaxFrame,Helper.MaxFrame,security);

            using(var wait=new CancellationTokenSource(TimeSpan.FromSeconds(90))) {
                try { pipe.WaitForConnectionAsync(wait.Token).GetAwaiter().GetResult(); }
                catch { return 4; }                            // کسی وصل نشد
            }

            Serve(pipe,token);
            return 0;
        } catch {
            return 5;
        } finally {
            StopCore();
            if(job!=null){ job.Dispose(); job=null; }
        }
    }

    /* وقتی طرف مقابل می‌رود (برنامه بسته شد یا مرد)، خواندن صفر برمی‌گرداند و
       هلپر هم می‌رود. به‌علاوه ChildJob تضمین می‌کند sing-box با ما بمیرد. */
    static void Serve(Stream pipe,string token) {
        bool greeted=false;
        while(true) {
            Dictionary<string,object> message;
            try { message=Helper.ReadFrame(pipe); }
            catch { return; }
            if(message==null) return;

            var id=Json.Str(message,"id");
            object result=null;string error=null;
            try {
                var cmd=Json.Str(message,"cmd");
                if(!greeted) {
                    if(cmd!="hello") throw new Exception("err.helperAuth");
                    if(!Helper.SameSecret(Json.Str(message,"token"),token)) throw new Exception("err.helperAuth");
                    if(Json.Int(message,"proto")!=Proto) throw new Exception("err.helperProto");
                    greeted=true;
                    result=Json.Obj("proto",Proto,"elevated",Cores.Elevated);
                } else switch(cmd) {
                    case "ping": result=Json.Obj("ok",true);break;
                    case "status": result=Json.Obj("running",CoreAlive(),"pid",core!=null&&CoreAlive()?core.Id:0);break;
                    case "tun.start": result=TunStart(Json.Int(message,"socksPort"),Json.Int(message,"mtu",1280));break;
                    case "tun.stop": StopCore();result=Json.Obj("ok",true);break;
                    default: throw new Exception("err.helperCmd");
                }
            } catch(Exception e) { error=e.Message; }

            try { Helper.WriteFrame(pipe,error!=null?Json.Obj("id",id,"error",error):Json.Obj("id",id,"result",result)); }
            catch { return; }                                  // لوله قطع شد
        }
    }

    public const int Proto=1;

    /* مسیر هسته‌ها را خودمان می‌سازیم. اگر طرفِ مقابل بتواند مسیر بدهد، می‌تواند
       ما را وادار کند یک باینریِ دلخواه را با دسترسی مدیر اجرا کنیم. */
    static object TunStart(int socksPort,int mtu) {
        if(socksPort<1024||socksPort>65535) throw new Exception("err.port");
        if(mtu<1280||mtu>1500) mtu=1280;                      // مثل Config.Tun

        StopCore();
        var folder=Path.Combine(Helper.Root(),"runtime-"+Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(folder);
        Store.RestrictAdmin(folder);

        var file=Path.Combine(folder,"tun.json");
        File.WriteAllText(file,Json.Write(Config.Tun(socksPort,mtu)),new UTF8Encoding(false));

        var exe=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"cores","sing-box.exe");
        if(!File.Exists(exe)) throw new Exception("err.coreMissing");

        core=Cores.StartCore(exe,"run -c \""+file+"\"",job);
        sessionFolder=folder;
        Thread.Sleep(1400);                                   // مثل مسیر درون‌برنامه‌ای
        if(core.HasExited) { StopCore(); throw new Exception("err.tunnel"); }
        return Json.Obj("pid",core.Id);
    }

    static bool CoreAlive() { return core!=null&&!core.HasExited; }

    static void StopCore() {
        if(core!=null) { try { if(!core.HasExited){core.Kill();core.WaitForExit(2000);} } catch { } core.Dispose(); core=null; }
        if(sessionFolder!=null) { try { if(Directory.Exists(sessionFolder))Directory.Delete(sessionFolder,true); } catch { } sessionFolder=null; }
    }

    /* پوشه باید فقط دستِ SYSTEM و Administrators باشد، و *مالکش* هم آن‌ها.
       اگر کاربر بی‌دسترسی از قبل این پوشه را ساخته باشد مالکِ آن است و می‌تواند
       با WRITE_DAC دوباره کنترل را بگیرد — پس در آن حالت بالا نمی‌آییم. */
    static void PrepareRoot() {
        var root=Helper.Root();
        if(Directory.Exists(root)) {
            var owner=new DirectoryInfo(root).GetAccessControl().GetOwner(typeof(SecurityIdentifier));
            if(owner==null) throw new Exception("err.helperDir");
            var sid=owner.Value;
            var system=new SecurityIdentifier(WellKnownSidType.LocalSystemSid,null).Value;
            var admins=new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid,null).Value;
            if(sid!=system&&sid!=admins) throw new Exception("err.helperDir");
        } else {
            Directory.CreateDirectory(root);
        }
        Store.RestrictAdmin(root);
    }

    static PipeSecurity PipeSecurity() {
        var security=new PipeSecurity();
        security.SetAccessRuleProtection(true,false);
        var system=new SecurityIdentifier(WellKnownSidType.LocalSystemSid,null);
        var admins=new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid,null);
        var user=WindowsIdentity.GetCurrent().User;
        security.AddAccessRule(new PipeAccessRule(system,PipeAccessRights.FullControl,AccessControlType.Allow));
        security.AddAccessRule(new PipeAccessRule(admins,PipeAccessRights.FullControl,AccessControlType.Allow));
        security.AddAccessRule(new PipeAccessRule(user,PipeAccessRights.FullControl,AccessControlType.Allow));
        return security;
    }

    static string Arg(string[] args,string name) {
        foreach(var a in args) if(a.StartsWith(name+"=",StringComparison.Ordinal)) return a.Substring(name.Length+1);
        return "";
    }

    /* هلپر کنسول است تا در فهرست پروسه‌ها از میزبانِ رابط جدا باشد، ولی نباید
       پنجرهٔ سیاه نشان بدهد. */
    [System.Runtime.InteropServices.DllImport("kernel32.dll")] static extern IntPtr GetConsoleWindow();
    [System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h,int cmd);
    static void HideConsole() {
        var h=GetConsoleWindow();
        if(h!=IntPtr.Zero) ShowWindow(h,0);
    }
}

/* ───────────────────────── نیمهٔ برنامه (بی‌دسترسی) ───────────────────────── */
public static class HelperClient {
    static readonly object gate=new object();
    static NamedPipeClientStream pipe;
    static string token;
    static int sequence;

    public static bool Running { get { lock(gate) return pipe!=null&&pipe.IsConnected; } }

    public static bool StartTun(int socksPort,int mtu) {
        Send("tun.start",Json.Obj("socksPort",socksPort,"mtu",mtu),120000);
        return true;
    }

    public static void Stop() {
        lock(gate) { if(pipe==null) return; }
        try { Send("tun.stop",null,15000,false); } catch { }
    }

    /* آیا هستهٔ TUN که هلپر بالا آورده هنوز زنده است؟ */
    public static bool TunAlive() {
        try {
            var reply=Send("status",null,5000,false);
            return Json.Bool((Dictionary<string,object>)reply,"running");
        } catch { return false; }
    }

    public static void Shutdown() {
        lock(gate) {
            if(pipe!=null) { try { pipe.Dispose(); } catch { } pipe=null; }
            token=null;
        }
    }

    /* هلپر را با UAC بالا می‌آورد. کل عمرِ برنامه حداکثر یک بار، چون هلپر
       مقیم می‌ماند و برای اتصال‌های بعدی دوباره استفاده می‌شود. */
    static void Launch() {
        var exe=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"VyraxHelper.exe");
        if(!File.Exists(exe)) throw new Exception("err.coreMissing");
        var fresh=Helper.NewToken();
        var info=new ProcessStartInfo(exe) {
            UseShellExecute=true,
            Verb="runas",
            Arguments="--pipe="+Helper.PipeName()+" --token="+fresh+" --parent="+Process.GetCurrentProcess().Id
        };
        try {
            Process.Start(info);
        } catch(Win32Exception) {
            /* ۱۲۲۳ = کاربر پنجرهٔ UAC را رد کرد */
            throw new Exception("err.adminDeclined");
        } catch(Exception) {
            throw new Exception("err.adminStart");
        }
        lock(gate) { token=fresh; }
    }

    static void Connect() {
        var client=new NamedPipeClientStream(".",Helper.PipeName(),PipeDirection.InOut,PipeOptions.None);
        try {
            using(var wait=new CancellationTokenSource(TimeSpan.FromSeconds(120)))
                client.ConnectAsync(wait.Token).GetAwaiter().GetResult();
        } catch {
            try { client.Dispose(); } catch { }
            throw new Exception("err.adminTimeout");
        }
        lock(gate) { pipe=client; }
        /* دست‌دادن باید اولِ هر اتصال باشد، وگرنه هلپر هیچ دستوری را قبول نمی‌کند.
           allowLaunch=false چون تازه وصل شده‌ایم و نباید دوباره هلپر بسازیم. */
        Send("hello",Json.Obj("proto",HelperServer.Proto),20000,false);
    }

    /* `allowLaunch` عمداً هست: متوقف‌کردن و پرسیدنِ وضعیت هرگز نباید هلپر را دوباره
       بالا بیاورند، وگرنه فقط برای «توقف» یا «آیا زنده است؟» یک پنجرهٔ UAC دیگر
       به کاربر نشان می‌دهیم. */
    static object Send(string cmd,Dictionary<string,object> extra,int timeoutMs,bool allowLaunch=true) {
        lock(gate) {
            if(pipe==null||!pipe.IsConnected) { try { pipe=null; } catch { } }
            if(pipe==null) {
                if(!allowLaunch) throw new Exception("err.helperGone");
                Launch(); Connect();
            }

            var id=(++sequence).ToString();
            var message=Json.Obj("id",id,"cmd",cmd,"token",token);
            if(extra!=null) foreach(var kv in extra) message[kv.Key]=kv.Value;

            try {
                Helper.WriteFrame(pipe,message);
                var reply=Helper.ReadFrame(pipe);
                if(reply==null) throw new Exception("err.helperGone");
                var error=Json.Str(reply,"error");
                if(error.Length>0) throw new Exception(error);
                return reply.ContainsKey("result")?reply["result"]:null;
            } catch {
                /* لوله مرده؛ دفعهٔ بعد دوباره وصل می‌شویم (و اگر هلپر رفته، UAC دوباره) */
                try { pipe.Dispose(); } catch { }
                pipe=null;
                throw;
            }
        }
    }
}
}
