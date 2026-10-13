package com.amyrax.vyrax;

import android.Manifest;
import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.net.Uri;
import android.net.VpnService;
import android.os.Build;
import android.os.Bundle;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.TextView;
import androidx.webkit.WebMessageCompat;
import androidx.webkit.WebViewAssetLoader;
import androidx.webkit.WebViewCompat;
import androidx.webkit.WebViewFeature;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.concurrent.CompletableFuture;
import java.util.function.Consumer;
import org.json.JSONArray;
import org.json.JSONObject;

public final class MainActivity extends Activity {
    private static final String ORIGIN="https://appassets.androidplatform.net";
    private static final int VPN_REQUEST=41,FILE_REQUEST=42,NOTIFICATION_REQUEST=43;
    private WebView view;
    private VpnEngine engine;
    private Geo geo;
    private CompletableFuture<Object> permissionResult,fileResult;
    private JSONObject permissionArgs;
    private long permissionGeneration;
    private boolean ready;
    private static StartRequest starting;
    private static final class StartRequest {
        final VpnEngine engine;final JSONObject profile,settings;final CompletableFuture<Object> result;final long generation;
        StartRequest(VpnEngine engine,JSONObject profile,JSONObject settings,CompletableFuture<Object> result){this.engine=engine;this.profile=profile;this.settings=settings;this.result=result;generation=engine.generation.get();}
    }
    private final Consumer<JSONObject> event=value->{if(view!=null&&ready)view.evaluateJavascript("window.__vyraxNativeEvent&&window.__vyraxNativeEvent("+value.toString()+")",null);};
    @Override public void onCreate(Bundle saved){
        super.onCreate(saved);engine=VpnEngine.get(this);
        if(!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)){
            TextView message=new TextView(this);message.setText("برای اجرای Vyrax، Android System WebView را به‌روز کنید.\nUpdate Android System WebView to run Vyrax.");message.setPadding(32,64,32,32);message.setTextColor(Color.WHITE);message.setBackgroundColor(Color.rgb(10,16,18));setContentView(message);return;
        }
        view=new WebView(this);view.setBackgroundColor(Color.rgb(10,16,18));setContentView(view);
        // System bars and cutouts remain outside the WebView's content area.
        view.setOnApplyWindowInsetsListener((v,insets)->{if(Build.VERSION.SDK_INT>=30){android.graphics.Insets bars=insets.getInsets(android.view.WindowInsets.Type.systemBars()|android.view.WindowInsets.Type.displayCutout()|android.view.WindowInsets.Type.ime());v.setPadding(bars.left,bars.top,bars.right,bars.bottom);}else v.setPadding(insets.getSystemWindowInsetLeft(),insets.getSystemWindowInsetTop(),insets.getSystemWindowInsetRight(),insets.getSystemWindowInsetBottom());return insets;});
        view.getSettings().setJavaScriptEnabled(true);view.getSettings().setDomStorageEnabled(true);
        view.getSettings().setAllowFileAccess(false);view.getSettings().setAllowContentAccess(false);view.getSettings().setJavaScriptCanOpenWindowsAutomatically(false);view.getSettings().setMediaPlaybackRequiresUserGesture(true);
        view.getSettings().setMixedContentMode(android.webkit.WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        WebView.setWebContentsDebuggingEnabled(BuildConfig.DEBUG);
        WebViewAssetLoader loader=new WebViewAssetLoader.Builder().addPathHandler("/assets/",new WebViewAssetLoader.AssetsPathHandler(this)).build();
        view.setWebViewClient(new WebViewClient(){
            @Override public WebResourceResponse shouldInterceptRequest(WebView web,WebResourceRequest request){WebResourceResponse local=loader.shouldInterceptRequest(request.getUrl());return local!=null?local:new WebResourceResponse("text/plain","UTF-8",403,"Blocked",Collections.emptyMap(),new ByteArrayInputStream(new byte[0]));}
            @Override public boolean shouldOverrideUrlLoading(WebView web,WebResourceRequest request){Uri uri=request.getUrl();return !ORIGIN.equals(uri.getScheme()+"://"+uri.getAuthority())||!uri.getPath().startsWith("/assets/ui/");}
            @Override public void onPageFinished(WebView web,String url){ready=true;event.accept(Jsons.obj("event","state","status",engine.status,"profileId",engine.profileId,"selectionMode",engine.selectionMode));}
        });
        WebViewCompat.addWebMessageListener(view,"VyraxAndroid",Collections.singleton(ORIGIN),(web,message,source,isMainFrame,reply)->{
            if(!isMainFrame||!ORIGIN.equals(source.toString()))return;
            Object id=null;
            try{
                String text=message.getData();if(text==null||text.length()>5*1024*1024)throw new IllegalArgumentException("err.tooBig");
                JSONObject request=new JSONObject(text);id=request.get("id");JSONObject args=request.optJSONObject("args");if(args==null)args=new JSONObject();
                Object requestId=id;
                dispatch(request.getString("action"),args).whenComplete((value,error)->runOnUiThread(()->{if(view==null)return;reply.postMessage((error==null?Jsons.obj("id",requestId,"result",value==null?JSONObject.NULL:value):Jsons.obj("id",requestId,"error",VpnEngine.safeError(error.getCause()==null?error:error.getCause()))).toString());}));
            }catch(Throwable error){reply.postMessage(Jsons.obj("id",id,"error",VpnEngine.safeError(error)).toString());}
        });
        engine.listeners.add(event);view.loadUrl(ORIGIN+"/assets/ui/index.html");
    }
    private CompletableFuture<Object> background(java.util.concurrent.Callable<Object> action){return CompletableFuture.supplyAsync(()->{try{return action.call();}catch(Exception error){throw new java.util.concurrent.CompletionException(error);}},engine.network);}
    private CompletableFuture<Object> dispatch(String action,JSONObject args)throws Exception{
        switch(action){
            case "load":return background(()->engine.store.load());
            case "save":return background(()->{engine.store.save(args);return true;});
            case "validateSettings":return CompletableFuture.completedFuture(Preferences.normalize(args));
            case "status":return CompletableFuture.completedFuture(engine.snapshot());
            case "ready":return background(()->engine.store.load()).thenCompose(value->{JSONObject saved=(JSONObject)value,settings=saved.optJSONObject("settings");if(settings==null||!settings.optBoolean("autoConnect")||!engine.status.equals("disconnected"))return CompletableFuture.completedFuture(engine.snapshot());JSONArray catalog=Jsons.array(saved,"profiles");JSONObject selected=null;for(int i=0;i<catalog.length();i++){JSONObject p=catalog.optJSONObject(i);if(p!=null&&p.optString("id").equals(saved.optString("selectedId")))selected=p;}if(selected==null)return CompletableFuture.completedFuture(engine.snapshot());JSONObject selectedProfile=selected;XrayConfig.put(settings,"_catalog",catalog);XrayConfig.put(settings,"_selection",saved.optString("selectionMode","manual"));XrayConfig.put(settings,"_source",saved.optString("activeSourceId"));CompletableFuture<Object> result=new CompletableFuture<>();runOnUiThread(()->{try{connect(Jsons.obj("profile",selectedProfile,"settings",settings)).whenComplete((answer,error)->{if(error==null)result.complete(answer);else result.completeExceptionally(error);});}catch(Exception error){result.completeExceptionally(error);}});return result;});
            case "connect":return connect(args);
            case "disconnect":cancelPendingConnect();return engine.disconnect().thenApply(value->value);
            case "select":return engine.select(args).thenApply(value->value);
            case "delay":case "ping":return engine.delay(args.getJSONObject("profile"));
            case "subscription":return background(()->NativeHttp.request(args.getString("url"),false,engine.proxy()));
            case "checkUpdates":return background(()->NativeHttp.updates(this,engine.proxy()));
            case "openProjectLink":startActivity(new Intent(Intent.ACTION_VIEW,Uri.parse(NativeHttp.projectLink(this,args.getString("target")))));return CompletableFuture.completedFuture(true);
            case "geo":return background(()->{if(geo==null)geo=new Geo(this);return geo.lookup(Jsons.array(args,"hosts"));});
            case "clipboard":{ClipboardManager clipboard=(ClipboardManager)getSystemService(CLIPBOARD_SERVICE);ClipData clip=clipboard.getPrimaryClip();return CompletableFuture.completedFuture(clip==null||clip.getItemCount()==0?"":clip.getItemAt(0).coerceToText(this).toString());}
            case "copy":{String text=args.getString("text");if(text.length()>4*1024*1024)throw new IllegalArgumentException("err.tooBig");ClipData clip=ClipData.newPlainText("Vyrax",text);if(Build.VERSION.SDK_INT>=33){android.os.PersistableBundle extras=new android.os.PersistableBundle();extras.putBoolean("android.content.extra.IS_SENSITIVE",true);clip.getDescription().setExtras(extras);}((ClipboardManager)getSystemService(CLIPBOARD_SERVICE)).setPrimaryClip(clip);return CompletableFuture.completedFuture(true);}
            case "file":if(fileResult!=null)throw new IllegalStateException("err.busy");fileResult=new CompletableFuture<>();Intent choose=new Intent(Intent.ACTION_OPEN_DOCUMENT).setType("*/*").addCategory(Intent.CATEGORY_OPENABLE);startActivityForResult(choose,FILE_REQUEST);return fileResult;
            case "minimize":case "close":moveTaskToBack(true);return CompletableFuture.completedFuture(true);
            case "drag":return CompletableFuture.completedFuture(false);
            case "language":getSharedPreferences("ui",MODE_PRIVATE).edit().putString("language",args.optString("language","fa")).apply();return CompletableFuture.completedFuture(true);
            default:throw new IllegalArgumentException("err.action");
        }
    }
    private CompletableFuture<Object> connect(JSONObject args)throws Exception{
        if(permissionResult!=null||starting!=null)throw new IllegalStateException("err.busy");
        JSONObject profile=args.getJSONObject("profile"),settings=Preferences.normalize(args.optJSONObject("settings"));XrayConfig.validate(profile);
        XrayConfig.build(profile,settings,0,0,0);CompletableFuture<Object> result=new CompletableFuture<>();
        Intent permission=settings.optString("mode").equals("tun")?VpnService.prepare(this):null;
        if(permission!=null){permissionResult=result;permissionArgs=Jsons.obj("profile",profile,"settings",settings);permissionGeneration=engine.generation.get();startActivityForResult(permission,VPN_REQUEST);}
        else startVpn(profile,settings,result);
        return result;
    }
    private void startVpn(JSONObject profile,JSONObject settings,CompletableFuture<Object> result){
        starting=new StartRequest(engine,profile,settings,result);
        try{startForegroundService(new Intent(this,VyraxVpnService.class).setAction(VyraxVpnService.CONNECT));}
        catch(Exception error){starting=null;result.completeExceptionally(new IllegalStateException("err.core"));}
    }
    static void completeServiceStart(VyraxVpnService host){
        StartRequest request=starting;starting=null;
        if(request==null){host.connectionStopped();return;}
        if(request.generation!=request.engine.generation.get()){request.result.complete(request.engine.snapshot());host.connectionStopped();return;}
        request.engine.connect(request.profile,request.settings,host).whenComplete((value,error)->{if(error==null)request.result.complete(value);else request.result.completeExceptionally(error);});
    }
    private void cancelPendingConnect(){if(permissionResult!=null){permissionResult.complete(engine.snapshot());permissionResult=null;permissionArgs=null;}if(starting!=null){starting.result.complete(engine.snapshot());starting=null;}}
    @Override protected void onActivityResult(int request,int result,Intent data){
        super.onActivityResult(request,result,data);
        if(request==VPN_REQUEST&&permissionResult!=null){CompletableFuture<Object> answer=permissionResult;JSONObject args=permissionArgs;permissionResult=null;permissionArgs=null;if(result==RESULT_OK&&permissionGeneration==engine.generation.get())startVpn(args.optJSONObject("profile"),args.optJSONObject("settings"),answer);else answer.completeExceptionally(new IllegalStateException("err.vpnPermission"));}
        if(request==FILE_REQUEST&&fileResult!=null){CompletableFuture<Object> answer=fileResult;fileResult=null;if(result!=RESULT_OK||data==null||data.getData()==null)answer.complete(null);else{Uri uri=data.getData();background(()->{try(InputStream input=getContentResolver().openInputStream(uri)){if(input==null)throw new IllegalStateException("err.file");return NativeHttp.read(input,4*1024*1024);}}).whenComplete((value,error)->{if(error==null)answer.complete(value);else answer.completeExceptionally(error);});}}
    }
    @Override protected void onResume(){super.onResume();if(view!=null){view.onResume();view.resumeTimers();if(ready){JSONObject state=engine.snapshot();XrayConfig.put(state,"event","state");XrayConfig.put(state,"switched",true);event.accept(state);}}if(Build.VERSION.SDK_INT>=33&&checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED&&!getSharedPreferences("ui",MODE_PRIVATE).getBoolean("notificationAsked",false)){getSharedPreferences("ui",MODE_PRIVATE).edit().putBoolean("notificationAsked",true).apply();requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS},NOTIFICATION_REQUEST);}}
    @Override protected void onPause(){if(view!=null)view.onPause();super.onPause();}
    @Override public void onBackPressed(){if(view!=null&&ready)view.evaluateJavascript("window.dispatchEvent(new Event('vyrax-back'))",null);else super.onBackPressed();}
    @Override protected void onDestroy(){engine.listeners.remove(event);cancelPendingConnect();if(fileResult!=null)fileResult.complete(null);if(view!=null){view.destroy();view=null;}super.onDestroy();}
}
