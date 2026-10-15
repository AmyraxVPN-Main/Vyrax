using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Authentication;
using System.Threading;
using System.Threading.Tasks;
using Vyrax;
class FreeProviderSelfTest {
    class Transport:HttpMessageHandler {
        public int passes,denied;public bool fail;
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage r,CancellationToken token) {
            if(r.RequestUri.Host!="vpn.mozilla.org")throw new Exception("Unexpected endpoint");
            if(denied>0)return Task.FromResult(new HttpResponseMessage((HttpStatusCode)denied){Content=new StringContent("")});
            if(fail)return Task.FromResult(new HttpResponseMessage(HttpStatusCode.ServiceUnavailable){Content=new StringContent("{}")});
            var response=new HttpResponseMessage(HttpStatusCode.OK);
            if(r.RequestUri.AbsolutePath.EndsWith("/token")){passes++;response.Content=new StringContent(Json.Write(Json.Obj("token","synthetic-pass","expires_at",2000000000)));response.Headers.Add("X-Quota-Limit","53687091200");response.Headers.Add("X-Quota-Remaining","21474836480");response.Headers.Add("X-Quota-Reset","1900000000");}
            else response.Content=new StringContent("{\"subscribed\":true,\"maxBytes\":53687091200}");
            return Task.FromResult(response);
        }
    }
    class ActivationTransport:HttpMessageHandler {
        public string activation="{\"subscribed\":true,\"maxBytes\":53687091200}",status="{\"subscribed\":true,\"maxBytes\":53687091200}";
        public int activationCode=200,tokenCode=200;
        public readonly List<string> requests=new List<string>();
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,CancellationToken token) {
            var endpoint=request.RequestUri.Segments.Last();requests.Add(endpoint);
            if(request.RequestUri.Host!="vpn.mozilla.org")throw new Exception("Unexpected endpoint");
            var response=new HttpResponseMessage(HttpStatusCode.OK);
            if(endpoint=="activate"){response.StatusCode=(HttpStatusCode)activationCode;response.Content=new StringContent(activation);}
            else if(endpoint=="status")response.Content=new StringContent(status);
            else if(endpoint=="token"){
                response.StatusCode=(HttpStatusCode)tokenCode;response.Content=new StringContent("{\"token\":\"synthetic-pass\",\"expires_at\":2000000000}");
                response.Headers.Add("X-Quota-Limit","53687091200");response.Headers.Add("X-Quota-Remaining","21474836480");
            }else throw new Exception("Unexpected endpoint");
            return Task.FromResult(response);
        }
    }
    static void Check(bool value,string message){if(!value)throw new Exception(message);Console.WriteLine("PASS: "+message);}
    static Dictionary<string,object> Session(string email){return Json.Obj("email",email,"accessToken","synthetic-access","refreshToken","synthetic-refresh","expiresAt",2000000000);}
    static int Main(string[] args){try{Run(args.Contains("--online")).GetAwaiter().GetResult();return 0;}catch(Exception e){Console.Error.WriteLine(e.Message);return 1;}}
    static async Task Run(bool online){
        var root=Path.Combine(Path.GetTempPath(),"vyrax-free-test-"+Guid.NewGuid().ToString("N"));
        try{
            using(var system=FreeProvider.CreateHandler()){
                Check(system.SslProtocols==SslProtocols.Tls12,"Mozilla transport negotiates TLS 1.2 in the Framework host");
                Check(system.UseProxy&&system.Proxy==null,"disconnected provider respects the system proxy");
                Check(!system.AllowAutoRedirect&&!system.UseCookies,"credential requests cannot follow redirects or retain cookies");
            }
            var route=new WebProxy("http://127.0.0.1:12345");
            using(var routed=FreeProvider.CreateHandler(route)){
                Check(routed.UseProxy&&routed.Proxy==route&&routed.SslProtocols==SslProtocols.Tls12,"active core route retains explicit proxy and modern TLS");
            }
            if(online){
                var live=new FreeProvider(Path.Combine(root,"live"));
                var list=(Dictionary<string,object>)await live.Request(Json.Obj("endpoint","servers"));
                Check(Json.Int(list,"status")==200&&Json.Read(Json.Str(list,"body")).ContainsKey("data"),"unauthenticated Mozilla server list works through the real provider transport");
                var login=(Dictionary<string,object>)await live.Request(Json.Obj("endpoint","login","body","{}"));
                Check(Json.Int(login,"status")>=400&&Json.Int(login,"status")<500,"Firefox login endpoint is reachable without account data (HTTP "+Json.Int(login,"status")+")");
            }
            var http=new Transport();var provider=new FreeProvider(root,new HttpClient(http));
            var p=Json.Obj("id","firefox:test","protocol","firefox","sourceId","vyrax-firefox-free","host","test.m1.fastly-masque.net","port",2499);
            await provider.Save(Session("a@example.test"));
            var results=await Task.WhenAll(provider.Resolve(new[]{p}),provider.Resolve(new[]{p}),provider.Resolve(new[]{p}));
            Check(http.passes==1,"concurrent native probes request one pass");Check(!p.ContainsKey("proxyPass"),"saved metadata is not mutated by runtime preparation");
            var outbound=(Dictionary<string,object>)Config.Outbound(results[0][0]);Check(Json.Str(outbound,"protocol")=="http","native core uses HTTP CONNECT");
            var status=(Dictionary<string,object>)await provider.Account("local");Check(!Json.Write(status).Contains("synthetic"),"account summary exposes no credentials");
            var quota=(Dictionary<string,object>)status["quota"];Check(Convert.ToInt64(quota["remaining"])==21474836480L,"remaining bytes come from Guardian headers");
            http.fail=true;bool transient=false;try{await provider.Account("status");}catch(Exception e){transient=e.Message=="err.freeService";}Check(transient&&Json.Bool((Dictionary<string,object>)await provider.Account("local"),"signedIn"),"transient service error retains saved account");http.fail=false;
            http.denied=406;bool challenge=false;try{await provider.Account("status");}catch(Exception e){challenge=e.Message=="err.freeChallenge";}Check(challenge,"Guardian protection is distinct from account eligibility");
            Check(Json.Bool((Dictionary<string,object>)await provider.Account("local"),"signedIn")&&http.passes==1,"web protection preserves account and does not request another pass");http.denied=0;
            await provider.Save(Session("b@example.test"));await provider.Remove("a@example.test");status=(Dictionary<string,object>)await provider.Account("local");Check(Json.Str(status,"email")=="b@example.test","removing inactive account preserves active account");
            await provider.Remove("b@example.test");status=(Dictionary<string,object>)await provider.Account("local");Check(!Json.Bool(status,"signedIn"),"removing final account clears login");
            var restored=new FreeProvider(root,new HttpClient(http));status=(Dictionary<string,object>)await restored.Account("local");Check(!Json.Bool(status,"signedIn"),"account removal persists in encrypted storage");
            bool rejected=false;try{await provider.Request(Json.Obj("endpoint","https://evil.test"));}catch(Exception e){rejected=e.Message=="err.action";}Check(rejected,"arbitrary credential endpoints rejected");
            p["host"]="fastly-masque.net.evil.test";rejected=false;try{Config.Validate(p);}catch(Exception e){rejected=e.Message=="err.freeServer";}Check(rejected,"proxy pass cannot be sent to a foreign host");
            foreach(var mode in new[]{"confirmed","acknowledged","not-active","blocked","quota-blocked","malformed"}){
                var transport=new ActivationTransport();
                if(mode=="acknowledged"){transport.activation="";transport.activationCode=204;}
                if(mode=="not-active"){transport.activation="{}";transport.status="{\"subscribed\":false}";}
                if(mode=="blocked")transport.activationCode=406;
                if(mode=="quota-blocked")transport.tokenCode=406;
                if(mode=="malformed")transport.activation="<html>not entitlement data</html>";
                var fixture=new FreeProvider(Path.Combine(root,mode),new HttpClient(transport));await fixture.Save(Session("activation@example.test"));
                string error="";Dictionary<string,object> account=null;try{account=(Dictionary<string,object>)await fixture.Account("activate");}catch(Exception e){error=e.Message;}
                if(mode=="confirmed"||mode=="acknowledged"){
                    Check(error==""&&Json.Bool(account,"activated"),mode+" activation returns confirmed access");
                    Check(Convert.ToInt64(((Dictionary<string,object>)account["quota"])["remaining"])==21474836480L,mode+" activation immediately returns official remaining data");
                    Check(String.Join(",",transport.requests)==(mode=="confirmed"?"activate,token":"activate,status,token"),mode+" activation performs only the required official requests");
                }else{
                    var expected=mode=="not-active"?"err.freeNotActivated":mode=="malformed"?"err.freeService":"err.freeChallenge";
                    Check(error==expected,mode+" activation reports an explicit error");
                    var local=(Dictionary<string,object>)await fixture.Account("local");
                    Check(Json.Bool(local,"signedIn")&&Json.Bool(local,"activated")== (mode=="quota-blocked"),mode+" activation preserves the account and actual confirmed state");
                    if(mode=="blocked"||mode=="malformed")Check(transport.requests.Count==1,mode+" activation is not retried");
                    if(mode=="not-active")Check(!transport.requests.Contains("token"),"unconfirmed access cannot fetch a proxy pass");
                }
            }
        }finally{if(Directory.Exists(root))Directory.Delete(root,true);}
    }
}
