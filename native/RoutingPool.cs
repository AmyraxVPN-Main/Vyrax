using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Vyrax {
// Routing changes affect new flows. Existing outbound handlers stay alive until
// disconnect, so their TCP/TLS streams are never killed by a selection change.
public sealed class RoutingPool {
    readonly Dictionary<string,Dictionary<string,object>> nodes=new Dictionary<string,Dictionary<string,object>>();
    readonly HashSet<string> installed=new HashSet<string>();
    readonly Dictionary<string,object>[] baseRules;
    readonly object[] auxiliaryOutbounds;
    readonly string networkInterface;
    readonly string exe,folder;
    readonly int api;
    int revision;
    public int Version {get{return revision;}}
    public string Mode {get;private set;}
    public string Source {get;private set;}
    public string SelectedId {get;private set;}
    string balancer;
    public Dictionary<string,object> Profile(string id) {Dictionary<string,object> profile;return nodes.TryGetValue(id,out profile)?profile:null;}
    public RoutingPool(Dictionary<string,object> config,string core,string directory,int port) {
        exe=core;folder=directory;api=port;
        var routing=(Dictionary<string,object>)config["routing"];
        var outbounds=Json.Items(config["outbounds"]).Cast<Dictionary<string,object>>().ToArray();
        var proxy=outbounds.First(outbound=>Json.Str(outbound,"tag")=="proxy");
        object value;var stream=proxy.TryGetValue("streamSettings",out value)?value as Dictionary<string,object>:null;
        var sockopt=stream!=null&&stream.TryGetValue("sockopt",out value)?value as Dictionary<string,object>:null;
        networkInterface=Json.Str(sockopt,"interface");
        auxiliaryOutbounds=outbounds.Where(outbound=>Json.Str(outbound,"tag")!="proxy").Cast<object>().ToArray();
        baseRules=((List<object>)routing["rules"]).Cast<Dictionary<string,object>>().Concat(new[]{Json.Obj("type","field","network","tcp,udp","outboundTag","proxy")}).ToArray();
    }
    static string Hash(string value) {using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(Encoding.UTF8.GetBytes(value))).Replace("-","").ToLowerInvariant().Substring(0,24);}
    public static string Tag(Dictionary<string,object> profile,string networkInterface=null) {return "node-"+Hash(Json.Str(profile,"id")+Json.Write(Config.Outbound(profile,networkInterface)));}
    string NodeTag(Dictionary<string,object> profile) {return Tag(profile,networkInterface);}
    public static Dictionary<string,object>[] Catalog(IDictionary<string,object> settings,Dictionary<string,object> fallback) {
        object raw;var list=settings!=null&&settings.TryGetValue("_catalog",out raw)?Json.Items(raw):null;
        var entries=list==null?new[]{fallback}:list.OfType<Dictionary<string,object>>().ToArray();
        if(entries.Length==0||entries.Length>512)throw new Exception("err.catalog");
        foreach(var p in entries){Config.Validate(p);if(String.IsNullOrEmpty(Json.Str(p,"id")))throw new Exception("err.catalog");}
        if(entries.Select(p=>Json.Str(p,"id")).Distinct().Count()!=entries.Length)throw new Exception("err.catalog");
        return entries;
    }
    public static void ValidateMode(string mode) {if(mode!="manual"&&mode!="fastest"&&mode!="balance")throw new Exception("err.selection");}
    public void Build(Dictionary<string,object> config,Dictionary<string,object>[] profiles,string selected,string mode,string source) {
        ValidateMode(mode);foreach(var p in profiles)nodes[Json.Str(p,"id")]=p;
        var outbounds=new List<object>();
        foreach(var p in profiles){var outbound=(Dictionary<string,object>)Config.Outbound(p,networkInterface);outbound["tag"]=NodeTag(p);installed.Add(NodeTag(p));outbounds.Add(outbound);}
        outbounds.AddRange(auxiliaryOutbounds);
        config["outbounds"]=outbounds;
        config["api"]=Json.Obj("tag","api","listen","127.0.0.1:"+api,"services",new[]{"RoutingService","HandlerService"});
        config["observatory"]=Json.Obj("subjectSelector",new[]{"node-"},"probeURL",DelayProbe.TestUrl,"probeInterval","45s","enableConcurrency",true);
        config["routing"]=Routing(selected,mode,source,true);
        Mode=mode;Source=source;
    }
    Dictionary<string,object> Routing(string selected,string mode,string source,bool includeBalancers) {
        ValidateMode(mode);
        var scoped=nodes.Values.Where(p=>Json.Str(p,"sourceId")==source).ToArray();
        if(scoped.Length==0)throw new Exception("err.noSourceServers");
        Dictionary<string,object> chosen;
        if(!nodes.TryGetValue(selected,out chosen)||Json.Str(chosen,"sourceId")!=source)chosen=scoped.OrderBy(p=>Json.Int(p,"latency",Int32.MaxValue)).First();
        SelectedId=Json.Str(chosen,"id");
        var fast="fast-"+revision;var balanced="balance-"+revision;
        balancer=mode=="balance"?balanced:fast;
        var rules=baseRules.Select(rule=>new Dictionary<string,object>(rule)).ToArray();
        foreach(var rule in rules)if(Json.Str(rule,"outboundTag")=="proxy") {
            rule.Remove("outboundTag");
            if(mode=="manual")rule["outboundTag"]=NodeTag(chosen);else rule["balancerTag"]=balancer;
        }
        var result=Json.Obj("domainStrategy","AsIs","rules",rules);
        if(includeBalancers)result["balancers"]=new[]{
            Json.Obj("tag",fast,"selector",scoped.Select(NodeTag).ToArray(),"fallbackTag",NodeTag(chosen),"strategy",Json.Obj("type","leastPing")),
            Json.Obj("tag",balanced,"selector",scoped.Select(NodeTag).ToArray(),"fallbackTag",NodeTag(chosen),"strategy",Json.Obj("type","leastLoad","settings",Json.Obj("expected",2)))
        };
        return result;
    }
    public async Task Select(Dictionary<string,object>[] profiles,string selected,string mode,string source,CancellationToken token) {
        ValidateMode(mode);
        token.ThrowIfCancellationRequested();
        if(profiles.Length==0||profiles.Length>512)throw new Exception("err.catalog");
        if(profiles.Select(p=>Json.Str(p,"id")).Distinct().Count()!=profiles.Length)throw new Exception("err.catalog");
        var additions=new List<object>();
        foreach(var p in profiles){Config.Validate(p);var tag=NodeTag(p);if(!installed.Contains(tag)){var outbound=(Dictionary<string,object>)Config.Outbound(p,networkInterface);outbound["tag"]=tag;additions.Add(outbound);}}
        if(installed.Count+additions.Count>2048)throw new Exception("err.poolFull");
        var unchanged=selected==SelectedId&&mode==Mode&&source==Source&&profiles.Length==nodes.Count&&profiles.All(p=>{
            Dictionary<string,object> old;return nodes.TryGetValue(Json.Str(p,"id"),out old)&&NodeTag(old)==NodeTag(p);
        });
        if(unchanged) {
            foreach(var p in profiles)nodes[Json.Str(p,"id")]=p;
            return;
        }
        var previous=nodes.ToArray();var previousBalancer=balancer;var previousId=SelectedId;
        nodes.Clear();foreach(var p in profiles)nodes[Json.Str(p,"id")]=p;
        try {
            revision++;
            var routing=Routing(selected,mode,source,true);
            if(additions.Count>0) {
                var file=Path.Combine(folder,"outbound-update.json");File.WriteAllText(file,Json.Write(Json.Obj("outbounds",additions)),new UTF8Encoding(false));
                await Command("ado \""+file+"\"",token);
                foreach(Dictionary<string,object> outbound in additions)installed.Add(Json.Str(outbound,"tag"));
            }
            var ruleFile=Path.Combine(folder,"routing-update.json");File.WriteAllText(ruleFile,Json.Write(Json.Obj("routing",routing)),new UTF8Encoding(false));
            await Command("adrules \""+ruleFile+"\"",token);
            Mode=mode;Source=source;
        } catch {
            nodes.Clear();foreach(var item in previous)nodes[item.Key]=item.Value;balancer=previousBalancer;SelectedId=previousId;throw;
        }
    }
    internal async Task<string> Command(string arguments,CancellationToken token) {
        return await Task.Run(()=>{
            token.ThrowIfCancellationRequested();
            var split=arguments.IndexOf(' ');var verb=split<0?arguments:arguments.Substring(0,split);var rest=split<0?"":arguments.Substring(split+1);
            var info=new ProcessStartInfo(exe,"api "+verb+" --server=127.0.0.1:"+api+" --timeout=3 "+rest){UseShellExecute=false,CreateNoWindow=true,WindowStyle=ProcessWindowStyle.Hidden,RedirectStandardOutput=true,RedirectStandardError=true};
            using(var p=Process.Start(info))
            using(token.Register(()=>{try{if(!p.HasExited)p.Kill();}catch{}})) {
                var output=p.StandardOutput.ReadToEndAsync();var error=p.StandardError.ReadToEndAsync();
                if(!p.WaitForExit(5000)){try{p.Kill();}catch{}throw new Exception("err.routingUpdate");}
                token.ThrowIfCancellationRequested();
                if(p.ExitCode!=0)throw new Exception("err.routingUpdate");
                return output.GetAwaiter().GetResult();
            }
        },token);
    }
    public async Task<string[]> Targets(CancellationToken token) {
        if(Mode=="manual")return new[]{SelectedId};
        var json=Json.Read(await Command("bi --json "+balancer,token));object raw;
        var b=json.TryGetValue("balancer",out raw)?raw as Dictionary<string,object>:null;
        var target=b!=null&&b.TryGetValue("principleTarget",out raw)?raw as Dictionary<string,object>:null;
        var tags=target!=null&&target.TryGetValue("tag",out raw)?raw as System.Collections.IEnumerable:null;
        if(tags==null)return new string[0];
        return tags.Cast<object>().Select(tag=>nodes.Values.FirstOrDefault(p=>NodeTag(p)==Convert.ToString(tag))).Where(p=>p!=null).Select(p=>Json.Str(p,"id")).ToArray();
    }
}
}
