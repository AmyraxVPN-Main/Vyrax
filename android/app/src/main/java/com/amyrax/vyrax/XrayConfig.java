package com.amyrax.vyrax;

import org.json.JSONArray;
import org.json.JSONObject;

final class XrayConfig {
    static final String PROBE_URL="https://www.gstatic.com/generate_204";
    static void validate(JSONObject p){
        String protocol=p.optString("protocol"),transport=p.optString("transport","tcp"),host=p.optString("host");
        if(!java.util.Arrays.asList("vless","vmess","trojan","shadowsocks","firefox").contains(protocol)||
           !java.util.Arrays.asList("tcp","ws","grpc","httpupgrade","xhttp").contains(transport)||
           host.isEmpty()||host.length()>253||host.matches(".*[\\s/\\\\@].*")||p.optInt("port")<1||p.optInt("port")>65535)throw new IllegalArgumentException("err.config");
        if((protocol.equals("vless")||protocol.equals("vmess"))&&!p.optString("uuid").matches("[a-fA-F0-9]{8}-(?:[a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}"))throw new IllegalArgumentException("err.config");
        if((protocol.equals("trojan")||protocol.equals("shadowsocks"))&&p.optString("password").isEmpty())throw new IllegalArgumentException("err.config");
        if(protocol.equals("firefox")&&(!p.optString("sourceId").equals("vyrax-firefox-free")||!host.matches("(?i)[a-z0-9]+(?:[.-][a-z0-9]+)*\\.fastly-masque\\.net")))throw new IllegalArgumentException("err.freeServer");
    }
    static JSONObject outbound(JSONObject p,String tag){
        validate(p);String protocol=p.optString("protocol"),host=p.optString("host"),transport=p.optString("transport","tcp");
        if(protocol.equals("firefox")){
            String pass=p.optString("proxyPass");if(pass.isEmpty()||pass.length()>16384||pass.matches(".*[\\s\\x00-\\x1f].*"))throw new IllegalArgumentException("err.freeAuth");
            return Jsons.obj("tag",tag,"protocol","http","settings",Jsons.obj("servers",Jsons.arr(Jsons.obj("address",host,"port",p.optInt("port"))),"headers",Jsons.obj("Proxy-Authorization","Bearer "+pass)),"streamSettings",Jsons.obj("network","tcp","security","tls","tlsSettings",Jsons.obj("serverName",host,"allowInsecure",false,"alpn",Jsons.arr("h2"))));
        }
        JSONObject user,settings;
        if(protocol.equals("vless")||protocol.equals("vmess")){
            user=Jsons.obj("id",p.optString("uuid"));
            if(protocol.equals("vless")){user=Jsons.obj("id",p.optString("uuid"),"encryption","none");if(!p.optString("flow").isEmpty())put(user,"flow",p.optString("flow"));}
            else{put(user,"security",p.optString("cipher","auto"));put(user,"alterId",p.optInt("alterId"));}
            settings=Jsons.obj("vnext",Jsons.arr(Jsons.obj("address",host,"port",p.optInt("port"),"users",Jsons.arr(user))));
        }else{
            JSONObject server=Jsons.obj("address",host,"port",p.optInt("port"),"password",p.optString("password"));
            if(protocol.equals("shadowsocks"))put(server,"method",p.optString("method","aes-256-gcm"));
            settings=Jsons.obj("servers",Jsons.arr(server));
        }
        JSONObject stream=Jsons.obj("network",transport,"security",p.optBoolean("reality")?"reality":p.optBoolean("tls")?"tls":"none");
        if(p.optBoolean("tls")){
            JSONObject tls=Jsons.obj("serverName",p.optString("sni").isEmpty()?host:p.optString("sni"),"allowInsecure",p.optBoolean("insecure"));
            if(!p.optString("alpn").isEmpty())put(tls,"alpn",new JSONArray(java.util.Arrays.asList(p.optString("alpn").split(","))));
            if(!p.optString("fingerprint").isEmpty())put(tls,"fingerprint",p.optString("fingerprint"));
            put(stream,"tlsSettings",tls);
        }
        if(p.optBoolean("reality"))put(stream,"realitySettings",Jsons.obj("serverName",p.optString("sni"),"fingerprint",p.optString("fingerprint").isEmpty()?"chrome":p.optString("fingerprint"),"password",p.optString("publicKey"),"publicKey",p.optString("publicKey"),"shortId",p.optString("shortId")));
        if(transport.equals("ws"))put(stream,"wsSettings",Jsons.obj("path",p.optString("path","/"),"headers",p.optString("wsHost").isEmpty()?new JSONObject():Jsons.obj("Host",p.optString("wsHost"))));
        if(transport.equals("grpc"))put(stream,"grpcSettings",Jsons.obj("serviceName",p.optString("serviceName"),"multiMode",false));
        if(transport.equals("httpupgrade"))put(stream,"httpupgradeSettings",Jsons.obj("path",p.optString("path","/"),"host",p.optString("wsHost")));
        if(transport.equals("xhttp"))put(stream,"xhttpSettings",Jsons.obj("path",p.optString("path","/"),"host",p.optString("wsHost"),"mode",p.optString("mode","auto")));
        return Jsons.obj("tag",tag,"protocol",protocol,"settings",settings,"streamSettings",stream);
    }
    static JSONObject build(JSONObject p,JSONObject raw,int socks,int http,int share){
        JSONObject options=Preferences.normalize(raw);String mode=options.optString("_selection","manual");
        if(!java.util.Arrays.asList("manual","fastest","balance").contains(mode))throw new IllegalArgumentException("err.config");
        JSONArray outbounds=new JSONArray(),nodes=new JSONArray();String fallback="";
        JSONArray catalog=Jsons.array(options,"_catalog");String source=options.optString("_source");
        if(!mode.equals("manual"))for(int i=0;i<catalog.length();i++){
            JSONObject item=catalog.optJSONObject(i);if(item==null||!item.optString("sourceId").equals(source))continue;
            String tag="node-"+i;outbounds.put(outbound(item,tag));nodes.put(tag);
            if(item.optString("id").equals(p.optString("id")))fallback=tag;
            if(nodes.length()>256)throw new IllegalArgumentException("err.tooBig");
        }
        if(nodes.length()==0){mode="manual";outbounds.put(outbound(p,"proxy"));}
        outbounds.put(Jsons.obj("tag","direct","protocol","freedom"));
        JSONArray inbounds=new JSONArray();
        if(socks>0)inbounds.put(inbound("socks",socks,"socks",Jsons.obj("auth","noauth","udp",true),"127.0.0.1"));
        if(http>0)inbounds.put(inbound("http",http,"http",new JSONObject(),"127.0.0.1"));
        if(share>0)inbounds.put(inbound("share",share,"http",new JSONObject(),"0.0.0.0"));
        JSONArray rules=new JSONArray();
        // DNS goes through the selected proxy, never through split/bypass fallbacks.
        rules.put(route(Jsons.obj("type","field","port","53"),mode));
        rules.put(Jsons.obj("type","field","ip",Jsons.arr("127.0.0.0/8","10.0.0.0/8","172.16.0.0/12","192.168.0.0/16","::1/128","fc00::/7"),"outboundTag","direct"));
        boolean split=options.optBoolean("splitTunneling"),bypass=options.optBoolean("bypassSites");
        if(split||bypass){
            JSONArray addresses=Preferences.addresses(options,split?"splitAddresses":"bypassAddresses"),ips=new JSONArray(),domains=new JSONArray();
            for(int i=0;i<addresses.length();i++){String value=addresses.optString(i);if(Preferences.isIp(value.split("/")[0]))ips.put(value);else domains.put("domain:"+value);}
            if(ips.length()>0)rules.put(split?route(Jsons.obj("type","field","ip",ips),mode):Jsons.obj("type","field","ip",ips,"outboundTag","direct"));
            if(domains.length()>0)rules.put(split?route(Jsons.obj("type","field","domain",domains),mode):Jsons.obj("type","field","domain",domains,"outboundTag","direct"));
        }
        rules.put(split?Jsons.obj("type","field","network","tcp,udp","outboundTag","direct"):route(Jsons.obj("type","field","network","tcp,udp"),mode));
        JSONObject routing=Jsons.obj("domainStrategy","AsIs","rules",rules);
        JSONObject result=Jsons.obj("log",Jsons.obj("loglevel","none"),"inbounds",inbounds,"outbounds",outbounds,"routing",routing,"stats",new JSONObject(),"policy",Jsons.obj("system",Jsons.obj("statsOutboundUplink",true,"statsOutboundDownlink",true)));
        if(p.optString("protocol").equals("firefox")){
            // The upstream supports TCP CONNECT only. Answer device DNS with DoH
            // through the selected upstream instead of sending UDP to it.
            outbounds.put(Jsons.obj("tag","dns-out","protocol","dns","settings",Jsons.obj("nonIPQuery","drop")));
            JSONArray dnsRules=new JSONArray();dnsRules.put(Jsons.obj("type","field","port","53","outboundTag","dns-out"));dnsRules.put(route(Jsons.obj("type","field","inboundTag",Jsons.arr("dns-remote")),mode));for(int i=0;i<rules.length();i++)dnsRules.put(rules.opt(i));put(routing,"rules",dnsRules);
            put(result,"dns",Jsons.obj("tag","dns-remote","queryStrategy","UseIP","servers",Jsons.arr("https://1.1.1.1/dns-query","https://8.8.8.8/dns-query")));
        }
        if(!mode.equals("manual")){
            JSONObject strategy=Jsons.obj("type",mode.equals("balance")?"leastLoad":"leastPing");
            if(mode.equals("balance"))put(strategy,"settings",Jsons.obj("expected",2));
            put(routing,"balancers",Jsons.arr(Jsons.obj("tag","pool","selector",nodes,"fallbackTag",fallback.isEmpty()?nodes.optString(0):fallback,"strategy",strategy)));
            put(result,"observatory",Jsons.obj("subjectSelector",nodes,"probeURL",PROBE_URL,"probeInterval","30s","enableConcurrency",true));
        }
        return result;
    }
    static JSONObject probe(JSONObject profile,int port){
        // A probe never follows LAN bypass/split rules or allocates traffic stats.
        JSONObject config=build(profile,new JSONObject(),port,0,0);
        config.remove("stats");config.remove("policy");
        put(config,"routing",Jsons.obj("rules",Jsons.arr(Jsons.obj("type","field","network","tcp,udp","outboundTag","proxy"))));
        JSONObject inbound=Jsons.array(config,"inbounds").optJSONObject(0);
        if(inbound!=null)inbound.remove("sniffing");
        return config;
    }
    private static JSONObject inbound(String tag,int port,String protocol,JSONObject settings,String listen){return Jsons.obj("tag",tag,"listen",listen,"port",port,"protocol",protocol,"settings",settings,"sniffing",Jsons.obj("enabled",true,"destOverride",Jsons.arr("http","tls","quic"),"routeOnly",true));}
    private static JSONObject route(JSONObject rule,String mode){put(rule,mode.equals("manual")?"outboundTag":"balancerTag",mode.equals("manual")?"proxy":"pool");return rule;}
    static void put(JSONObject object,String key,Object value){try{object.put(key,value);}catch(Exception error){throw new IllegalArgumentException("err.config");}}
}
