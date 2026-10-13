package com.amyrax.vyrax;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import java.net.InetSocketAddress;
import java.net.Proxy;
import java.net.ServerSocket;
import java.util.Set;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CopyOnWriteArraySet;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.Consumer;
import libv2ray.CoreCallbackHandler;
import libv2ray.CoreController;
import libv2ray.Libv2ray;
import org.json.JSONArray;
import org.json.JSONObject;

final class VpnEngine {
    private static VpnEngine instance;
    static synchronized VpnEngine get(Context context){if(instance==null)instance=new VpnEngine(context.getApplicationContext());return instance;}
    final Context context;
    final SecureStore store;
    final ExecutorService worker=Executors.newSingleThreadExecutor();
    final ExecutorService network=Executors.newFixedThreadPool(3);
    private final ExecutorService probes;
    final Set<Consumer<JSONObject>> listeners=new CopyOnWriteArraySet<>();
    private final Handler main=new Handler(Looper.getMainLooper());
    final AtomicLong generation=new AtomicLong();
    volatile String status="disconnected";
    volatile String profileId="",selectionMode="manual",mode="tun";
    volatile int httpPort,socksPort,sharePort;
    private boolean initialized;
    private CoreController core;
    private long since,up,down,lastSample;
    JSONObject profile=new JSONObject(),options=new JSONObject();
    VyraxVpnService service;
    VpnEngine(Context context){this.context=context;store=new SecureStore(context);android.app.ActivityManager memory=(android.app.ActivityManager)context.getSystemService(Context.ACTIVITY_SERVICE);probes=Executors.newFixedThreadPool(memory!=null&&memory.isLowRamDevice()?2:3);}
    synchronized void init(){if(initialized)return;go.Seq.setContext(context);Libv2ray.initCoreEnv(context.getFilesDir().getAbsolutePath(),"");initialized=true;}
    JSONObject snapshot(){return Jsons.obj("status",status,"profileId",profileId,"selectionMode",selectionMode,"since",since==0?JSONObject.NULL:java.time.Instant.ofEpochMilli(since).toString(),"elevated",true,"exit",profile.optString("host"),"share",sharePort>0?Jsons.obj("hosts",localHosts(),"port",sharePort):mode.equals("proxy")&&status.equals("connected")?Jsons.obj("hosts",Jsons.arr("127.0.0.1"),"port",httpPort):JSONObject.NULL,"activeTargets",Jsons.arr(profileId));}
    private JSONArray localHosts(){JSONArray hosts=new JSONArray();try{java.util.Enumeration<java.net.NetworkInterface> adapters=java.net.NetworkInterface.getNetworkInterfaces();while(adapters.hasMoreElements()){java.net.NetworkInterface adapter=adapters.nextElement();if(!adapter.isUp()||adapter.isLoopback())continue;java.util.Enumeration<java.net.InetAddress> ips=adapter.getInetAddresses();while(ips.hasMoreElements()){java.net.InetAddress ip=ips.nextElement();if(ip instanceof java.net.Inet4Address&&ip.isSiteLocalAddress())hosts.put(ip.getHostAddress());}}}catch(Exception ignored){}return hosts;}
    void emit(JSONObject event){main.post(()->{for(Consumer<JSONObject> listener:listeners)listener.accept(event);});}
    void state(String stage,String message,boolean switched){JSONObject event=snapshot();XrayConfig.put(event,"event","state");XrayConfig.put(event,"stage",stage);XrayConfig.put(event,"message",message);XrayConfig.put(event,"switched",switched);emit(event);}
    Proxy proxy(){return status.equals("connected")&&httpPort>0?new Proxy(Proxy.Type.HTTP,new InetSocketAddress("127.0.0.1",httpPort)):Proxy.NO_PROXY;}
    static int freePort()throws Exception{try(ServerSocket socket=new ServerSocket(0,0,java.net.InetAddress.getLoopbackAddress())){return socket.getLocalPort();}}
    CompletableFuture<JSONObject> connect(JSONObject selected,JSONObject settings,VyraxVpnService host){
        XrayConfig.validate(selected);JSONObject normalized=Preferences.normalize(settings);
        long token=generation.incrementAndGet();CompletableFuture<JSONObject> answer=new CompletableFuture<>();
        worker.execute(()->{
            try{
                stopCore();if(generation.get()!=token){answer.complete(snapshot());return;}
                service=host;profile=Jsons.copy(selected);options=normalized;profileId=profile.optString("id");selectionMode=options.optString("_selection","manual");mode=options.optString("mode","tun");
                status="connecting";state("stage.core","",false);init();
                socksPort=freePort();httpPort=freePort();sharePort=options.optBoolean("proxyShare")?freePort():0;
                core=Libv2ray.newCoreController(new CoreCallbackHandler(){public long startup(){return 0;}public long shutdown(){return 0;}public long onEmitStatus(long status,String message){return 0;}});
                core.startLoop(XrayConfig.build(profile,options,socksPort,httpPort,sharePort).toString(),0);
                if(!core.getIsRunning())throw new IllegalStateException("err.core");
                state("stage.handshake","",false);
                // An authenticated request must succeed before reporting Connected.
                if(DelayProbe.measure(new Proxy(Proxy.Type.HTTP,new InetSocketAddress("127.0.0.1",httpPort)),XrayConfig.PROBE_URL,8000)==null)throw new IllegalStateException("err.core");
                if(generation.get()!=token){stopCore();answer.complete(snapshot());return;}
                if(mode.equals("tun"))host.establishTunnel(socksPort,options.optInt("mtu",1280));
                if(generation.get()!=token){stopCore();answer.complete(snapshot());return;}
                status="connected";since=System.currentTimeMillis();up=down=0;lastSample=SystemClock.elapsedRealtime();
                host.connected();state("","",false);main.removeCallbacks(poll);main.postDelayed(poll,1000);answer.complete(snapshot());
            }catch(Throwable error){stopCore();status="disconnected";if(service!=null)service.connectionStopped();state("",safeError(error),false);answer.completeExceptionally(new IllegalStateException(safeError(error)));}
        });return answer;
    }
    CompletableFuture<JSONObject> disconnect(){generation.incrementAndGet();CompletableFuture<JSONObject> answer=new CompletableFuture<>();worker.execute(()->{stopCore();status="disconnected";profileId="";since=0;if(service!=null)service.connectionStopped();state("","",false);answer.complete(snapshot());});return answer;}
    private void stopCore(){main.removeCallbacks(poll);if(service!=null)service.closeTunnel();if(core!=null){try{core.stopLoop();}catch(Exception ignored){}core=null;}sharePort=0;}
    private final Runnable poll=new Runnable(){public void run(){if(!status.equals("connected"))return;worker.execute(()->{
        try{
            if(core==null||!core.getIsRunning()||(mode.equals("tun")&&!hev.htproxy.TProxyService.TProxyIsRunning()))throw new IllegalStateException("err.tunStart");
            long addedUp=0,addedDown=0;String active="";long activeBytes=0;
            for(String item:core.queryAllOutboundTrafficStats().split(";")){String[] parts=item.split(",");if(parts.length!=3||(!parts[0].equals("proxy")&&!parts[0].startsWith("node-")))continue;long count=Long.parseLong(parts[2]);if(parts[1].equals("uplink"))addedUp+=count;else if(parts[1].equals("downlink"))addedDown+=count;if(count>activeBytes&&parts[0].startsWith("node-")){active=parts[0];activeBytes=count;}}
            if(!active.isEmpty()){JSONObject selected=Jsons.array(options,"_catalog").optJSONObject(Integer.parseInt(active.substring(5)));if(selected!=null&&!selected.optString("id").equals(profileId)){profile=selected;profileId=selected.optString("id");state("","",true);}}
            double seconds=Math.max(.1,(SystemClock.elapsedRealtime()-lastSample)/1000.0);lastSample=SystemClock.elapsedRealtime();up+=addedUp;down+=addedDown;
            emit(Jsons.obj("event","stats","up",up,"down",down,"upRate",(long)(addedUp/seconds),"downRate",(long)(addedDown/seconds)));
            main.postDelayed(this,1000);
        }catch(Throwable error){status="disconnected";stopCore();state("",safeError(error),false);if(service!=null)service.reconnectOrStop();}
    });}};
    CompletableFuture<JSONObject> select(JSONObject args){
        JSONArray profiles=Jsons.array(args,"profiles");JSONObject chosen=null;
        for(int i=0;i<profiles.length();i++){JSONObject item=profiles.optJSONObject(i);if(item!=null&&item.optString("id").equals(args.optString("selectedId"))&&item.optString("sourceId").equals(args.optString("activeSourceId"))){chosen=item;break;}}
        if(chosen==null)throw new IllegalArgumentException("err.config");
        JSONObject next=Jsons.copy(options);XrayConfig.put(next,"_catalog",profiles);XrayConfig.put(next,"_selection",args.optString("selectionMode","manual"));XrayConfig.put(next,"_source",args.optString("activeSourceId"));
        return connect(chosen,next,service);
    }
    CompletableFuture<Object> delay(JSONObject selected){return delay(selected,XrayConfig.PROBE_URL);}
    CompletableFuture<Object> delay(JSONObject selected,String url){return CompletableFuture.supplyAsync(()->{
        CoreController probe=null;
        try{
            init();int port=freePort();
            probe=Libv2ray.newCoreController(new CoreCallbackHandler(){public long startup(){return 0;}public long shutdown(){return 0;}public long onEmitStatus(long status,String message){return 0;}});
            probe.startLoop(XrayConfig.probe(selected,port).toString(),0);
            Long latency=DelayProbe.measure(new Proxy(Proxy.Type.HTTP,new InetSocketAddress("127.0.0.1",port)),url,8000);
            return Jsons.obj("latency",latency==null?JSONObject.NULL:latency);
        }catch(Throwable error){return Jsons.obj("latency",JSONObject.NULL);}
        finally{if(probe!=null)try{probe.stopLoop();}catch(Exception ignored){}}
    },probes);}
    static String safeError(Throwable error){String message=error.getMessage();return message!=null&&message.matches("err\\.[A-Za-z]+")?message:"err.core";}
}
