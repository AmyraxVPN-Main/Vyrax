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
            waitFor("document.querySelector('.pill-text b')?.textContent.includes('Synthetic')");
            assertEquals("\"android\"",js("document.documentElement.dataset.platform"));
            assertEquals("0",js("document.querySelectorAll('.bar button').length"));
            assertEquals("true",js("Math.abs(document.querySelector('.dial').getBoundingClientRect().left+document.querySelector('.dial').getBoundingClientRect().width/2-innerWidth/2)<2"));
            assertEquals("true",js("document.querySelector('.tabs-row').getBoundingClientRect().width>innerWidth*.8"));
            screenshot("home-portrait.png");
            assertEquals("1",js("document.querySelectorAll('[data-gooey-svg]').length"));
            assertEquals("1",js("document.querySelectorAll('.dial-liquid [data-gooey-svg]').length"));
            js("window.__vyraxNativeEvent({event:'state',status:'connected',profileId:'ui-test-0',exit:'198.51.100.42'});window.__vyraxNativeEvent({event:'stats',down:1048576,up:1024,downRate:128000,upRate:3300})");
            Thread.sleep(1000);
            screenshot("home-connected.png");
            String geometry=js("JSON.stringify({width:innerWidth,height:innerHeight,rects:Object.fromEntries(['.dial','.quick','.readout','.chips.traffic','.ip-line','.pill'].map(s=>[s,document.querySelector(s).getBoundingClientRect().toJSON()]))})");
            assertEquals(geometry,"true",js("(()=>{const dial=document.querySelector('.dial').getBoundingClientRect(),quick=document.querySelector('.quick').getBoundingClientRect(),readout=document.querySelector('.readout').getBoundingClientRect(),traffic=document.querySelector('.chips.traffic').getBoundingClientRect(),ip=document.querySelector('.ip-line').getBoundingClientRect(),pill=document.querySelector('.pill').getBoundingClientRect();return Math.abs(dial.left+dial.width/2-innerWidth/2)<1&&Math.abs(quick.left+quick.width/2-innerWidth/2)<1&&readout.top>quick.bottom&&ip.top+1>=traffic.bottom&&ip.bottom<=pill.top+1;})()"));
            js("window.__orbitTrace=[];window.__orbitDone=false;document.querySelector('.quick').click();let start=performance.now();function sample(t){window.__orbitTrace.push({t:t-start,x:document.querySelector('.drop').getBoundingClientRect().left});if(t-start<1100)requestAnimationFrame(sample);else window.__orbitDone=true;}requestAnimationFrame(sample)");
            waitFor("window.__orbitDone");
            assertEquals("true",js("new Set(window.__orbitTrace.map(v=>Math.round(v.x))).size>3"));
            assertEquals("true",js("Math.abs(window.__orbitTrace[0].x-window.__orbitTrace[window.__orbitTrace.length-1].x)>80"));
            assertEquals("true",js("Math.min(...window.__orbitTrace.map(v=>v.x))<window.__orbitTrace[window.__orbitTrace.length-1].x-4"));
            assertEquals("true",js("(()=>{const d=[...document.querySelectorAll('.drop')].map(el=>{const r=el.getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2};});return Math.abs(d[0].x+d[3].x-innerWidth)<1&&Math.abs(d[1].x+d[2].x-innerWidth)<1&&Math.abs(d[0].y-d[3].y)<1&&Math.abs(d[1].y-d[2].y)<1;})()"));
            screenshot("quick-orbit-open.png");
            js("document.querySelector('.quick').click()");Thread.sleep(1100);
            assertEquals("true",js("Math.abs(document.querySelector('.drop').getBoundingClientRect().left+28-innerWidth/2)<2"));
            assertEquals("true",js("document.elementFromPoint(innerWidth/2,document.querySelector('.dial').getBoundingClientRect().top+75).closest('.dial')!==null"));
            js("document.querySelector('.quick').click()");Thread.sleep(100);
            js("document.querySelector('.quick').click()");Thread.sleep(100);
            js("document.querySelector('.quick').click()");Thread.sleep(1100);
            assertEquals("true",js("Math.abs(document.querySelector('.shell').scrollLeft)<1&&Math.abs(document.querySelector('.dial').getBoundingClientRect().left+75-innerWidth/2)<1"));
            js("document.querySelector('.quick').click()");Thread.sleep(1100);
            try(java.io.FileWriter output=new java.io.FileWriter(new java.io.File(context.getFilesDir(),"orbit-animation.json"))){output.write(js("JSON.stringify(window.__orbitTrace)"));}
            js("window.__vyraxNativeEvent({event:'state',status:'disconnected'})");
            js("document.querySelector('.tabs-row .tab:nth-child(2)').click()");waitFor("document.querySelector('.source-picker')");
            waitFor("document.querySelector('.source-picker').textContent.includes('Synthetic group')");
            js("document.querySelector('.loc-head .icon-btn').click()");waitFor("document.querySelector('.check-row.on')");
            js("document.querySelector('.source-picker').click()");waitFor("document.querySelector('.subscriptions-sheet')");
            assertEquals("false",js("document.querySelector('.sheet-close').disabled"));
            assertEquals("false",js("document.querySelector('.sub-actions button:nth-child(1)').disabled"));
            js("document.querySelector('.sub-actions button:nth-child(1)').click()");waitFor("document.querySelector('.toast')");
            screenshot("subscription-during-pings.png");
            js("document.querySelector('.sheet-close').click()");waitFor("!document.querySelector('.subscriptions-sheet')");
            assertEquals("true",js("Boolean(document.querySelector('.check-row.on'))"));
            js("document.querySelector('.tabs-row .tab:nth-child(3)').click()");waitFor("document.querySelector('.prefs')");
            assertEquals("true",js("document.querySelector('.tabs-row .tab:nth-child(3)').getAttribute('aria-current')==='page'"));
            js("document.querySelector('.language-picker button:nth-child(2)').click()");waitFor("document.documentElement.dir==='rtl'");
            js("document.querySelector('.tabs-row .tab:nth-child(2)').click()");waitFor("document.querySelector('.source-picker')");
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
