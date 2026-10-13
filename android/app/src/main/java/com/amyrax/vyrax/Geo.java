package com.amyrax.vyrax;

import android.content.Context;
import java.io.InputStream;
import java.net.InetAddress;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import org.json.JSONArray;
import org.json.JSONObject;

final class Geo {
    private final ByteBuffer table;
    private final String[] codes;
    private final int offset,count;
    Geo(Context context)throws Exception{
        byte[] bytes;try(InputStream input=context.getAssets().open("geo.bin")){java.io.ByteArrayOutputStream output=new java.io.ByteArrayOutputStream();byte[] buffer=new byte[8192];int n;while((n=input.read(buffer))>0)output.write(buffer,0,n);bytes=output.toByteArray();}
        table=ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN);int countries=Short.toUnsignedInt(table.getShort());codes=new String[countries];
        for(int i=0;i<countries;i++)codes[i]=""+(char)table.get()+(char)table.get();
        count=table.getInt();offset=table.position();if(offset+(long)count*6!=bytes.length)throw new IllegalStateException("err.geo");
    }
    String country(byte[] ip){
        if(ip.length!=4)return "";long address=0;for(byte value:ip)address=(address<<8)|(value&255);
        int low=0,high=count-1;while(low<high){int mid=(low+high)>>>1;long end=Integer.toUnsignedLong(table.getInt(offset+mid*6));if(end<address)low=mid+1;else high=mid;}
        int index=Short.toUnsignedInt(table.getShort(offset+low*6+4));return index<codes.length?codes[index].toLowerCase(java.util.Locale.ROOT):"";
    }
    JSONObject lookup(JSONArray hosts){JSONObject result=new JSONObject();for(int i=0;i<Math.min(512,hosts.length());i++){String host=hosts.optString(i);if(host.isEmpty()||host.length()>253||host.matches(".*[\\s/\\\\@].*"))continue;try{for(InetAddress ip:InetAddress.getAllByName(host)){String code=country(ip.getAddress());if(!code.isEmpty()){XrayConfig.put(result,host,code);break;}}}catch(Exception ignored){}}return result;}
}
