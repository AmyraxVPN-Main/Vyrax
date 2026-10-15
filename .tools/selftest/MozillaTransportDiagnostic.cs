// Unauthenticated connectivity diagnostic. Never reads saved accounts or credentials.
using System;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Authentication;
using System.Threading.Tasks;
class MozillaTransportDiagnostic {
    static async Task Probe(string host,string path,bool tls12,bool systemProxy) {
        var label=host+" tls="+(tls12?"1.2":"default")+" route="+(systemProxy?"system":"direct");
        try {
            using(var handler=new HttpClientHandler{UseProxy=systemProxy,AllowAutoRedirect=false}) {
                if(tls12)handler.SslProtocols=SslProtocols.Tls12;
                using(var http=new HttpClient(handler){Timeout=TimeSpan.FromSeconds(10)})
                using(var response=await http.GetAsync("https://"+host+path,HttpCompletionOption.ResponseHeadersRead))
                    Console.WriteLine(label+" HTTP "+(int)response.StatusCode);
            }
        }catch(Exception e){
            var details="";
            for(var current=e;current!=null;current=current.InnerException){var web=current as WebException;details+=(details.Length>0?" > ":"")+current.GetType().Name+(web==null?"":"/"+web.Status);}
            Console.WriteLine(label+" "+details);
        }
    }
    static void Main(){
        Console.WriteLine("Framework default TLS: "+ServicePointManager.SecurityProtocol);
        Task.WhenAll(new[]{false,true}.SelectMany(tls=>new[]{false,true}.SelectMany(proxy=>new[]{
            Probe("api.accounts.firefox.com","/v1/account/login",tls,proxy),
            Probe("firefox.settings.services.mozilla.com","/v1/",tls,proxy)
        }))).GetAwaiter().GetResult();
    }
}
