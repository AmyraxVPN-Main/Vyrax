using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;

namespace Vyrax {
/* تبدیل JSON و ساخت کانفیگ هستهٔ Xray.
   پیام‌های خطا «کلید» هستند تا رابط بتواند ترجمه‌شان کند. */
public static class Json {
    public static readonly JavaScriptSerializer Serializer = new JavaScriptSerializer { MaxJsonLength = 8 * 1024 * 1024 };
    public static string Write(object value) { return Serializer.Serialize(value); }
    public static Dictionary<string,object> Read(string value) { return Serializer.Deserialize<Dictionary<string,object>>(value); }
    public static object[] Items(object value) {var items=value as System.Collections.IEnumerable;return items==null||value is string?new object[0]:items.Cast<object>().ToArray();}
    public static string Str(IDictionary<string,object> d,string key,string fallback="") { object v;return d!=null&&d.TryGetValue(key,out v)&&v!=null?Convert.ToString(v,CultureInfo.InvariantCulture):fallback; }
    public static bool Bool(IDictionary<string,object> d,string key) { var s=Str(d,key);return s.Equals("true",StringComparison.OrdinalIgnoreCase)||s=="1"; }
    public static int Int(IDictionary<string,object> d,string key,int fallback=0) { int v;return int.TryParse(Str(d,key),out v)?v:fallback; }
    public static Dictionary<string,object> Obj(params object[] pairs) { var d=new Dictionary<string,object>();for(int i=0;i+1<pairs.Length;i+=2)d[(string)pairs[i]]=pairs[i+1];return d; }
}

public static class Config {
    static readonly string[] Protocols = {"vless","vmess","trojan","shadowsocks"};
    static readonly string[] Transports = {"tcp","ws","grpc","httpupgrade","xhttp"};
    static readonly string[] Bounded = {"name","password","uuid","path","wsHost","serviceName","sni","publicKey","shortId","flow","fingerprint"};

    public static void Validate(Dictionary<string,object> p) {
        var protocol=Json.Str(p,"protocol");var transport=Json.Str(p,"transport","tcp");
        if(!Protocols.Contains(protocol))throw new Exception("err.protocol");
        if(!Transports.Contains(transport))throw new Exception("err.transport");
        var host=Json.Str(p,"host");
        if(host.Length==0||host.Length>253||Regex.IsMatch(host,@"[\s/\\@?#\x00-\x1f]"))throw new Exception("err.host");
        var port=Json.Int(p,"port");if(port<1||port>65535)throw new Exception("err.port");
        Guid parsed;
        if((protocol=="vless"||protocol=="vmess")&&!Guid.TryParse(Json.Str(p,"uuid"),out parsed))throw new Exception("err.uuid");
        if((protocol=="trojan"||protocol=="shadowsocks")&&String.IsNullOrEmpty(Json.Str(p,"password")))throw new Exception("err.password");
        if(Json.Bool(p,"reality")&&(Json.Str(p,"publicKey").Length==0||Json.Str(p,"sni").Length==0))throw new Exception("err.reality");
        foreach(var field in Bounded)if(Json.Str(p,field).Length>4096)throw new Exception("err.tooLong");
    }

    public static object Outbound(Dictionary<string,object> p,string networkInterface=null) {
        Validate(p);
        var protocol=Json.Str(p,"protocol");var transport=Json.Str(p,"transport","tcp");
        var host=Json.Str(p,"host");var port=Json.Int(p,"port");
        object settings;
        if(protocol=="vless"||protocol=="vmess") {
            var user=Json.Obj("id",Json.Str(p,"uuid"));
            if(protocol=="vless") { user["encryption"]="none";if(Json.Str(p,"flow").Length>0)user["flow"]=Json.Str(p,"flow"); }
            else { user["security"]=Json.Str(p,"cipher","auto");user["alterId"]=Json.Int(p,"alterId"); }
            settings=Json.Obj("vnext",new[]{Json.Obj("address",host,"port",port,"users",new[]{user})});
        } else {
            var server=Json.Obj("address",host,"port",port,"password",Json.Str(p,"password"));
            if(protocol=="shadowsocks")server["method"]=Json.Str(p,"method","aes-256-gcm");
            settings=Json.Obj("servers",new[]{server});
        }
        var stream=Json.Obj("network",transport,"security",Json.Bool(p,"reality")?"reality":Json.Bool(p,"tls")?"tls":"none");
        // Resolve the transport server with Xray's bootstrap DNS, then bind its
        // sockets to the captured uplink. Windows system DNS enters TUN after
        // auto_route starts and would otherwise depend on this same transport.
        if(!String.IsNullOrEmpty(networkInterface))stream["sockopt"]=Json.Obj("interface",networkInterface,"domainStrategy","ForceIPv4v6");
        if(Json.Bool(p,"tls")) {
            var tls=Json.Obj("serverName",Json.Str(p,"sni",host),"allowInsecure",Json.Bool(p,"insecure"));
            if(Json.Str(p,"sni").Length==0)tls["serverName"]=host;
            if(Json.Str(p,"alpn").Length>0)tls["alpn"]=Json.Str(p,"alpn").Split(',');
            if(Json.Str(p,"fingerprint").Length>0)tls["fingerprint"]=Json.Str(p,"fingerprint");
            stream["tlsSettings"]=tls;
        }
        if(Json.Bool(p,"reality"))stream["realitySettings"]=Json.Obj("serverName",Json.Str(p,"sni"),"fingerprint",Json.Str(p,"fingerprint").Length==0?"chrome":Json.Str(p,"fingerprint"),"password",Json.Str(p,"publicKey"),"publicKey",Json.Str(p,"publicKey"),"shortId",Json.Str(p,"shortId"));
        if(transport=="ws")stream["wsSettings"]=Json.Obj("path",Json.Str(p,"path","/"),"headers",Json.Str(p,"wsHost").Length==0?Json.Obj():Json.Obj("Host",Json.Str(p,"wsHost")));
        if(transport=="httpupgrade")stream["httpupgradeSettings"]=Json.Obj("path",Json.Str(p,"path","/"),"host",Json.Str(p,"wsHost"));
        if(transport=="grpc")stream["grpcSettings"]=Json.Obj("serviceName",Json.Str(p,"serviceName"),"multiMode",false);
        if(transport=="xhttp")stream["xhttpSettings"]=Json.Obj("path",Json.Str(p,"path","/"),"host",Json.Str(p,"wsHost"),"mode",Json.Str(p,"mode","auto"));
        return Json.Obj("tag","proxy","protocol",protocol,"settings",settings,"streamSettings",stream);
    }

    public static object Xray(Dictionary<string,object> p,int socks,int http,int metrics,Dictionary<string,object> options=null,int probe=0,int share=0,string networkInterface=null,string[] bootstrapDns=null,int subscription=0) {
        Preferences.Validate(options);
        var bootstrap=!String.IsNullOrEmpty(networkInterface)&&bootstrapDns!=null;
        if(!bootstrap)networkInterface=null;
        var inbounds=new List<object>{
            Json.Obj("tag","socks","listen","127.0.0.1","port",socks,"protocol","socks","settings",Json.Obj("auth","noauth","udp",true)),
            Json.Obj("tag","http","listen","127.0.0.1","port",http,"protocol","http","settings",Json.Obj())};
        if(share>0)inbounds.Add(Json.Obj("tag","share","listen","0.0.0.0","port",share,"protocol","http","settings",Json.Obj()));
        foreach(Dictionary<string,object> inbound in inbounds)inbound["sniffing"]=Json.Obj("enabled",true,"destOverride",new[]{"http","tls","quic"},"routeOnly",true);
        if(probe>0)inbounds.Add(Json.Obj("tag","probe","listen","127.0.0.1","port",probe,"protocol","http","settings",Json.Obj()));
        if(subscription>0)inbounds.Add(Json.Obj("tag","subscription","listen","127.0.0.1","port",subscription,"protocol","http","settings",Json.Obj()));
        var rules=new List<object>();
        if(subscription>0)rules.Add(Json.Obj("type","field","inboundTag",new[]{"subscription"},"outboundTag","direct"));
        // This tag belongs to internal transport-server lookups only. Send them
        // straight to the uplink DNS, ahead of the VPN and split/bypass rules.
        if(bootstrap)rules.Add(Json.Obj("type","field","inboundTag",new[]{"dns-bootstrap"},"outboundTag","bootstrap-direct"));
        // Probes must verify the proxy even when the split list excludes them.
        if(probe>0)rules.Add(Json.Obj("type","field","inboundTag",new[]{"probe"},"outboundTag","proxy"));
        rules.Add(Json.Obj("type","field","ip",new[]{"127.0.0.0/8","10.0.0.0/8","172.16.0.0/12","192.168.0.0/16","::1/128","fc00::/7"},"outboundTag","direct"));
        var split=Json.Bool(options,"splitTunneling");var bypass=Json.Bool(options,"bypassSites");
        if(split||bypass) {
            var addresses=Preferences.Addresses(options,split?"splitAddresses":"bypassAddresses");
            var domains=addresses.Where(x=>!Preferences.IsIp(x)).Select(x=>"domain:"+x).ToArray();
            var ips=addresses.Where(Preferences.IsIp).ToArray();
            var target=split?"proxy":"direct";
            if(domains.Length>0)rules.Add(Json.Obj("type","field","domain",domains,"outboundTag",target));
            if(ips.Length>0)rules.Add(Json.Obj("type","field","ip",ips,"outboundTag",target));
            if(split)rules.Add(Json.Obj("type","field","network","tcp,udp","outboundTag","direct"));
        }
        var direct=Json.Obj("tag","direct","protocol","freedom");
        var outbounds=new List<object>{Outbound(p,networkInterface),direct};
        if(bootstrap) {
            var binding=Json.Obj("sockopt",Json.Obj("interface",networkInterface));
            direct["streamSettings"]=binding;
            outbounds.Add(Json.Obj("tag","bootstrap-direct","protocol","freedom","streamSettings",binding));
        }
        var result=Json.Obj("log",Json.Obj("loglevel",bootstrap?"warning":"none"),"inbounds",inbounds,
            "outbounds",outbounds,
            "routing",Json.Obj("domainStrategy","AsIs","rules",rules),
            "stats",Json.Obj(),"policy",Json.Obj("system",Json.Obj("statsOutboundUplink",true,"statsOutboundDownlink",true)),
            "metrics",Json.Obj("tag","metrics","listen","127.0.0.1:"+metrics));
        // Some networks advertise a DNS server that times out or returns no
        // records for transport domains. Race it with HTTPS resolvers;
        // never fall back to Windows DNS once TUN owns the default route.
        if(bootstrap)result["dns"]=Json.Obj("tag","dns-bootstrap","queryStrategy","UseIP","enableParallelQuery",true,
            "servers",bootstrapDns.Concat(new[]{"https://1.1.1.1/dns-query","https://8.8.8.8/dns-query"}).Distinct().Select(address=>Json.Obj("address",address,"timeoutMs",4000)).ToArray());
        return result;
    }

    public static object Tun(int socks,int mtu) {
        if(mtu<1280||mtu>1500)mtu=1280;
        /* level=info و نه error: تصمیم‌های ساختِ رابط و مسیرها همین‌جا نوشته می‌شوند و
           اگر روزی تونل بالا نیامد، همین خطوط تنها سرنخ ما هستند. خروجی جایی جز
           حافظهٔ خودِ برنامه نوشته نمی‌شود و Engine فقط سر و دُمِ آن را نگه می‌دارد. */
        return Json.Obj("log",Json.Obj("level","info"),
            "dns",Json.Obj("servers",new[]{Json.Obj("type","https","tag","remote-dns","server","1.1.1.1","server_port",443,"path","/dns-query","detour","proxy")},"final","remote-dns","strategy","ipv4_only"),
            "inbounds",new[]{Json.Obj("type","tun","tag","tun-in","interface_name","Vyrax","address",new[]{"172.28.0.1/30"},"mtu",mtu,"auto_route",true,"strict_route",true,"stack","mixed")},
            "outbounds",new[]{Json.Obj("type","socks","tag","proxy","server","127.0.0.1","server_port",socks,"version","5"),Json.Obj("type","direct","tag","direct")},
            // Only the transport cores bypass the tunnel to prevent routing loops.
            // Vyrax.exe must use the tunnel too: it performs the bound TLS probe.
            "route",Json.Obj("auto_detect_interface",true,"rules",new[]{Json.Obj("process_name",new[]{"xray.exe","sing-box.exe"},"action","route","outbound","direct"),Json.Obj("protocol","dns","action","hijack-dns"),Json.Obj("ip_is_private",true,"action","route","outbound","direct")},"final","proxy"));
    }
}
}
