package com.amyrax.vyrax;

import java.net.IDN;
import java.net.InetAddress;
import java.util.LinkedHashSet;
import org.json.JSONArray;
import org.json.JSONObject;

final class Preferences {
    static JSONArray addresses(JSONObject settings,String key) {
        Object raw=settings.opt(key);String text="";
        if(raw instanceof JSONArray){JSONArray values=(JSONArray)raw;StringBuilder all=new StringBuilder();for(int i=0;i<values.length();i++)all.append(values.optString(i)).append('\n');text=all.toString();}
        else if(raw instanceof String)text=(String)raw;
        if(text.length()>16000)throw new IllegalArgumentException("err.routeList");
        LinkedHashSet<String> entries=new LinkedHashSet<>();
        for(String part:text.split("[\\s,;]+")){
            if(part.isEmpty())continue;
            String value=part.toLowerCase(java.util.Locale.ROOT);
            if(value.startsWith("*."))value=value.substring(2);
            try {
                String[] cidr=value.split("/",-1);
                if(isIp(cidr[0])){
                    InetAddress ip=InetAddress.getByName(cidr[0]);
                    if(cidr.length>2)throw new Exception();
                    if(cidr.length==2){int prefix=Integer.parseInt(cidr[1]);if(prefix<0||prefix>ip.getAddress().length*8)throw new Exception();}
                }else{
                    if(cidr.length!=1)throw new Exception();
                    value=IDN.toASCII(value.replaceAll("\\.$",""));
                    if(value.length()>253||!value.matches("(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?"))throw new Exception();
                }
            } catch(Exception error){throw new IllegalArgumentException("err.routeList");}
            entries.add(value);if(entries.size()>200)throw new IllegalArgumentException("err.routeList");
        }
        return new JSONArray(entries);
    }
    static boolean isIp(String value){return value.contains(":")||value.matches("[0-9.]+") ;}
    static JSONObject normalize(JSONObject input){
        JSONObject settings=input==null?new JSONObject():Jsons.copy(input);
        try{
            if(settings.optInt("preferencesVersion",0)<1)for(String key:new String[]{"autoConnect","autoReconnect","splitTunneling","bypassSites","proxyShare"})settings.put(key,false);
            settings.put("preferencesVersion",1);
            String mode=settings.optString("mode","tun");if(!mode.equals("tun")&&!mode.equals("proxy"))throw new IllegalArgumentException("err.mode");
            settings.put("mode",mode);
            int mtu=settings.optInt("mtu",1280);if(mtu<1280||mtu>1500)throw new IllegalArgumentException("err.config");
            settings.put("mtu",mtu);
            JSONArray split=addresses(settings,"splitAddresses"),bypass=addresses(settings,"bypassAddresses");
            boolean splitOn=settings.optBoolean("splitTunneling"),bypassOn=settings.optBoolean("bypassSites");
            if(splitOn&&bypassOn)throw new IllegalArgumentException("err.routeConflict");
            if((splitOn&&split.length()==0)||(bypassOn&&bypass.length()==0))throw new IllegalArgumentException("err.routeEmpty");
            settings.put("splitAddresses",split);settings.put("bypassAddresses",bypass);
            return settings;
        }catch(org.json.JSONException error){throw new IllegalArgumentException("err.config");}
    }
}
