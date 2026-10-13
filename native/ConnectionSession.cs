using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Vyrax {
public interface IConnectionEngine {
    event Action<object> Changed;
    object Snapshot();
    Task<object> Connect(Dictionary<string,object> profile,string mode,int mtu,Dictionary<string,object> settings);
    Task<object> Disconnect();
    Task Poll();
}

// Owns user intent independently of a core process. Manual disconnect, cancel,
// shutdown and switching servers invalidate an old attempt, including retries.
public sealed class ConnectionSession {
    readonly IConnectionEngine engine;
    readonly Func<DateTime> now;
    Dictionary<string,object> profile,settings=Json.Obj();
    bool wanted,busy,started,waiting;
    int generation,failures;
    DateTime retryAt;
    public event Action<object> Changed;
    public ConnectionSession(IConnectionEngine value,Func<DateTime> clock=null) { engine=value;now=clock??(()=>DateTime.UtcNow);engine.Changed+=Forward; }
    void Emit(object value) { if(Changed!=null)Changed(value); }
    void Forward(object value) {
        var data=value as Dictionary<string,object>;
        if(data!=null&&Json.Str(data,"event")=="state"&&Json.Str(data,"status")=="disconnected"&&wanted&&!busy&&Json.Bool(settings,"autoReconnect")) {
            Schedule();return;
        }
        if(waiting&&data!=null&&Json.Str(data,"status")=="disconnected")return;
        Emit(value);
    }
    void Schedule() {
        if(waiting)return;
        waiting=true;retryAt=now().AddSeconds(Math.Min(30,2*Math.Pow(2,Math.Min(failures++,4))));
        Emit(Json.Obj("event","state","status","connecting","stage","stage.retry","profileId",Json.Str(profile,"id")));
    }
    public object Snapshot() {
        var snapshot=new Dictionary<string,object>((Dictionary<string,object>)engine.Snapshot());
        if(waiting||busy){snapshot["status"]="connecting";snapshot["stage"]=waiting?"stage.retry":"stage.start";snapshot["profileId"]=Json.Str(profile,"id");}
        return snapshot;
    }
    public void Update(Dictionary<string,object> value) {
        var previous=settings;settings=Preferences.Normalize(value);
        foreach(var key in new[]{"_catalog","_selection","_source"})if(!settings.ContainsKey(key)&&previous.ContainsKey(key))settings[key]=previous[key];
        if(waiting&&!Json.Bool(settings,"autoReconnect")) {waiting=false;wanted=false;Emit(Json.Obj("event","state","status","disconnected"));}
    }
    public async Task Start(Dictionary<string,object> saved) {
        if(started)return;started=true;
        object raw;
        Update(saved.TryGetValue("settings",out raw)?raw as Dictionary<string,object>:null);
        if(!Json.Bool(settings,"autoConnect"))return;
        var profiles=saved.TryGetValue("profiles",out raw)?Json.Items(raw):null;
        if(profiles==null||profiles.Length==0)return;
        var entries=profiles.OfType<Dictionary<string,object>>().ToArray();
        var chosen=entries.FirstOrDefault(p=>Json.Str(p,"id")==Json.Str(saved,"selectedId"))??entries.FirstOrDefault();
        if(chosen==null)return;
        settings["_catalog"]=entries;settings["_selection"]=Json.Str(saved,"selectionMode","manual");settings["_source"]=Json.Str(saved,"activeSourceId",Json.Str(chosen,"sourceId"));
        try { await Connect(chosen,settings); }
        catch(Exception e){Emit(Json.Obj("event","state","status","disconnected","message",e.Message));}
    }
    public async Task<object> Connect(Dictionary<string,object> chosen,Dictionary<string,object> options) {
        Config.Validate(chosen);
        Preferences.Validate(options);
        var current=++generation;wanted=false;waiting=false;
        await engine.Disconnect();
        if(current!=generation)return Snapshot();
        profile=new Dictionary<string,object>(chosen);Update(options);wanted=true;failures=0;
        return await Attempt(current);
    }
    async Task<object> Attempt(int current) {
        busy=true;waiting=false;
        try {
            var result=await engine.Connect(profile,Json.Str(settings,"mode","proxy"),Json.Int(settings,"mtu",1280),settings);
            if(current!=generation)return Snapshot();
            if(Json.Str((Dictionary<string,object>)result,"status")=="connected")failures=0;
            return result;
        } catch(Exception error) {
            if(current==generation&&wanted&&Json.Bool(settings,"autoReconnect")&&Retryable(error)){Schedule();return Snapshot();}
            if(current==generation)wanted=false;
            throw;
        } finally { if(current==generation)busy=false; }
    }
    static bool Retryable(Exception error) {
        return new[]{"err.verify","err.timeout","err.coreFailed","err.coreStopped","err.coreSlow","err.tunnel","err.tunnelTraffic","err.tunBusy","err.portBusy"}.Contains(error.Message);
    }
    public async Task<object> Disconnect() { ++generation;wanted=false;waiting=false;busy=false;return await engine.Disconnect(); }
    public async Task<object> Select(Dictionary<string,object>[] profiles,string selected,string mode,string source) {
        if(busy||waiting)throw new Exception("err.routingUnavailable");
        var current=generation;
        var concrete=engine as ISelectionEngine;if(concrete==null)throw new Exception("err.routingUnavailable");
        var result=await concrete.Select(profiles,selected,mode,source);
        if(current!=generation)return Snapshot();
        profile=profiles.FirstOrDefault(p=>Json.Str(p,"id")==Json.Str((Dictionary<string,object>)result,"profileId"))??profile;
        settings["_catalog"]=profiles;settings["_selection"]=mode;settings["_source"]=source;
        return result;
    }
    public async Task Poll() {
        if(busy)return;
        await engine.Poll();
        if(waiting&&wanted&&Json.Bool(settings,"autoReconnect")&&now()>=retryAt) {
            try { await Attempt(generation); } catch(Exception e) {Emit(Json.Obj("event","state","status","disconnected","message",e.Message));}
        }
    }
}
public interface ISelectionEngine {
    Task<object> Select(Dictionary<string,object>[] profiles,string selected,string mode,string source);
}
}
