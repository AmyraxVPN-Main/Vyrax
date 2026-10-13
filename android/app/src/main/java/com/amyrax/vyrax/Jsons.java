package com.amyrax.vyrax;

import org.json.JSONArray;
import org.json.JSONObject;

final class Jsons {
    static JSONObject obj(Object... pairs) {
        JSONObject result = new JSONObject();
        try { for (int i=0;i<pairs.length;i+=2) result.put((String)pairs[i], pairs[i+1]); }
        catch (Exception error) { throw new IllegalArgumentException("err.config"); }
        return result;
    }
    static JSONArray arr(Object... values) { JSONArray result=new JSONArray(); for(Object value:values)result.put(value);return result; }
    static JSONObject copy(JSONObject value) { try { return new JSONObject(value.toString()); } catch(Exception error){throw new IllegalArgumentException("err.config");} }
    static JSONArray array(JSONObject value,String key){JSONArray result=value.optJSONArray(key);return result==null?new JSONArray():result;}
}
