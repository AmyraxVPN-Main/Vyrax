package com.amyrax.vyrax;

import org.junit.Test;
import static org.junit.Assert.*;
import org.json.JSONArray;
import org.json.JSONObject;

public class ConfigTest {
    @Test public void providerWebProtectionIsDistinctFromEligibility()throws Exception{
        assertEquals("err.freeChallenge",assertThrows(IllegalStateException.class,()->FreeProvider.data(Jsons.obj("status",406,"body",""))).getMessage());
        assertEquals("err.freeEligibility",assertThrows(IllegalStateException.class,()->FreeProvider.data(Jsons.obj("status",403,"body",""))).getMessage());
    }
    @Test public void firefoxConnectUsesAuthenticatedHttp2AndEncryptedDns()throws Exception{
        JSONObject p=Jsons.obj("id","firefox:test","protocol","firefox","sourceId","vyrax-firefox-free","host","test.m1.fastly-masque.net","port",2499,"proxyPass","synthetic-pass");
        JSONObject outbound=XrayConfig.outbound(p,"proxy");assertEquals("http",outbound.getString("protocol"));
        assertEquals("Bearer synthetic-pass",outbound.getJSONObject("settings").getJSONObject("headers").getString("Proxy-Authorization"));
        JSONObject tls=outbound.getJSONObject("streamSettings").getJSONObject("tlsSettings");assertFalse(tls.getBoolean("allowInsecure"));assertEquals("h2",tls.getJSONArray("alpn").getString(0));
        JSONObject config=XrayConfig.build(p,new JSONObject(),1080,1081,0);assertEquals("dns-remote",config.getJSONObject("dns").getString("tag"));
        assertEquals("dns-out",config.getJSONObject("routing").getJSONArray("rules").getJSONObject(0).getString("outboundTag"));
        p.put("host","fastly-masque.net.evil.test");try{XrayConfig.validate(p);fail("Foreign proxy must be rejected");}catch(IllegalArgumentException expected){assertEquals("err.freeServer",expected.getMessage());}
    }
    private JSONObject profile(){return Jsons.obj("id","synthetic","protocol","vless","uuid","00000000-0000-4000-8000-000000000001","host","example.test","port",443,"transport","tcp","tls",true,"sourceId","one");}
    @Test public void allProtocolsAndTransportsBuild()throws Exception{
        for(String protocol:new String[]{"vless","vmess","trojan","shadowsocks"})for(String transport:new String[]{"tcp","ws","grpc","httpupgrade","xhttp"}){
            JSONObject profile=profile();profile.put("protocol",protocol);profile.put("transport",transport);profile.put("password","synthetic-test-only");
            JSONObject outbound=XrayConfig.outbound(profile,"proxy");
            assertEquals(protocol,outbound.getString("protocol"));assertEquals(transport,outbound.getJSONObject("streamSettings").getString("network"));
        }
    }
    @Test public void routingPoolDoesNotIncludeOtherSubscriptions()throws Exception{
        JSONObject a=profile(),b=profile();b.put("sourceId","two");b.put("host","another.example.test");
        JSONObject config=XrayConfig.build(a,Jsons.obj("_catalog",Jsons.arr(a,b),"_source","one","_selection","fastest"),10808,10809,0);
        assertEquals(2,config.getJSONArray("outbounds").length());
        assertEquals("leastPing",config.getJSONObject("routing").getJSONArray("balancers").getJSONObject(0).getJSONObject("strategy").getString("type"));
    }
    @Test public void manualSelectionRemovesAutomaticBalancing()throws Exception{
        JSONObject config=XrayConfig.build(profile(),Jsons.obj("_selection","manual"),10808,10809,0);
        assertFalse(config.has("observatory"));assertFalse(config.getJSONObject("routing").has("balancers"));
        assertEquals("proxy",config.getJSONArray("outbounds").getJSONObject(0).getString("tag"));
    }
    @Test public void automaticFallbackUsesTheChosenHealthyProfile()throws Exception{
        JSONObject dead=profile(),healthy=profile();dead.put("id","dead");healthy.put("id","healthy");
        for(String mode:new String[]{"fastest","balance"}){
            JSONObject config=XrayConfig.build(healthy,Jsons.obj("_catalog",Jsons.arr(dead,healthy),"_source","one","_selection",mode),10808,10809,0);
            assertEquals("node-1",config.getJSONObject("routing").getJSONArray("balancers").getJSONObject(0).getString("fallbackTag"));
        }
    }
    @Test public void realityDefaultsMatchDesktopForMissingAndEmptyFingerprint()throws Exception{
        JSONObject p=profile();p.put("reality",true);p.put("sni","example.test");p.put("publicKey","synthetic-key");
        for(String fingerprint:new String[]{null,"","firefox"}){
            if(fingerprint==null)p.remove("fingerprint");else p.put("fingerprint",fingerprint);
            JSONObject settings=XrayConfig.outbound(p,"proxy").getJSONObject("streamSettings").getJSONObject("realitySettings");
            assertEquals(fingerprint==null||fingerprint.isEmpty()?"chrome":fingerprint,settings.getString("fingerprint"));
            assertEquals("synthetic-key",settings.getString("publicKey"));
        }
    }
    @Test public void firstLaunchUsesTunAndKeepsExplicitMode(){
        assertEquals("tun",Preferences.normalize(null).optString("mode"));
        assertEquals("proxy",Preferences.normalize(Jsons.obj("mode","proxy")).optString("mode"));
    }
    @Test public void delayAlwaysUsesProfileWithoutStatsOrSniffing()throws Exception{
        JSONObject probe=XrayConfig.probe(profile(),12345);
        assertFalse(probe.has("stats"));assertFalse(probe.has("policy"));
        assertFalse(probe.getJSONArray("inbounds").getJSONObject(0).has("sniffing"));
        assertEquals("socks",probe.getJSONArray("inbounds").getJSONObject(0).getString("protocol"));
        assertEquals("proxy",probe.getJSONObject("routing").getJSONArray("rules").getJSONObject(0).getString("outboundTag"));
    }
    @Test public void splitRoutingKeepsDnsInProxy()throws Exception{
        JSONObject config=XrayConfig.build(profile(),Jsons.obj("preferencesVersion",1,"splitTunneling",true,"splitAddresses",Jsons.arr("example.test")),10808,10809,0);
        JSONArray rules=config.getJSONObject("routing").getJSONArray("rules");
        assertEquals("proxy",rules.getJSONObject(0).getString("outboundTag"));assertEquals("53",rules.getJSONObject(0).getString("port"));
        assertEquals("direct",rules.getJSONObject(rules.length()-1).getString("outboundTag"));
    }
    @Test public void proxyListenersAreLocalUnlessShareEnabled()throws Exception{
        JSONArray inbounds=XrayConfig.build(profile(),new JSONObject(),10808,10809,0).getJSONArray("inbounds");
        assertEquals(2,inbounds.length());for(int i=0;i<2;i++)assertEquals("127.0.0.1",inbounds.getJSONObject(i).getString("listen"));
    }
    @Test public void badProfileRejected(){for(JSONObject invalid:new JSONObject[]{Jsons.obj("protocol","vless","host","bad/path","port",443),Jsons.obj("protocol","trojan","host","example.test","port",99999,"password","synthetic")})assertThrows(IllegalArgumentException.class,()->XrayConfig.validate(invalid));}
    @Test public void conflictingAndInvalidRoutesRejected(){
        assertThrows(IllegalArgumentException.class,()->Preferences.normalize(Jsons.obj("preferencesVersion",1,"splitTunneling",true,"bypassSites",true,"splitAddresses",Jsons.arr("example.test"),"bypassAddresses",Jsons.arr("example.test"))));
        assertThrows(IllegalArgumentException.class,()->Preferences.normalize(Jsons.obj("preferencesVersion",1,"splitTunneling",true)));
        assertThrows(IllegalArgumentException.class,()->Preferences.addresses(Jsons.obj("list","https://example.test/path"),"list"));
        assertThrows(IllegalArgumentException.class,()->Preferences.addresses(Jsons.obj("list","10.0.0.1/99"),"list"));
    }
    @Test public void routeNamesNormalizedAndDeduplicated()throws Exception{JSONArray values=Preferences.addresses(Jsons.obj("list","*.EXAMPLE.test\nexample.test\n203.0.113.0/24"),"list");assertEquals(2,values.length());assertEquals("example.test",values.getString(0));}
}
