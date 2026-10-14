package com.amyrax.vyrax;

import android.app.Instrumentation;
import android.content.Context;
import android.content.Intent;
import android.webkit.WebView;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.Test;
import org.junit.runner.RunWith;
import static org.junit.Assert.*;

@RunWith(AndroidJUnit4.class)
public class WebViewSmokeTest {
    private final Instrumentation instrumentation=InstrumentationRegistry.getInstrumentation();
    private WebView view;
    private String js(String script)throws Exception{
        CountDownLatch done=new CountDownLatch(1);String[] answer=new String[1];
        instrumentation.runOnMainSync(()->view.evaluateJavascript(script,value->{answer[0]=value;done.countDown();}));
        assertTrue("WebView responded",done.await(10,TimeUnit.SECONDS));return answer[0];
    }
    private void waitFor(String expression)throws Exception{
        long deadline=System.currentTimeMillis()+10000;
        while(System.currentTimeMillis()<deadline){if("true".equals(js("Boolean("+expression+")")))return;Thread.sleep(100);}
        fail("Timed out waiting for "+expression);
    }
    private void screenshot(String name)throws Exception{
        android.graphics.Bitmap bitmap=instrumentation.getUiAutomation().takeScreenshot();
        java.io.File file=new java.io.File(instrumentation.getTargetContext().getFilesDir(),name);
        try(java.io.FileOutputStream output=new java.io.FileOutputStream(file)){bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG,100,output);}
        bitmap.recycle();
    }
    @Test public void bundledBridgeAndSubscriptionControlsRemainResponsiveDuringPings()throws Exception{
        Context context=instrumentation.getTargetContext();SecureStore store=VpnEngine.get(context).store;JSONObject original=store.load();MainActivity activity=null;
        try{
            JSONArray profiles=new JSONArray();
            for(int i=0;i<6;i++)profiles.put(Jsons.obj("id","ui-test-"+i,"name","Synthetic "+i,"protocol","vless","uuid","00000000-0000-4000-8000-000000000001","host","127.0.0.1","port",22541,"transport","tcp","sourceId","ui-test","cc","de","raw","vless://00000000-0000-4000-8000-000000000001@127.0.0.1:22541#Synthetic"));
            store.save(Jsons.obj("profiles",profiles,"subscriptions",Jsons.arr(Jsons.obj("id","ui-test","name","Synthetic group","kind","local","url","")),"activeSourceId","ui-test","selectedId","ui-test-0","selectionMode","manual","settings",Jsons.obj("preferencesVersion",1,"mode","tun")));
            activity=(MainActivity)instrumentation.startActivitySync(new Intent(context,MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            java.lang.reflect.Field field=MainActivity.class.getDeclaredField("view");field.setAccessible(true);view=(WebView)field.get(activity);assertNotNull(view);
            waitFor("document.querySelector('.connect-fab') && document.querySelector('.dashboard')");
            assertEquals("\"android\"",js("document.documentElement.dataset.platform"));
            assertEquals("0",js("document.querySelectorAll('.bar button').length"));
            assertEquals("true",js("document.querySelector('.material-nav').getBoundingClientRect().width>innerWidth*.9"));
            assertEquals("true",js("document.documentElement.scrollWidth<=innerWidth+1"));
            assertEquals("true",js("(()=>{const r=document.querySelector('.connect-fab').getBoundingClientRect();return r.left>innerWidth/2&&r.right<innerWidth})()"));
            screenshot("home-portrait.png");
            js("window.__vyraxNativeEvent({event:'state',status:'connected',profileId:'ui-test-0',exit:'198.51.100.42'});window.__vyraxNativeEvent({event:'stats',down:1048576,up:1024,downRate:128000,upRate:3300})");
            waitFor("document.querySelector('.dashboard.is-connected')");
            Thread.sleep(500);screenshot("home-connected.png");
            assertEquals("true",js("document.querySelector('.connect-fab').getAttribute('aria-busy')==='false'"));
            assertEquals("true",js("[...document.querySelectorAll('.dashboard-grid .dash-card')].every(e=>{const r=e.getBoundingClientRect();return r.left>=-1&&r.right<=innerWidth+1})"));
            js("window.__vyraxNativeEvent({event:'state',status:'disconnected'})");
            js("document.querySelector('.material-nav > button:nth-child(3)').click()");waitFor("document.querySelector('.source-picker')");
            waitFor("document.querySelector('.source-picker').textContent.includes('Synthetic group')");
            js("document.querySelector('.loc-head .icon-btn').click()");waitFor("document.querySelector('.check-row.on')");
            js("document.querySelector('.source-picker').click()");waitFor("document.querySelector('.subscriptions-sheet')");
            assertEquals("false",js("document.querySelector('.sheet-close').disabled"));
            assertEquals("false",js("document.querySelector('.sub-actions button:nth-child(1)').disabled"));
            js("document.querySelector('.sub-actions button:nth-child(1)').click()");waitFor("document.querySelector('.toast')");
            screenshot("subscription-during-pings.png");
            js("document.querySelector('.sheet-close').click()");waitFor("!document.querySelector('.subscriptions-sheet')");
            assertEquals("true",js("Boolean(document.querySelector('.check-row.on'))"));
            js("document.querySelector('.material-nav > button:nth-child(6)').click()");waitFor("document.querySelector('.prefs')");
            assertEquals("true",js("document.querySelector('.material-nav > button:nth-child(6)').getAttribute('aria-current')==='page'"));
            js("document.querySelector('.language-picker button:nth-child(2)').click()");waitFor("document.documentElement.dir==='rtl'");
            js("document.querySelector('.material-nav > button:nth-child(3)').click()");waitFor("document.querySelector('.source-picker')");
            js("document.querySelector('.source-picker').click()");waitFor("document.querySelector('.subscriptions-sheet')");
            assertEquals("\"right\"",js("getComputedStyle(document.querySelector('.sub-select')).textAlign==='start'?'right':getComputedStyle(document.querySelector('.sub-select')).textAlign"));
            Thread.sleep(350);screenshot("subscriptions-persian.png");
            js("document.querySelector('.sub-actions button:nth-child(2)').click()");waitFor("document.querySelector('.qr-share img')");
            js("document.querySelector('.sheet-close').click()");waitFor("!document.querySelector('.subscriptions-sheet')");
        }finally{
            if(activity!=null){MainActivity current=activity;instrumentation.runOnMainSync(current::finish);instrumentation.waitForIdleSync();}
            // Probes run on their own workers and finish within two eight-second batches.
            Thread.sleep(17000);store.save(original);
        }
    }
}
