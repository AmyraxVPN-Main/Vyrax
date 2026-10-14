// SPDX-License-Identifier: MIT
// Guardian protocol adapted from FoxyVPN, Copyright (c) 2026 Vauth.
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Authentication;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
namespace Vyrax {
public sealed class FreeProvider {
    const string ClientId="5882386c6d801776",Scope="profile https://identity.mozilla.com/apps/vpn";
    readonly Store store;readonly SemaphoreSlim gate=new SemaphoreSlim(1,1);
    readonly HttpClient client;Dictionary<string,object> session,state;string pass="";double expiry;
    readonly Func<IWebProxy> controlProxy;
    Dictionary<string,object>[] accounts;
    bool readError;
    static double Now { get {return (DateTime.UtcNow-new DateTime(1970,1,1)).TotalSeconds;} }
    public FreeProvider(string root,HttpClient transport=null,Func<IWebProxy> proxy=null) {
        controlProxy=proxy;
        store=new Store(Path.Combine(root,"firefox"));Dictionary<string,object> saved;try{saved=store.Load();}catch{saved=Json.Obj();readError=true;}object raw;accounts=saved.TryGetValue("accounts",out raw)?Json.Items(raw).OfType<Dictionary<string,object>>().ToArray():Json.Str(saved,"refreshToken").Length>0?new[]{saved}:new Dictionary<string,object>[0];session=accounts.FirstOrDefault(a=>Json.Str(a,"email")==Json.Str(saved,"activeEmail"))??accounts.FirstOrDefault()??Json.Obj();Restore();
        client=transport??new HttpClient(CreateHandler()){Timeout=TimeSpan.FromSeconds(15)};
    }
    internal static HttpClientHandler CreateHandler(IWebProxy proxy=null) {
        // The Framework host otherwise negotiates TLS 1.0. Mozilla requires TLS 1.2.
        // With no Vyrax route, respect the user's system proxy as the updater does.
        return new HttpClientHandler{UseProxy=true,Proxy=proxy,UseCookies=false,AllowAutoRedirect=false,
            AutomaticDecompression=DecompressionMethods.GZip|DecompressionMethods.Deflate,SslProtocols=SslProtocols.Tls12};
    }
    void Restore(){pass="";expiry=0;object q;state=Json.Obj("signedIn",Json.Str(session,"refreshToken").Length>0,"email",Json.Str(session,"email"),"activated",Json.Bool(session,"activated"),"quota",session.TryGetValue("quota",out q)?q:null);}
    object Summary(){var result=new Dictionary<string,object>(state);result["activeEmail"]=Json.Str(session,"email");result["accounts"]=accounts.Select(a=>{var current=Json.Str(a,"email")==Json.Str(session,"email")?state:a;object q;return Json.Obj("email",Json.Str(a,"email"),"activated",Json.Bool(current,"activated"),"quota",current.TryGetValue("quota",out q)?q:null);}).ToArray();return result;}
    void Persist(){if(Json.Str(session,"email").Length>0){session["activated"]=Json.Bool(state,"activated");object q;if(state.TryGetValue("quota",out q))session["quota"]=q;accounts=accounts.Where(a=>Json.Str(a,"email")!=Json.Str(session,"email")).Concat(new[]{session}).ToArray();}store.Save(Json.Obj("accounts",accounts,"activeEmail",Json.Str(session,"email")));}
    static string Endpoint(string name) {
        if(name=="login")return "https://api.accounts.firefox.com/v1/account/login";
        if(name=="verify")return "https://api.accounts.firefox.com/v1/session/verify_code";
        if(name=="oauth")return "https://api.accounts.firefox.com/v1/oauth/token";
        if(name=="servers")return "https://firefox.settings.services.mozilla.com/v1/buckets/main/collections/vpn-serverlist/records";
        if(new[]{"status","activate","token"}.Contains(name))return "https://vpn.mozilla.org/api/v1/fpn/"+name;
        throw new Exception("err.action");
    }
    public async Task<object> Request(Dictionary<string,object> args) {
        var endpoint=Json.Str(args,"endpoint");if(!new[]{"login","verify","oauth","servers"}.Contains(endpoint))throw new Exception("err.action");
        return await Http(endpoint,Json.Str(args,"body"),Json.Str(args,"authorization"));
    }
    async Task<Dictionary<string,object>> Http(string endpoint,string body="",string authorization="") {
        if(body.Length>32768||authorization.Length>32768||authorization.IndexOfAny(new[]{'\r','\n'})>=0)throw new Exception("err.action");
        HttpClient routed=null;
        try {
            var proxy=controlProxy==null?null:controlProxy();
            if(proxy!=null)routed=new HttpClient(CreateHandler(proxy)){Timeout=TimeSpan.FromSeconds(15)};
            using(var stop=new CancellationTokenSource(TimeSpan.FromSeconds(15)))
            using(var request=new HttpRequestMessage(new[]{"login","verify","oauth","activate"}.Contains(endpoint)?HttpMethod.Post:HttpMethod.Get,Endpoint(endpoint))) {
                request.Headers.TryAddWithoutValidation("User-Agent","Vyrax Firefox-compatible client");request.Headers.TryAddWithoutValidation("Accept","application/json");
                if(authorization.Length>0)request.Headers.TryAddWithoutValidation("Authorization",authorization);
                if(request.Method==HttpMethod.Post)request.Content=new StringContent(body,Encoding.UTF8,"application/json");
                using(var response=await (routed??client).SendAsync(request,HttpCompletionOption.ResponseHeadersRead,stop.Token))
                using(var input=await response.Content.ReadAsStreamAsync())
                using(var output=new MemoryStream()) {
                    var buffer=new byte[8192];int n;while((n=await input.ReadAsync(buffer,0,buffer.Length,stop.Token))>0){if(output.Length+n>1048576)throw new Exception("err.tooBig");output.Write(buffer,0,n);}
                    var headers=Json.Obj();foreach(var key in new[]{"x-quota-limit","x-quota-remaining","x-quota-reset"}){IEnumerable<string> values;if(response.Headers.TryGetValues(key,out values))headers[key]=values.FirstOrDefault();}
                    return Json.Obj("status",(int)response.StatusCode,"body",Encoding.UTF8.GetString(output.ToArray()),"headers",headers);
                }
            }
        } catch(Exception e){if(e.Message.StartsWith("err."))throw;throw new Exception("err.freeNetwork");}
        finally{if(routed!=null)routed.Dispose();}
    }
    static Dictionary<string,object> Data(Dictionary<string,object> r) {
        var code=Json.Int(r,"status");if(code==406)throw new Exception("err.freeChallenge");if(code==429)throw new Exception("err.freeQuota");if(code==403)throw new Exception("err.freeEligibility");if(code==401)throw new Exception("err.freeAuth");if(code<200||code>=300)throw new Exception("err.freeService");
        try{return Json.Read(Json.Str(r,"body"));}catch{throw new Exception("err.freeService");}
    }
    static double Number(Dictionary<string,object> data,string key) {double n;return double.TryParse(Json.Str(data,key),System.Globalization.NumberStyles.Float,System.Globalization.CultureInfo.InvariantCulture,out n)?n:0;}
    static void Secret(string value){if(value.Length==0||value.Length>16384||Regex.IsMatch(value,@"[\s\x00-\x1f]"))throw new Exception("err.freeAuth");}
    public async Task<object> Save(Dictionary<string,object> value) {
        await gate.WaitAsync();try{Secret(Json.Str(value,"accessToken"));Secret(Json.Str(value,"refreshToken"));var email=Json.Str(value,"email");if(email.Length==0||email.Length>254||(!accounts.Any(a=>Json.Str(a,"email")==email)&&accounts.Length>=10))throw new Exception("err.freeAccounts");session=Json.Obj("accessToken",Json.Str(value,"accessToken"),"refreshToken",Json.Str(value,"refreshToken"),"expiresAt",Number(value,"expiresAt"),"email",email);Restore();Persist();readError=false;return Summary();}finally{gate.Release();}
    }
    async Task<string> Access() {
        if(Json.Str(session,"refreshToken").Length==0)throw new Exception("err.freeAuth");
        if(Json.Str(session,"accessToken").Length>0&&Number(session,"expiresAt")>Now+60)return Json.Str(session,"accessToken");
        var r=await Http("oauth",Json.Write(Json.Obj("client_id",ClientId,"grant_type","refresh_token","refresh_token",Json.Str(session,"refreshToken"),"scope",Scope)));
        if(new[]{400,401,403}.Contains(Json.Int(r,"status")))throw new Exception("err.freeAuth");
        var d=Data(r);Secret(Json.Str(d,"access_token"));session["accessToken"]=Json.Str(d,"access_token");if(Json.Str(d,"refresh_token").Length>0)session["refreshToken"]=Json.Str(d,"refresh_token");session["expiresAt"]=Now+(Number(d,"expires_in")>0?Number(d,"expires_in"):86400);Persist();return Json.Str(session,"accessToken");
    }
    async Task<Dictionary<string,object>> Authorized(string endpoint) {
        var r=await Http(endpoint,"","Bearer "+await Access());if(Json.Int(r,"status")==401||Json.Int(r,"status")==403){session["expiresAt"]=0;r=await Http(endpoint,"","Bearer "+await Access());}return r;
    }
    void Quota(Dictionary<string,object> r,Dictionary<string,object> data=null) {
        var h=(Dictionary<string,object>)r["headers"];var quota=Json.Obj();
        foreach(var pair in new[]{new[]{"limit","x-quota-limit"},new[]{"remaining","x-quota-remaining"},new[]{"reset","x-quota-reset"}}){var text=Json.Str(h,pair[1]);quota[pair[0]]=Regex.IsMatch(text,@"\A\d+\z")?(object)Number(h,pair[1]):null;}
        if(quota["limit"]==null&&data!=null&&data.ContainsKey("maxBytes"))quota["limit"]=data["maxBytes"];
        object previous;if(quota["limit"]==null&&state.TryGetValue("quota",out previous)&&previous is Dictionary<string,object>){var old=(Dictionary<string,object>)previous;if(old.ContainsKey("limit"))quota["limit"]=old["limit"];}
        state["quota"]=quota;if(data!=null&&data.ContainsKey("subscribed"))state["activated"]=Json.Bool(data,"subscribed");
    }
    void Cache(Dictionary<string,object> r,Dictionary<string,object> d) {
        var value=Json.Str(d,"token");Secret(value);pass=value;expiry=Number(d,"expires_at");
        if(expiry<=Now)try{var encoded=value.Split('.')[1].Replace('-','+').Replace('_','/');expiry=Number(Json.Read(Encoding.UTF8.GetString(Convert.FromBase64String(encoded.PadRight((encoded.Length+3)/4*4,'=')))),"exp");}catch{}
        if(expiry<=Now)expiry=Now+300;Quota(r);state["activated"]=true;
    }
    public async Task<object> Account(string operation) {
        await gate.WaitAsync();try {
            if(operation=="local"){if(readError)throw new Exception("err.freeStorage");return Summary();}
            if(operation!="status"&&operation!="activate")throw new Exception("err.action");
            var r=await Authorized(operation);var d=Data(r);Quota(r,d);
            if(Json.Bool(d,"subscribed")&&operation=="status"){r=await Authorized("token");if(Json.Int(r,"status")==200)Cache(r,Data(r));else if(Json.Int(r,"status")==429){Quota(r);((Dictionary<string,object>)state["quota"])["remaining"]=0;}}
            Persist();return Summary();
        }finally{gate.Release();}
    }
    public async Task<Dictionary<string,object>[]> Resolve(Dictionary<string,object>[] profiles) {
        await gate.WaitAsync();try {
            if(profiles.Any(p=>Json.Str(p,"protocol")=="firefox")) {
                foreach(var p in profiles.Where(p=>Json.Str(p,"protocol")=="firefox"))Config.Validate(p);
                if(pass.Length==0||expiry<=Now+60){var r=await Authorized("token");Cache(r,Data(r));}
            }
            return profiles.Select(p=>{var copy=new Dictionary<string,object>(p);if(Json.Str(p,"protocol")=="firefox")copy["proxyPass"]=pass;return copy;}).ToArray();
        }finally{gate.Release();}
    }
    public async Task<object> Switch(string email){await gate.WaitAsync();try{Persist();var chosen=accounts.FirstOrDefault(a=>Json.Str(a,"email")==email);if(chosen==null)throw new Exception("err.freeAuth");session=chosen;Restore();Persist();return Summary();}finally{gate.Release();}}
    public async Task<object> Logout(){await gate.WaitAsync();try{accounts=accounts.Where(a=>Json.Str(a,"email")!=Json.Str(session,"email")).ToArray();session=accounts.FirstOrDefault()??Json.Obj();Restore();Persist();return Summary();}finally{gate.Release();}}
    public async Task<object> Remove(string email){await gate.WaitAsync();try{accounts=accounts.Where(a=>Json.Str(a,"email")!=email).ToArray();if(email==Json.Str(session,"email")){session=accounts.FirstOrDefault()??Json.Obj();Restore();}Persist();return Summary();}finally{gate.Release();}}
}
}
