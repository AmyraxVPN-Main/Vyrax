// Test-only services for the unmodified production MainForm.
// This executable cannot access the installed app's store, VPN cores or proxy settings.
using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

namespace Vyrax {
// Shadow the system clipboard only in this test host; copy feedback can be
// exercised without replacing anything the user has copied in Windows.
public static class Clipboard {
    static string text="vless://00000000-0000-4000-8000-000000000001@single.example.test:443?security=tls#Single%20import";
    public static bool ContainsText(){return text.Length>0;}
    public static string GetText(){return text;}
    public static void SetText(string value){text=value;}
}
public sealed class Store {
    public readonly string Root=Path.Combine(Path.GetTempPath(), "Vyrax-window-preview");
    Dictionary<string,object> saved;
    public Dictionary<string,object> Load() { return saved ?? Json.Obj("profiles",new[]{
        Json.Obj("id","preview-de","name","Frankfurt","host","de.example.com","protocol","vless","cc","de","latency",42,"sourceId","sub-a"),
        Json.Obj("id","preview-nl","name","Amsterdam","host","nl.example.com","protocol","vless","cc","nl","latency",54,"sourceId","sub-a"),
        Json.Obj("id","preview-us","name","New York","host","us.example.com","protocol","vless","cc","us","latency",108,"sourceId","sub-b")},
        "selectedId","preview-de","activeSourceId","sub-a","subscriptions",new[]{
        Json.Obj("id","sub-a","name","Subscription","url","https://subscription.example.test/a?token=demo-only","usage",Json.Obj("upload",1073741824L,"download",27917287424L,"total",107374182400L),"updatedAt","2026-10-13T00:00:00Z"),
        Json.Obj("id","sub-b","name","کاربر اصلی","url","https://subscription.example.test/b?token=demo-only","updatedAt","2026-10-12T00:00:00Z")}); }
    public void Save(Dictionary<string,object> value) { saved=value; }
}
public sealed class Geo : IDisposable {
    public Geo(string path) { }
    public void Dispose() { }
}
public static class Config {public static void Validate(Dictionary<string,object> profile) { }}
public static class AppUpdates {
    public static async Task<object> Latest() {
        await Task.Delay(350);
        var path=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"latest-release.fixture.json");
        return File.Exists(path)?Json.Read(File.ReadAllText(path)):Json.Obj("release",null);
    }
    // Only record the button target in the isolated fixture; do not launch a browser.
    public static void Open(string target) { File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"opened-link.fixture.txt"),target); }
}
public sealed class Engine : IDisposable, IConnectionEngine, ISelectionEngine {
    public event Action<object> Changed;
    bool connected;string selectedId="",selectionMode="manual";
    public Engine(Store store,string cores) { }
    public object Snapshot() { return Json.Obj("status",connected?"connected":"disconnected","profileId",selectedId,"selectionMode",selectionMode,"elevated",false,"exit",connected?"198.51.100.42":null); }
    // In-memory display fixture only; no processes, network or proxy changes.
    public Task<object> Connect(Dictionary<string,object> profile,string mode,int mtu,Dictionary<string,object> settings) {
        connected=true;selectedId=Json.Str(profile,"id");selectionMode=Json.Str(settings,"_selection","manual");
        if(Changed!=null) {
            Changed(Json.Obj("event","state","status","connected","profileId",selectedId,"selectionMode",selectionMode,"exit","198.51.100.42"));
            Changed(Json.Obj("event","stats","down",65536000,"up",512000,"downRate",128000,"upRate",3300));
        }
        return Task.FromResult(Snapshot());
    }
    public Task<object> Disconnect() { connected=false;if(Changed!=null)Changed(Json.Obj("event","state","status","disconnected"));return Task.FromResult(Snapshot()); }
    public Task Poll() { return Task.FromResult(true); }
    public Task<object> Select(Dictionary<string,object>[] profiles,string selected,string mode,string source) {
        selectedId=selected;selectionMode=mode;
        var data=Json.Obj("status","connected","profileId",selected,"selectionMode",mode,"switched",true,"exit","198.51.100.42");
        if(Changed!=null){data["event"]="state";Changed(data);}return Task.FromResult<object>(data);
    }
    public static async Task<object> Fetch(string url) {
        // In-memory response matching the provider's generic title + real filename.
        await Task.Delay(900);
        var name=url.Contains("/b?")?"کاربر اصلی":"Amyrax-100GB-V2";
        var text=Json.Write(Json.Obj("outbounds",new[]{Json.Obj("type","vless","tag","Frankfurt","server","de.example.test","server_port",443,"uuid","00000000-0000-4000-8000-000000000001")}));
        return Json.Obj("title","base64:U3Vic2NyaXB0aW9u","disposition","attachment; filename=\""+Uri.EscapeDataString(name)+"\"","text",text,"userInfo","upload=1073741824;download=27917287424;total=107374182400");
    }
    public static Task<object> Ping(Dictionary<string,object> profile) { return Task.FromResult<object>(Json.Obj("latency",42)); }
    public static Task<object> RealDelay(Dictionary<string,object> profile,string root) { return Ping(profile); }
    public static Task<object> GeoLookup(Geo geo,string[] hosts) { return Task.FromResult<object>(new Dictionary<string,object>()); }
    public void Dispose() { }
}
public static class Json {
    public static Dictionary<string,object> Obj(params object[] values) { var result=new Dictionary<string,object>();for(int i=0;i<values.Length;i+=2)result[(string)values[i]]=values[i+1];return result; }
    public static string Write(object value) { return new JavaScriptSerializer().Serialize(value); }
    public static Dictionary<string,object> Read(string value) { return new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(value); }
    public static object[] Items(object value) {var items=value as System.Collections.IEnumerable;var result=new List<object>();if(items!=null&&!(value is string))foreach(var item in items)result.Add(item);return result.ToArray();}
    public static string Str(IDictionary<string,object> value,string key,string fallback="") { return value!=null&&value.ContainsKey(key)?Convert.ToString(value[key]):fallback; }
    public static bool Bool(IDictionary<string,object> value,string key) {return Str(value,key).Equals("true",StringComparison.OrdinalIgnoreCase);}
    public static int Int(IDictionary<string,object> value,string key,int fallback=0) { return value!=null&&value.ContainsKey(key)?Convert.ToInt32(value[key]):fallback; }
}
}
