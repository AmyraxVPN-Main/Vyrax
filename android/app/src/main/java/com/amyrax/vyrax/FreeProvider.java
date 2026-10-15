// SPDX-License-Identifier: MIT
// Guardian protocol adapted from FoxyVPN, Copyright (c) 2026 Vauth.
package com.amyrax.vyrax;
import android.content.Context;
import java.net.Proxy;
import java.util.concurrent.TimeUnit;
import okhttp3.*;
import org.json.*;

final class FreeProvider {
    private static final String CLIENT="5882386c6d801776",SCOPE="profile https://identity.mozilla.com/apps/vpn";
    interface Vault {JSONObject load()throws Exception;void save(JSONObject value)throws Exception;}
    interface Transport {JSONObject request(String name,String body,String authorization)throws Exception;}
    private final Vault store;
    private final Transport transport;
    private final OkHttpClient http=new OkHttpClient.Builder().proxy(Proxy.NO_PROXY).followRedirects(false).followSslRedirects(false).connectTimeout(8,TimeUnit.SECONDS).readTimeout(15,TimeUnit.SECONDS).callTimeout(15,TimeUnit.SECONDS).build();
    private JSONArray accounts;
    private JSONObject session,state;
    private String pass="";
    private long expiry;
    private boolean readError;
    static long now(){return System.currentTimeMillis()/1000;}
    FreeProvider(Context context){
        SecureStore secure=new SecureStore(context,true);
        store=new Vault(){public JSONObject load()throws Exception{return secure.load();}public void save(JSONObject value)throws Exception{secure.save(value);}};
        transport=this::network;
    }
    FreeProvider(Vault store,Transport transport){this.store=store;this.transport=transport;}
    private void init()throws Exception {if(accounts!=null)return;JSONObject saved;try{saved=store.load();}catch(Exception error){saved=new JSONObject();readError=true;}accounts=saved.optJSONArray("accounts");if(accounts==null){accounts=new JSONArray();if(saved.has("refreshToken"))accounts.put(saved);}session=accounts.optJSONObject(0);for(int i=0;i<accounts.length();i++)if(accounts.getJSONObject(i).optString("email").equals(saved.optString("activeEmail")))session=accounts.getJSONObject(i);if(session==null)session=new JSONObject();restore();}
    private void restore(){pass="";expiry=0;state=Jsons.obj("signedIn",!session.optString("refreshToken").isEmpty(),"email",session.optString("email"),"activated",session.optBoolean("activated"),"quota",session.optJSONObject("quota"));}
    private JSONObject summary()throws Exception {JSONObject result=Jsons.copy(state);JSONArray list=new JSONArray();for(int i=0;i<accounts.length();i++){JSONObject a=accounts.getJSONObject(i),s=a.optString("email").equals(session.optString("email"))?state:a;list.put(Jsons.obj("email",a.optString("email"),"activated",s.optBoolean("activated"),"quota",s.optJSONObject("quota")));}result.put("accounts",list);result.put("activeEmail",session.optString("email"));return result;}
    private void persist()throws Exception {if(!session.optString("email").isEmpty()){session.put("activated",state.optBoolean("activated"));session.put("quota",state.optJSONObject("quota"));JSONArray list=new JSONArray();for(int i=0;i<accounts.length();i++)if(!accounts.getJSONObject(i).optString("email").equals(session.optString("email")))list.put(accounts.getJSONObject(i));list.put(session);accounts=list;}store.save(Jsons.obj("accounts",accounts,"activeEmail",session.optString("email")));}
    private static String endpoint(String name){switch(name){case "login":return "https://api.accounts.firefox.com/v1/account/login";case "verify":return "https://api.accounts.firefox.com/v1/session/verify_code";case "oauth":return "https://api.accounts.firefox.com/v1/oauth/token";case "servers":return "https://firefox.settings.services.mozilla.com/v1/buckets/main/collections/vpn-serverlist/records";case "status":case "activate":case "token":return "https://vpn.mozilla.org/api/v1/fpn/"+name;default:throw new IllegalArgumentException("err.action");}}
    JSONObject request(JSONObject args)throws Exception {String name=args.optString("endpoint");if(!java.util.Arrays.asList("login","verify","oauth","servers").contains(name))throw new IllegalArgumentException("err.action");return http(name,args.optString("body"),args.optString("authorization"));}
    private JSONObject http(String name,String body,String authorization)throws Exception {
        if(body.length()>32768||authorization.length()>32768||authorization.contains("\r")||authorization.contains("\n"))throw new IllegalArgumentException("err.action");
        endpoint(name);
        return transport.request(name,body,authorization);
    }
    private JSONObject network(String name,String body,String authorization)throws Exception {
        Request.Builder request=new Request.Builder().url(endpoint(name)).header("User-Agent","Vyrax Firefox-compatible client").header("Accept","application/json");if(!authorization.isEmpty())request.header("Authorization",authorization);
        if(java.util.Arrays.asList("login","verify","oauth","activate").contains(name))request.post(RequestBody.create(body,MediaType.get("application/json")));
        try(Response response=http.newCall(request.build()).execute()){
            if(response.body()==null||response.body().contentLength()>1048576)throw new IllegalStateException("err.freeService");
            JSONObject headers=new JSONObject();for(String key:new String[]{"x-quota-limit","x-quota-remaining","x-quota-reset"})headers.put(key,response.header(key));
            return Jsons.obj("status",response.code(),"body",NativeHttp.read(response.body().byteStream(),1048576),"headers",headers);
        }catch(java.io.IOException error){throw new IllegalStateException("err.freeNetwork");}
    }
    static JSONObject data(JSONObject response)throws Exception {int code=response.optInt("status");if(code==406)throw new IllegalStateException("err.freeChallenge");if(code==429)throw new IllegalStateException("err.freeQuota");if(code==403)throw new IllegalStateException("err.freeEligibility");if(code==401)throw new IllegalStateException("err.freeAuth");if(code<200||code>=300)throw new IllegalStateException("err.freeService");try{return new JSONObject(response.optString("body"));}catch(JSONException error){throw new IllegalStateException("err.freeService");}}
    private static void secret(String value){if(value.isEmpty()||value.length()>16384||value.matches(".*[\\s\\x00-\\x1f].*"))throw new IllegalArgumentException("err.freeAuth");}
    synchronized JSONObject save(JSONObject value)throws Exception {init();secret(value.optString("accessToken"));secret(value.optString("refreshToken"));String email=value.optString("email");if(email.isEmpty()||email.length()>254||(!contains(email)&&accounts.length()>=10))throw new IllegalArgumentException("err.freeAccounts");session=Jsons.obj("accessToken",value.optString("accessToken"),"refreshToken",value.optString("refreshToken"),"email",email,"expiresAt",value.optLong("expiresAt"));restore();persist();readError=false;return summary();}
    private boolean contains(String email){for(int i=0;i<accounts.length();i++)if(accounts.optJSONObject(i).optString("email").equals(email))return true;return false;}
    private String access()throws Exception {
        if(session.optString("refreshToken").isEmpty())throw new IllegalStateException("err.freeAuth");
        if(!session.optString("accessToken").isEmpty()&&session.optLong("expiresAt")>now()+60)return session.optString("accessToken");
        JSONObject response=http("oauth",Jsons.obj("client_id",CLIENT,"grant_type","refresh_token","refresh_token",session.optString("refreshToken"),"scope",SCOPE).toString(),"");if(java.util.Arrays.asList(400,401,403).contains(response.optInt("status")))throw new IllegalStateException("err.freeAuth");
        JSONObject d=data(response);secret(d.optString("access_token"));session.put("accessToken",d.optString("access_token"));if(!d.optString("refresh_token").isEmpty())session.put("refreshToken",d.optString("refresh_token"));session.put("expiresAt",now()+d.optLong("expires_in",86400));persist();return session.optString("accessToken");
    }
    private JSONObject authorized(String name)throws Exception {JSONObject r=http(name,"","Bearer "+access());if(r.optInt("status")==401||r.optInt("status")==403){session.put("expiresAt",0);r=http(name,"","Bearer "+access());}return r;}
    private void quota(JSONObject response,JSONObject d)throws Exception {JSONObject headers=response.optJSONObject("headers"),q=new JSONObject();for(String[] pair:new String[][]{{"limit","x-quota-limit"},{"remaining","x-quota-remaining"},{"reset","x-quota-reset"}}){String text=headers==null?"":headers.optString(pair[1]);q.put(pair[0],text.matches("[0-9]+")?Long.parseLong(text):JSONObject.NULL);}if(q.isNull("limit")&&d!=null&&d.has("maxBytes"))q.put("limit",d.opt("maxBytes"));if(q.isNull("limit")&&state.optJSONObject("quota")!=null)q.put("limit",state.getJSONObject("quota").opt("limit"));state.put("quota",q);if(d!=null&&d.has("subscribed"))state.put("activated",d.optBoolean("subscribed"));}
    private void cache(JSONObject response,JSONObject d)throws Exception {String value=d.optString("token");secret(value);pass=value;expiry=d.optLong("expires_at");if(expiry<=now())try{expiry=new JSONObject(new String(android.util.Base64.decode(value.split("\\.")[1],android.util.Base64.URL_SAFE|android.util.Base64.NO_WRAP),java.nio.charset.StandardCharsets.UTF_8)).optLong("exp");}catch(Exception ignored){}if(expiry<=now())expiry=now()+300;quota(response,null);state.put("activated",true);}
    synchronized JSONObject account(String operation)throws Exception {
        init();
        if(operation.equals("local")){if(readError)throw new IllegalStateException("err.freeStorage");return summary();}
        if(!operation.equals("status")&&!operation.equals("activate"))throw new IllegalArgumentException("err.action");
        JSONObject r=authorized(operation);int code=r.optInt("status");
        boolean acknowledged=operation.equals("activate")&&code>=200&&code<300&&r.optString("body").trim().isEmpty();
        JSONObject d=acknowledged?new JSONObject():data(r);quota(r,d);
        if(operation.equals("activate")&&!d.optBoolean("subscribed")){r=authorized("status");d=data(r);quota(r,d);}
        persist();
        if(operation.equals("activate")&&!state.optBoolean("activated"))throw new IllegalStateException("err.freeNotActivated");
        if(state.optBoolean("activated")){
            r=authorized("token");
            if(r.optInt("status")==429){quota(r,null);state.getJSONObject("quota").put("remaining",0);}
            else cache(r,data(r));
        }
        persist();return summary();
    }
    synchronized JSONArray resolve(JSONArray profiles,String source)throws Exception {init();boolean needed=false;for(int i=0;i<profiles.length();i++){JSONObject p=profiles.getJSONObject(i);if(p.optString("protocol").equals("firefox")&&p.optString("sourceId").equals(source)){XrayConfig.validate(p);needed=true;}}if(needed&&(pass.isEmpty()||expiry<=now()+60)){JSONObject r=authorized("token");cache(r,data(r));}JSONArray result=new JSONArray();for(int i=0;i<profiles.length();i++){JSONObject p=Jsons.copy(profiles.getJSONObject(i));if(p.optString("protocol").equals("firefox")){if(!p.optString("sourceId").equals(source))continue;p.put("proxyPass",pass);}result.put(p);}return result;}
    synchronized JSONObject switchAccount(String email)throws Exception {init();persist();JSONObject chosen=null;for(int i=0;i<accounts.length();i++)if(accounts.getJSONObject(i).optString("email").equals(email))chosen=accounts.getJSONObject(i);if(chosen==null)throw new IllegalStateException("err.freeAuth");session=chosen;restore();persist();return summary();}
    synchronized JSONObject logout()throws Exception {init();JSONArray remaining=new JSONArray();for(int i=0;i<accounts.length();i++)if(!accounts.getJSONObject(i).optString("email").equals(session.optString("email")))remaining.put(accounts.getJSONObject(i));accounts=remaining;session=accounts.optJSONObject(0);if(session==null)session=new JSONObject();restore();persist();return summary();}
    synchronized JSONObject remove(String email)throws Exception {init();JSONArray remaining=new JSONArray();for(int i=0;i<accounts.length();i++)if(!accounts.getJSONObject(i).optString("email").equals(email))remaining.put(accounts.getJSONObject(i));accounts=remaining;if(session.optString("email").equals(email)){session=accounts.optJSONObject(0);if(session==null)session=new JSONObject();restore();}persist();return summary();}
}
