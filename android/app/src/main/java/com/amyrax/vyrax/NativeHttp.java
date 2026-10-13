package com.amyrax.vyrax;

import android.content.Context;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.IOException;
import java.net.Proxy;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import org.json.JSONObject;
import java.util.concurrent.TimeUnit;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

final class NativeHttp {
    private static final OkHttpClient CLIENT=new OkHttpClient.Builder().followRedirects(false).followSslRedirects(false)
        .connectTimeout(8,TimeUnit.SECONDS).readTimeout(8,TimeUnit.SECONDS).build();
    static String read(InputStream input,int limit)throws Exception{
        ByteArrayOutputStream output=new ByteArrayOutputStream();byte[] buffer=new byte[8192];int n;
        while((n=input.read(buffer))!=-1){if(output.size()+n>limit)throw new IllegalArgumentException("err.tooBig");output.write(buffer,0,n);}
        return output.toString(StandardCharsets.UTF_8.name());
    }
    static JSONObject project(Context context)throws Exception{try(InputStream input=context.getAssets().open("project.json")){return new JSONObject(read(input,16384));}}
    static String projectLink(Context context,String target)throws Exception{
        JSONObject project=project(context);String repository=project.getString("repository");
        if(!repository.matches("[A-Za-z0-9-]+/[A-Za-z0-9_.-]+"))throw new IllegalArgumentException("err.action");
        switch(target){case "source":return "https://github.com/"+repository;case "release":return "https://github.com/"+repository+"/releases/latest";case "telegram":String link=project.getString("telegram");if(!link.matches("https://t\\.me/[A-Za-z0-9_]+"))throw new IllegalArgumentException("err.action");return link;default:throw new IllegalArgumentException("err.action");}
    }
    static JSONObject request(String address,boolean updates,Proxy proxy)throws Exception{
        if(!updates&&!Proxy.NO_PROXY.equals(proxy)){
            // The host UID is outside our VPN. Subscription panels often refuse
            // datacenter exits, so try the normal network before the VPN path.
            try{return fetch(address,false,Proxy.NO_PROXY,4000);}
            catch(IOException|IllegalStateException error){return fetch(address,false,proxy,12000);}
        }
        return fetch(address,updates,proxy,updates?12000:15000);
    }
    private static JSONObject fetch(String address,boolean updates,Proxy proxy,int budget)throws Exception{
        long deadline=android.os.SystemClock.elapsedRealtime()+budget;String current=address.trim();
        OkHttpClient client=CLIENT.newBuilder().proxy(proxy).build();
        for(int redirect=0;redirect<5;redirect++){
            URI uri=new URI(current);String scheme=uri.getScheme();
            if((!"https".equals(scheme)&&!"http".equals(scheme))||uri.getUserInfo()!=null||uri.getHost()==null||(updates&&!"https".equals(scheme)))throw new IllegalArgumentException("err.subUrl");
            long remaining=deadline-android.os.SystemClock.elapsedRealtime();if(remaining<=0)throw new IOException("Request deadline");
            Request request=new Request.Builder().url(current).header("User-Agent","Vyrax/"+BuildConfig.VERSION_NAME+" (Android; v2ray)")
                .header("Accept",updates?"application/vnd.github+json":"text/plain, application/json, application/yaml, */*").header("Cache-Control","no-cache").build();
            okhttp3.Call call=client.newCall(request);call.timeout().timeout(remaining,TimeUnit.MILLISECONDS);
            // OkHttp transparently decompresses gzip, including proxied replies.
            try(Response response=call.execute()){
                int code=response.code();
                if(updates&&code==404)return Jsons.obj("release",JSONObject.NULL);
                if(code>=300&&code<400&&!updates){String location=response.header("Location");if(location==null)throw new IllegalStateException("err.subFailed");URI next=uri.resolve(location);if("https".equals(scheme)&&!"https".equals(next.getScheme()))throw new IllegalArgumentException("err.subUrl");current=next.toString();continue;}
                if(code!=200)throw new IllegalStateException(updates?"err.update":"err.subFailed");
                int limit=updates?262144:4*1024*1024;
                if(response.body()==null)throw new IllegalStateException("err.subFailed");
                if(response.body().contentLength()>limit)throw new IllegalArgumentException("err.tooBig");
                String text=read(response.body().byteStream(),limit);
                if(updates){JSONObject release=new JSONObject(text);return Jsons.obj("release",Jsons.obj("tag_name",release.opt("tag_name"),"draft",release.opt("draft"),"prerelease",release.opt("prerelease"),"published_at",release.opt("published_at"),"html_url",release.opt("html_url")));}
                return Jsons.obj("text",text,"title",response.header("profile-title"),"userInfo",response.header("subscription-userinfo"),"disposition",response.header("content-disposition"));
            }
        }
        throw new IllegalStateException("err.subFailed");
    }
    static JSONObject updates(Context context,Proxy proxy)throws Exception{return request("https://api.github.com/repos/"+project(context).getString("repository")+"/releases/latest",true,proxy);}
}
