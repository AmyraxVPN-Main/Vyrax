package com.amyrax.vyrax;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Test;
import org.junit.runner.RunWith;
import static org.junit.Assert.*;
import org.json.JSONObject;
import libv2ray.Libv2ray;
import libv2ray.CoreCallbackHandler;
import libv2ray.CoreController;

@RunWith(AndroidJUnit4.class)
public class NativeSmokeTest {
    private JSONObject profile(){return Jsons.obj("id","test-only","protocol","vless","uuid","00000000-0000-4000-8000-000000000001","host","127.0.0.1","port",22539,"transport","tcp","sourceId","test-only");}
    @Test public void libraryStartsForAllRoutingModes()throws Exception{
        android.content.Context context=InstrumentationRegistry.getInstrumentation().getTargetContext();
        VpnEngine.get(context).init();assertTrue(Libv2ray.checkVersionX().contains("26.10.10"));
        for(String mode:new String[]{"manual","fastest","balance"}){
            CoreController core=Libv2ray.newCoreController(new CoreCallbackHandler(){public long startup(){return 0;}public long shutdown(){return 0;}public long onEmitStatus(long status,String message){return 0;}});
            JSONObject p=profile(),settings=Jsons.obj("_catalog",Jsons.arr(p),"_selection",mode,"_source","test-only");
            try{core.startLoop(XrayConfig.build(p,settings,VpnEngine.freePort(),VpnEngine.freePort(),0).toString(),0);assertTrue(core.getIsRunning());}
            finally{core.stopLoop();}
        }
    }
    @Test public void encryptedStoreRoundTrip()throws Exception{
        android.content.Context context=InstrumentationRegistry.getInstrumentation().getTargetContext();
        SecureStore store=new SecureStore(context);JSONObject original=store.load();
        try{store.save(Jsons.obj("profiles",Jsons.arr(profile()),"settings",Jsons.obj("preferencesVersion",1,"mode","tun")));assertEquals("test-only",store.load().getJSONArray("profiles").getJSONObject(0).getString("id"));
            byte[] bytes=java.nio.file.Files.readAllBytes(new java.io.File(context.getFilesDir(),"profiles.enc").toPath());assertFalse(new String(bytes,java.nio.charset.StandardCharsets.ISO_8859_1).contains("00000000-0000-4000-8000-000000000001"));}
        finally{store.save(original);}
    }
    @Test public void tunLibraryLoads(){assertFalse(hev.htproxy.TProxyService.TProxyIsRunning());assertEquals(4,hev.htproxy.TProxyService.TProxyGetStats().length);}
    @Test public void urlDelayReusesTunnelAndRejectsHttpErrors()throws Exception{
        VpnEngine engine=VpnEngine.get(InstrumentationRegistry.getInstrumentation().getTargetContext());
        Long warm=DelayProbe.measure(java.net.Proxy.NO_PROXY,"http://127.0.0.1:23040/warm",8000);
        assertNotNull(warm);assertTrue("warm measurement: "+warm,warm>=1&&warm<250);
        // Plain HTTP forwarding may close between HEADs; HTTPS production tests
        // reuse the CONNECT tunnel. Both must authenticate through the profile.
        JSONObject proxied=(JSONObject)engine.delay(profile(),"http://vyrax-fixture.example/warm").get(12,java.util.concurrent.TimeUnit.SECONDS);
        assertTrue(proxied.getLong("latency")>=1);
        JSONObject failed=(JSONObject)engine.delay(profile(),"http://vyrax-fixture.example/error").get(12,java.util.concurrent.TimeUnit.SECONDS);
        assertTrue("503 is not a working profile",failed.isNull("latency"));
        JSONObject bad=profile();bad.put("uuid","00000000-0000-4000-8000-000000000099");
        assertTrue(((JSONObject)engine.delay(bad,"http://vyrax-fixture.example/warm").get(12,java.util.concurrent.TimeUnit.SECONDS)).isNull("latency"));
    }
    @Test public void subscriptionsSupportCompressionRedirectsAndDirectWhileProxyIsUnavailable()throws Exception{
        java.net.Proxy unavailable=new java.net.Proxy(java.net.Proxy.Type.HTTP,new java.net.InetSocketAddress("127.0.0.1",VpnEngine.freePort()));
        JSONObject result=NativeHttp.request("http://127.0.0.1:23040/redirect",false,unavailable);
        assertTrue(result.getString("text").startsWith("vless://"));assertEquals("base64:VGVzdCBTdWJzY3JpcHRpb24=",result.getString("title"));
        try{NativeHttp.request("http://127.0.0.1:23040/too-big",false,java.net.Proxy.NO_PROXY);fail("size limit");}
        catch(IllegalArgumentException expected){assertEquals("err.tooBig",expected.getMessage());}
    }
    @Test public void authenticProxyRequestThroughSyntheticServer()throws Exception{
        // Runs against a loopback-only synthetic Xray server on the emulator host.
        android.content.Context context=InstrumentationRegistry.getInstrumentation().getTargetContext();VpnEngine.get(context).init();
        long delay=Libv2ray.measureOutboundDelay(XrayConfig.build(profile(),new JSONObject(),0,0,0).toString(),"http://vyrax-fixture.example/generate_204");assertTrue(delay>=0);
    }
    @Test public void foregroundProxyAndVpnServiceConnectAndDisconnect()throws Exception{
        android.app.Instrumentation instrumentation=InstrumentationRegistry.getInstrumentation();android.content.Context context=instrumentation.getTargetContext();
        MainActivity activity=(MainActivity)instrumentation.startActivitySync(new android.content.Intent(context,MainActivity.class).addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK));
        VpnEngine engine=VpnEngine.get(context);
        try{
            java.lang.reflect.Method connect=MainActivity.class.getDeclaredMethod("connect",JSONObject.class);connect.setAccessible(true);
            for(String mode:new String[]{"proxy","tun"}){
                assertNull("Test device must preauthorize VPN",android.net.VpnService.prepare(context));
                java.util.concurrent.atomic.AtomicReference<java.util.concurrent.CompletableFuture<?>> answer=new java.util.concurrent.atomic.AtomicReference<>();
                instrumentation.runOnMainSync(()->{try{answer.set((java.util.concurrent.CompletableFuture<?>)connect.invoke(activity,Jsons.obj("profile",profile(),"settings",Jsons.obj("preferencesVersion",1,"mode",mode))));}catch(Exception error){throw new RuntimeException(error);}});
                JSONObject state=(JSONObject)answer.get().get(40,java.util.concurrent.TimeUnit.SECONDS);assertEquals("connected",state.getString("status"));
                JSONObject subscription=NativeHttp.request("http://127.0.0.1:23040/redirect",false,engine.proxy());
                assertTrue("subscription refresh while "+mode,subscription.getString("text").startsWith("vless://"));
                JSONObject proxied=NativeHttp.request("http://vyrax-fixture.example/subscription",false,engine.proxy());
                assertEquals("base64:VGVzdCBTdWJzY3JpcHRpb24=",proxied.getString("title"));
                if(mode.equals("proxy")){
                    java.net.HttpURLConnection request=(java.net.HttpURLConnection)new java.net.URL("http://vyrax-fixture.example/generate_204").openConnection(engine.proxy());
                    try{request.setConnectTimeout(5000);request.setReadTimeout(5000);assertEquals(204,request.getResponseCode());}finally{request.disconnect();}
                }else{
                    assertTrue(hev.htproxy.TProxyService.TProxyIsRunning());
                    instrumentation.runOnMainSync(()->activity.moveTaskToBack(true));Thread.sleep(400);
                    assertEquals("VPN survives UI pause","connected",engine.status);
                    instrumentation.runOnMainSync(()->context.startActivity(new android.content.Intent(context,MainActivity.class).addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK|android.content.Intent.FLAG_ACTIVITY_REORDER_TO_FRONT|android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP)));
                    Thread.sleep(400);assertEquals("connected",engine.status);
                    // Use the separately installed test package UID, since the
                    // host process itself is deliberately excluded from the VPN.
                    // The proxy server redirects this reserved IP to the fixture.
                    try(android.os.ParcelFileDescriptor output=instrumentation.getUiAutomation().executeShellCommand("run-as com.amyrax.vyrax.test sh /data/local/tmp/vyrax-request-tun.sh");java.io.FileInputStream input=new java.io.FileInputStream(output.getFileDescriptor())){
                        String response=NativeHttp.read(input,8192);assertTrue("VPN fixture response: "+response,response.contains("204 No Content"));
                    }
                }
                engine.disconnect().get(10,java.util.concurrent.TimeUnit.SECONDS);assertEquals("disconnected",engine.status);assertFalse(hev.htproxy.TProxyService.TProxyIsRunning());
            }
        }finally{engine.disconnect().get(10,java.util.concurrent.TimeUnit.SECONDS);instrumentation.runOnMainSync(activity::finish);}
    }
}
