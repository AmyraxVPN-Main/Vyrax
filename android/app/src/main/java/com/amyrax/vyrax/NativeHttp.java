package com.amyrax.vyrax;

import android.content.Context;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.Proxy;
import java.net.URI;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import org.json.JSONObject;

final class NativeHttp {
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
        long deadline=android.os.SystemClock.elapsedRealtime()+12000;String current=address;
        for(int redirect=0;redirect<5;redirect++){
            URI uri=new URI(current);String scheme=uri.getScheme();
            if((!"https".equals(scheme)&&!"http".equals(scheme))||uri.getUserInfo()!=null||uri.getHost()==null||(updates&&!"https".equals(scheme)))throw new IllegalArgumentException("err.subUrl");
            HttpURLConnection connection=(HttpURLConnection)new URL(current).openConnection(proxy);
            try{
                int remaining=(int)Math.max(1,deadline-android.os.SystemClock.elapsedRealtime());
                connection.setConnectTimeout(Math.min(remaining,8000));connection.setReadTimeout(Math.min(remaining,8000));connection.setInstanceFollowRedirects(false);connection.setUseCaches(false);
                connection.setRequestProperty("User-Agent","Vyrax/"+BuildConfig.VERSION_NAME);
                if(updates)connection.setRequestProperty("Accept","application/vnd.github+json");
                int code=connection.getResponseCode();
                if(updates&&code==404)return Jsons.obj("release",JSONObject.NULL);
                if(code>=300&&code<400&&!updates){String location=connection.getHeaderField("Location");if(location==null||android.os.SystemClock.elapsedRealtime()>=deadline)throw new IllegalStateException("err.subFailed");URI next=uri.resolve(location);if("https".equals(scheme)&&!"https".equals(next.getScheme()))throw new IllegalArgumentException("err.subUrl");current=next.toString();continue;}
                if(code!=200)throw new IllegalStateException(updates?"err.update":"err.subFailed");
                int limit=updates?262144:4*1024*1024;
                if(connection.getContentLengthLong()>limit)throw new IllegalArgumentException("err.tooBig");
                String text;try(InputStream input=connection.getInputStream()){text=read(input,limit);}
                if(updates){JSONObject release=new JSONObject(text);return Jsons.obj("release",Jsons.obj("tag_name",release.opt("tag_name"),"draft",release.opt("draft"),"prerelease",release.opt("prerelease"),"published_at",release.opt("published_at"),"html_url",release.opt("html_url")));}
                return Jsons.obj("text",text,"title",connection.getHeaderField("profile-title"),"userInfo",connection.getHeaderField("subscription-userinfo"),"disposition",connection.getHeaderField("content-disposition"));
            }finally{connection.disconnect();}
        }
        throw new IllegalStateException("err.subFailed");
    }
    static JSONObject updates(Context context,Proxy proxy)throws Exception{return request("https://api.github.com/repos/"+project(context).getString("repository")+"/releases/latest",true,proxy);}
}
