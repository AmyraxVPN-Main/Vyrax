package com.amyrax.vyrax;

import org.junit.Test;
import static org.junit.Assert.*;
import org.json.*;
import java.util.*;

public class FreeProviderTest {
    private static final class Vault implements FreeProvider.Vault {
        JSONObject saved=new JSONObject();
        public JSONObject load()throws Exception{return Jsons.copy(saved);}
        public void save(JSONObject value)throws Exception{saved=Jsons.copy(value);}
    }
    private JSONObject response(int status,String body){return Jsons.obj("status",status,"body",body,"headers",Jsons.obj("x-quota-remaining","4096"));}
    private void activation(String mode)throws Exception {
        Vault vault=new Vault();List<String> calls=new ArrayList<>();
        FreeProvider provider=new FreeProvider(vault,(name,body,authorization)->{
            calls.add(name);
            if(name.equals("activate")){
                if(mode.equals("challenge"))return response(406,"");
                if(mode.equals("acknowledged"))return response(204,"");
                return response(200,mode.equals("confirmed")?"{\"subscribed\":true,\"maxBytes\":53687091200}":"{}");
            }
            if(name.equals("status"))return response(200,mode.equals("inactive")?"{\"subscribed\":false}":"{\"subscribed\":true,\"maxBytes\":53687091200}");
            if(mode.equals("quotaFailure"))return response(406,"");
            if(mode.equals("exhausted"))return response(429,"");
            return response(200,"{\"token\":\"synthetic-pass\",\"expires_at\":9999999999}");
        });
        provider.save(Jsons.obj("email","fixture@example.test","accessToken","synthetic-access","refreshToken","synthetic-refresh","expiresAt",9999999999L));
        String error=mode.equals("inactive")?"err.freeNotActivated":mode.equals("challenge")||mode.equals("quotaFailure")?"err.freeChallenge":null;
        if(error!=null){try{provider.account("activate");fail("Expected "+error);}catch(IllegalStateException failure){assertEquals(error,failure.getMessage());}}
        else {
            JSONObject result=provider.account("activate");assertTrue(result.getBoolean("activated"));
            assertEquals(mode.equals("exhausted")?0:4096,result.getJSONObject("quota").getLong("remaining"));
        }
        JSONObject local=provider.account("local");assertTrue(local.getBoolean("signedIn"));
        assertEquals(!mode.equals("inactive")&&!mode.equals("challenge"),local.getBoolean("activated"));
        assertEquals(mode.equals("confirmed")||mode.equals("challenge")?0:1,Collections.frequency(calls,"status"));
        assertEquals(mode.equals("inactive")||mode.equals("challenge")?0:1,Collections.frequency(calls,"token"));
        assertEquals(1,Collections.frequency(calls,"activate"));assertFalse(vault.saved.toString().contains("synthetic-pass"));
    }
    @Test public void confirmedActivationLoadsQuota()throws Exception{activation("confirmed");}
    @Test public void emptyAcknowledgementChecksOfficialStatus()throws Exception{activation("acknowledged");}
    @Test public void inactiveAccountReportsError()throws Exception{activation("inactive");}
    @Test public void challengeIsNotRetried()throws Exception{activation("challenge");}
    @Test public void quotaErrorKeepsConfirmedEntitlement()throws Exception{activation("quotaFailure");}
    @Test public void exhaustedAccountReportsZeroRemaining()throws Exception{activation("exhausted");}
}
