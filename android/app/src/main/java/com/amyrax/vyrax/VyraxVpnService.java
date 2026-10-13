package com.amyrax.vyrax;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.net.VpnService;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelFileDescriptor;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import org.json.JSONObject;

public final class VyraxVpnService extends VpnService {
    static final String CONNECT="com.amyrax.vyrax.CONNECT",DISCONNECT="com.amyrax.vyrax.DISCONNECT";
    private ParcelFileDescriptor tun;
    private VpnEngine engine;
    private final Handler main=new Handler(Looper.getMainLooper());
    private boolean stopped;
    @Override public void onCreate(){super.onCreate();engine=VpnEngine.get(this);((NotificationManager)getSystemService(NOTIFICATION_SERVICE)).createNotificationChannel(new NotificationChannel("vpn","Vyrax VPN",NotificationManager.IMPORTANCE_LOW));}
    @Override public int onStartCommand(Intent intent,int flags,int id){
        if(intent==null||DISCONNECT.equals(intent.getAction())){stopped=true;engine.disconnect();return START_NOT_STICKY;}
        stopped=false;foreground(false);
        MainActivity.completeServiceStart(this);
        return START_NOT_STICKY;
    }
    private boolean persian(){return getSharedPreferences("ui",MODE_PRIVATE).getString("language","fa").equals("fa");}
    private void foreground(boolean connected){
        boolean fa=persian();
        Intent open=new Intent(this,MainActivity.class);PendingIntent launch=PendingIntent.getActivity(this,0,open,PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT);
        Intent stop=new Intent(this,VyraxVpnService.class).setAction(DISCONNECT);PendingIntent disconnect=PendingIntent.getService(this,1,stop,PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT);
        Notification notification=new Notification.Builder(this,"vpn").setSmallIcon(R.drawable.ic_vpn).setContentTitle("Vyrax").setContentText(connected?(fa?"متصل — برای باز کردن بزنید":"Connected — tap to open"):(fa?"در حال اتصال…":"Connecting…")).setContentIntent(launch).setOngoing(true).setOnlyAlertOnce(true).addAction(new Notification.Action.Builder(null,fa?"قطع اتصال":"Disconnect",disconnect).build()).build();
        if(Build.VERSION.SDK_INT>=34)startForeground(17,notification,ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);else startForeground(17,notification);
    }
    void connected(){main.post(()->foreground(true));}
    synchronized void establishTunnel(int socks,int mtu)throws Exception{
        closeTunnel();
        Builder builder=new Builder().setSession("Vyrax").setMtu(mtu).addAddress("172.28.0.1",30).addAddress("fdfe:dcba:9876::1",126).addRoute("0.0.0.0",0).addRoute("::",0).addDnsServer("1.1.1.1").addDisallowedApplication(getPackageName()).setBlocking(false);
        if(Build.VERSION.SDK_INT>=29)builder.setMetered(false);
        tun=builder.establish();if(tun==null)throw new IllegalStateException("err.vpnPermission");
        File config=new File(getFilesDir(),"tunnel.yml");
        String yaml="tunnel:\n  mtu: "+mtu+"\n  ipv4: 172.28.0.1\n  ipv6: 'fdfe:dcba:9876::1'\nsocks5:\n  address: 127.0.0.1\n  port: "+socks+"\n  udp: 'udp'\nmisc:\n  log-level: error\n  log-file: /dev/null\n  task-stack-size: 32768\n  tcp-buffer-size: 8192\n  max-session-count: 1024\n";
        Files.write(config.toPath(),yaml.getBytes(StandardCharsets.UTF_8));
        if(!hev.htproxy.TProxyService.TProxyStartService(config.getAbsolutePath(),tun.getFd())){closeTunnel();throw new IllegalStateException("err.tunStart");}
        Thread.sleep(150);if(!hev.htproxy.TProxyService.TProxyIsRunning()){closeTunnel();throw new IllegalStateException("err.tunStart");}
    }
    synchronized void closeTunnel(){
        try{hev.htproxy.TProxyService.TProxyStopService();}catch(Throwable ignored){}
        if(tun!=null){try{tun.close();}catch(Exception ignored){}tun=null;}
    }
    void connectionStopped(){main.post(()->{if(engine.status.equals("disconnected")){stopForeground(STOP_FOREGROUND_REMOVE);stopSelf();}});}
    void reconnectOrStop(){
        if(!stopped&&engine.options.optBoolean("autoReconnect"))main.postDelayed(()->{if(!stopped&&engine.status.equals("disconnected"))engine.connect(engine.profile,engine.options,this);},3000);
        else connectionStopped();
    }
    @Override public void onRevoke(){stopped=true;engine.disconnect();super.onRevoke();}
    @Override public void onDestroy(){stopped=true;main.removeCallbacksAndMessages(null);closeTunnel();if(engine.service==this){engine.service=null;if(!engine.status.equals("disconnected"))engine.disconnect();}super.onDestroy();}
}
