using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace Vyrax {
public sealed class MainForm : Form {
    WebView2 view;Store store;Engine engine;ConnectionSession connection;Geo geo;NotifyIcon tray;System.Windows.Forms.Timer poll;
    bool quitting,hiddenToTray;
    readonly string baseDir=AppDomain.CurrentDomain.BaseDirectory;

    [DllImport("user32.dll")]static extern bool ReleaseCapture();
    [DllImport("user32.dll")]static extern IntPtr SendMessage(IntPtr hWnd,int msg,IntPtr wParam,IntPtr lParam);
    [DllImport("dwmapi.dll")]static extern int DwmSetWindowAttribute(IntPtr hwnd,int attribute,ref int value,int size);

    public MainForm() {
        Text="Vyrax";
        Width=380;Height=646;
        try { Icon=System.Drawing.Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }
        FormBorderStyle=FormBorderStyle.None;
        StartPosition=FormStartPosition.CenterScreen;
        BackColor=Color.FromArgb(10,15,17);
        KeyPreview=true;
        Shown+=async(s,e)=>await Initialize();
        FormClosing+=HandleClosing;
    }

    /* گوشه‌های گرد و نوار عنوان تیره، مثل ویندوز ۱۱ */
    protected override CreateParams CreateParams {
        get {
            var value=base.CreateParams;
            // Frameless windows still need these native capabilities for the
            // taskbar to minimise an already active window on its second click.
            value.Style|=0x00020000|0x00080000; // WS_MINIMIZEBOX | WS_SYSMENU
            return value;
        }
    }
    protected override void OnHandleCreated(EventArgs e) {
        base.OnHandleCreated(e);
        var round=2;
        DwmSetWindowAttribute(Handle,33,ref round,4);      /* DWMWA_WINDOW_CORNER_PREFERENCE */
        var dark=1;
        DwmSetWindowAttribute(Handle,20,ref dark,4);       /* DWMWA_USE_IMMERSIVE_DARK_MODE */
    }

    async Task Initialize() {
        try {
            store=new Store();
            geo=new Geo(Path.Combine(baseDir,"geo.bin"));
            engine=new Engine(store,Path.Combine(baseDir,"cores"));
            connection=new ConnectionSession(engine);
            connection.Changed+=Post;

            view=new WebView2{Dock=DockStyle.Fill,DefaultBackgroundColor=BackColor};
            Controls.Add(view);

            var env=await CoreWebView2Environment.CreateAsync(null,Path.Combine(store.Root,"WebView"));
            await view.EnsureCoreWebView2Async(env);

            var s=view.CoreWebView2.Settings;
            s.IsWebMessageEnabled=true;
            s.AreDefaultContextMenusEnabled=false;
            s.AreDevToolsEnabled=Environment.GetCommandLineArgs().Contains("--devtools");
            s.IsStatusBarEnabled=false;
            s.AreBrowserAcceleratorKeysEnabled=false;
            s.IsZoomControlEnabled=false;
            // Let the title bar's CSS drag region behave like a Windows title bar.
            // Older runtimes retain the pointer/drag message fallback in Bar.jsx.
            try { s.IsNonClientRegionSupportEnabled=true; } catch (NotImplementedException) { }

            /* کشِ WebView2 در یک پوشهٔ پایدار نگه داشته می‌شود و url همیشه همان
               https://vyrax.local/index.html است. اگر نصب‌کننده رابطِ قدیمی را نگه داشته باشد
               (یا کاربر بعداً روی نسخهٔ قدیمی‌تر نصب کند)، WebView2 ممکن است همان را از
               کش برگرداند. پس هنگام شروع کش را پاک می‌کنیم تا همیشه فایلِ دیسک جواب بدهد. */
            try {
                /* عمداً منتظر می‌مانیم: باید *قبل* از رفتن به index.html پاک شده باشد. */
                await view.CoreWebView2.Profile.ClearBrowsingDataAsync(CoreWebView2BrowsingDataKinds.DiskCache);
            } catch { }

            view.CoreWebView2.SetVirtualHostNameToFolderMapping("vyrax.local",Path.Combine(baseDir,"ui"),CoreWebView2HostResourceAccessKind.DenyCors);

            /* لایهٔ دومِ همان مشکل: علاوه بر پاک‌کردنِ کش در شروع، به خودِ index.html هم
               می‌گوییم ذخیره نشود، تا اگر روزی ترتیب عوض شد باز هم رابطِ کهنه سوار نشود. */
            view.CoreWebView2.WebResourceResponseReceived+=(o,e)=> {
                if(e.Request.Uri.Equals("https://vyrax.local/index.html",StringComparison.OrdinalIgnoreCase)) {
                    var headers=e.Response.Headers;
                    headers.AppendHeader("Cache-Control","no-store");
                }
            };
            view.CoreWebView2.NavigationStarting+=(o,e)=>{ if(!e.Uri.StartsWith("https://vyrax.local/",StringComparison.OrdinalIgnoreCase))e.Cancel=true; };
            view.CoreWebView2.NewWindowRequested+=(o,e)=>{ e.Handled=true; };
            view.CoreWebView2.PermissionRequested+=(o,e)=>{ e.State=CoreWebView2PermissionState.Deny; };
            view.CoreWebView2.WebMessageReceived+=Message;
            view.Source=new Uri("https://vyrax.local/index.html");

            BuildTray();

            poll=new System.Windows.Forms.Timer{Interval=1000};
            bool polling=false;
            poll.Tick+=async(o,e)=>{ if(polling)return;polling=true;try{ await connection.Poll(); }catch(Exception error){Post(Json.Obj("event","state","status","disconnected","message",error.Message));}finally{ polling=false; } };
            poll.Start();
        } catch(Exception e) {
            MessageBox.Show(
                "برنامه آماده نشد. اگر WebView2 نصب نیست، Microsoft Edge WebView2 Runtime را نصب کن.\n\n"+e.Message,
                "Vyrax",MessageBoxButtons.OK,MessageBoxIcon.Warning);
            quitting=true;Close();
        }
    }

    void BuildTray() {
        Icon icon=null;
        try { icon=System.Drawing.Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }
        if(icon==null)icon=SystemIcons.Application;
        var menu=new ContextMenuStrip();
        menu.Items.Add("باز کردن Vyrax",null,(s,e)=>Restore());
        menu.Items.Add("قطع اتصال",null,async(s,e)=>await connection.Disconnect());
        menu.Items.Add("خروج",null,async(s,e)=>await Quit());
        tray=new NotifyIcon{Icon=icon,Text="Vyrax",ContextMenuStrip=menu,Visible=true};
        tray.DoubleClick+=(s,e)=>Restore();
        Icon=icon;
    }

    void Restore() { Show();WindowState=FormWindowState.Normal;Activate();hiddenToTray=false; }

    void Post(object value) {
        if(IsDisposed||view==null||view.CoreWebView2==null)return;
        if(InvokeRequired){ BeginInvoke(new Action<object>(Post),value);return; }
        view.CoreWebView2.PostWebMessageAsJson(Json.Write(value));
    }

    async void Message(object sender,CoreWebView2WebMessageReceivedEventArgs e) {
        if(!e.Source.StartsWith("https://vyrax.local/",StringComparison.OrdinalIgnoreCase))return;
        object id=null;
        try {
            var message=Json.Read(e.WebMessageAsJson);
            id=message["id"];
            var action=Json.Str(message,"action");
            var args=message.ContainsKey("args")&&message["args"]!=null
                ? (Dictionary<string,object>)message["args"]
                : new Dictionary<string,object>();
            object result;
            switch(action) {
                case "load": result=store.Load();break;
                case "save": Preferences.Validate(args.ContainsKey("settings")?args["settings"] as Dictionary<string,object>:null);store.Save(args);connection.Update(args.ContainsKey("settings")?args["settings"] as Dictionary<string,object>:null);result=true;break;
                case "ready": await connection.Start(store.Load());result=connection.Snapshot();break;
                case "status": result=connection.Snapshot();break;
                case "checkUpdates": result=await AppUpdates.Latest();break;
                case "openProjectLink": AppUpdates.Open(Json.Str(args,"target"));result=true;break;
                case "validateSettings": Preferences.Validate(args);result=Json.Obj("splitAddresses",Preferences.Addresses(args,"splitAddresses"),"bypassAddresses",Preferences.Addresses(args,"bypassAddresses"));break;
                case "connect": result=await connection.Connect((Dictionary<string,object>)args["profile"],args.ContainsKey("settings")?(Dictionary<string,object>)args["settings"]:Json.Obj("preferencesVersion",1,"mode",Json.Str(args,"mode","proxy"),"mtu",Json.Int(args,"mtu",1280)));break;
                case "disconnect": result=await connection.Disconnect();break;
                case "select": result=await connection.Select(Json.Items(args["profiles"]).OfType<Dictionary<string,object>>().ToArray(),Json.Str(args,"selectedId"),Json.Str(args,"selectionMode","manual"),Json.Str(args,"activeSourceId"));break;
                case "subscription": result=await Engine.Fetch(Json.Str(args,"url"));break;
                case "ping": result=await Engine.Ping((Dictionary<string,object>)args["profile"]);break;
                /* «تأخیر واقعی»: از داخل خود کانفیگ یک درخواست می‌رود */
                case "delay": result=await Engine.RealDelay((Dictionary<string,object>)args["profile"],Path.Combine(baseDir,"cores"));break;
                case "geo": {
                    var list=(args.ContainsKey("hosts")&&args["hosts"]!=null)
                        ? Json.Items(args["hosts"]).Select(x=>Convert.ToString(x)).ToArray()
                        : new string[0];
                    result=await Engine.GeoLookup(geo,list);break;
                }
                case "clipboard": result=Clipboard.ContainsText()?Clipboard.GetText():"";break;
                case "copy": {var text=Json.Str(args,"text");if(text.Length>4*1024*1024)throw new Exception("err.tooBig");Clipboard.SetText(text);result=true;break;}
                case "file":
                    using(var dialog=new OpenFileDialog{Filter="Config files|*.txt;*.json;*.yaml;*.yml|All files|*.*"}) {
                        if(dialog.ShowDialog(this)!=DialogResult.OK)result=null;
                        else {
                            if(new FileInfo(dialog.FileName).Length>4*1024*1024)throw new Exception("err.tooBig");
                            result=File.ReadAllText(dialog.FileName,Encoding.UTF8);
                        }
                    }
                    break;
                case "minimize": WindowState=FormWindowState.Minimized;result=true;break;
                case "close": result=true;BeginInvoke(new Action(HideToTray));break;
                case "drag": ReleaseCapture();SendMessage(Handle,0xA1,(IntPtr)0x2,IntPtr.Zero);result=true;break;
                default: throw new Exception("err.action");
            }
            Post(Json.Obj("id",id,"result",result));
        } catch(Exception ex) {
            Post(Json.Obj("id",id,"error",ex.Message));
        }
    }

    void HideToTray() {
        Hide();
        if(!hiddenToTray&&tray!=null){
            tray.ShowBalloonTip(1800,"Vyrax","برنامه کنار ساعت ویندوز باز می‌ماند. برای خروج، از منوی آن استفاده کن.",ToolTipIcon.Info);
            hiddenToTray=true;
        }
    }

    async Task Quit() {
        if(quitting)return;
        quitting=true;
        if(connection!=null)await connection.Disconnect();
        Close();
    }

    void HandleClosing(object sender,FormClosingEventArgs e) {
        if(!quitting&&e.CloseReason==CloseReason.UserClosing){ e.Cancel=true;HideToTray();return; }
        quitting=true;
        if(poll!=null)poll.Stop();
        if(engine!=null)engine.Dispose();
        if(geo!=null)geo.Dispose();
        if(tray!=null)tray.Dispose();
        if(view!=null)view.Dispose();
    }
}

public static class Program {
    [STAThread]
    public static void Main(string[] args) {
        bool created;
        using(var mutex=new Mutex(true,@"Local\Vyrax-"+System.Security.Principal.WindowsIdentity.GetCurrent().User.Value+"-"+Process.GetCurrentProcess().Id,out created)) {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }
    }
}
}
