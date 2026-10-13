using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Security.Principal;
using System.Threading;
using System.Threading.Tasks;

namespace Vyrax {
/* کمک‌کارهای مشترکِ هسته‌ها: انتخاب پورت آزاد، بالا آوردن و آزمایش یک هسته.
   این‌ها قبلاً عضوِ Engine بودند. جدا شدند تا VyraxHelper.exe بتواند فقط همین‌ها را
   کامپایل کند و در عوض Engine، ProxySettings و WinForms را با خودش نکشد.
   رفتار هیچ‌کدام تغییر نکرده؛ فقط جابه‌جا شده‌اند. */
public static class Cores {
    /* آیا همین پروسه با دسترسی مدیر اجرا شده؟ حالت VPN کامل به آن نیاز دارد.
       اینجا هست و نه در Engine، تا VyraxHelper.exe بتواند بدون کشیدنِ Engine
       همین را بپرسد. */
    public static bool Elevated { get { return new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator); } }

    static readonly Dictionary<int,DateTime> issuedPorts=new Dictionary<int,DateTime>();
    // SOCKS/mixed listeners bind both TCP and UDP. Windows may reserve different
    // ranges for each, so a successful TCP bind alone does not prove availability.
    // Keep recent allocations distinct until the cores have acquired their ports.
    public static int FreePort(){
        lock(issuedPorts){
            var expired=new List<int>();
            foreach(var item in issuedPorts)if(item.Value<DateTime.UtcNow.AddMinutes(-1))expired.Add(item.Key);
            foreach(var port in expired)issuedPorts.Remove(port);
            for(int attempt=0;attempt<128;attempt++){
                var listener=new TcpListener(IPAddress.Loopback,0);
                try{
                    listener.ExclusiveAddressUse=true;listener.Start();
                    int port=((IPEndPoint)listener.LocalEndpoint).Port;
                    if(issuedPorts.ContainsKey(port))continue;
                    using(var udp=new Socket(AddressFamily.InterNetwork,SocketType.Dgram,ProtocolType.Udp)){
                        udp.ExclusiveAddressUse=true;udp.Bind(new IPEndPoint(IPAddress.Loopback,port));
                    }
                    issuedPorts[port]=DateTime.UtcNow;return port;
                }catch(SocketException){}finally{listener.Stop();}
            }
            throw new Exception("err.portBusy");
        }
    }

    /* هسته را بی‌پنجره و بی‌کنسول بالا می‌آورد. اگر Job Object بدهی، مرگِ ما مرگِ او هم هست. */
    public static Process StartCore(string exe,string args,ChildJob owner,Action<string> onLine=null) {
        var info=new ProcessStartInfo(exe,args){UseShellExecute=false,CreateNoWindow=true,WindowStyle=ProcessWindowStyle.Hidden,WorkingDirectory=Path.GetDirectoryName(exe),RedirectStandardOutput=true,RedirectStandardError=true};
        var p=Process.Start(info);if(owner!=null)owner.Add(p);
        p.OutputDataReceived+=(s,e)=>{ if(onLine!=null&&e.Data!=null){ try { onLine(e.Data); } catch { } } };
        p.ErrorDataReceived+=(s,e)=>{ if(onLine!=null&&e.Data!=null){ try { onLine(e.Data); } catch { } } };
        p.BeginOutputReadLine();p.BeginErrorReadLine();return p;
    }

    /* اجرای کوتاهِ «فقط بررسی کانفیگ»؛ خروجی غیرصفر یعنی هسته این کانفیگ را نمی‌پذیرد. */
    public static void Check(string exe,string args){
        if(!File.Exists(exe))throw new Exception("err.coreMissing");
        using(var p=StartCore(exe,args,null)) {
            if(!p.WaitForExit(8000)){try{p.Kill();}catch{}throw new Exception("err.coreSlow");}
            if(p.ExitCode!=0)throw new Exception("err.coreUnsupported");
        }
    }

    /* تا وقتی هسته روی این پورت جواب ندهد صبر می‌کند؛ اگر وسط راه بمیرد فوراً می‌فهمیم. */
    public static async Task WaitPort(Process process,int port,CancellationToken token){
        for(int i=0;i<50;i++){
            token.ThrowIfCancellationRequested();
            if(process.HasExited)throw new Exception("err.coreFailed");
            using(var c=new TcpClient()){ try { await c.ConnectAsync("127.0.0.1",port);return; } catch { } }
            await Task.Delay(100,token);
        }
        throw new Exception("err.portBusy");
    }
}
}
