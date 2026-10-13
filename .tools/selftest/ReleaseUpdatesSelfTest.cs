using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

class ReleaseUpdatesSelfTest {
    static int checks;
    static MethodInfo fetch,link;
    static readonly Uri endpoint=new Uri("https://api.github.com/repos/AmyraxVPN-Main/Vyrax/releases/latest");
    static void Check(bool value,string name) { if(!value)throw new Exception(name);checks++;Console.WriteLine("PASS: "+name); }
    static async Task<object> Fetch(HttpClient client,CancellationToken stop) { return await (Task<object>)fetch.Invoke(null,new object[]{client,endpoint,stop}); }
    static async Task Failure(HttpResponseMessage response,string name) {
        using(var client=new HttpClient(new Handler(response))) {
            bool failed=false;try{await Fetch(client,CancellationToken.None);}catch{failed=true;}Check(failed,name);
        }
    }
    public static int Main(string[] args) { try{Run(args[0]).GetAwaiter().GetResult();return 0;}catch(Exception e){Console.WriteLine(e.Message);return 1;} }
    static async Task Run(string file) {
        var type=Assembly.LoadFrom(file).GetType("Vyrax.AppUpdates");
        fetch=type.GetMethod("FetchLatest",BindingFlags.Static|BindingFlags.NonPublic);link=type.GetMethod("Link");
        var body="{\"tag_name\":\"v0.1.18\",\"draft\":false,\"prerelease\":false,\"published_at\":\"2026-10-13T00:00:00Z\",\"html_url\":\"https://github.com/AmyraxVPN-Main/Vyrax/releases/tag/v0.1.18\",\"body\":\"ignored release text\",\"author\":{\"secret\":\"not forwarded\"}}";
        var handler=new Handler(new HttpResponseMessage(HttpStatusCode.OK){Content=new StringContent(body,Encoding.UTF8,"application/json")});
        using(var client=new HttpClient(handler)) {
            var result=(Dictionary<string,object>)await Fetch(client,CancellationToken.None);
            var release=(Dictionary<string,object>)result["release"];
            Check(release.Count==5&&!release.ContainsKey("body")&&!release.ContainsKey("author"),"only release metadata reaches the interface");
            Check(Convert.ToString(release["tag_name"])=="v0.1.18","published tag is preserved");
            Check(handler.Method=="GET"&&handler.Url==endpoint.ToString(),"only the configured GitHub endpoint is requested");
            Check(handler.Accept.Contains("application/vnd.github+json")&&handler.UserAgent.StartsWith("Vyrax/"),"GitHub headers identify the public app");
            Check(!handler.Authorization&&handler.Body==null,"no credentials or profile data are transmitted");
        }
        using(var client=new HttpClient(new Handler(new HttpResponseMessage(HttpStatusCode.NotFound)))) {
            var result=(Dictionary<string,object>)await Fetch(client,CancellationToken.None);Check(result["release"]==null,"an empty release page produces no update");
        }
        foreach(var code in new[]{403,429,500,301})await Failure(new HttpResponseMessage((HttpStatusCode)code),"HTTP "+code+" is unavailable rather than a false update");
        await Failure(new HttpResponseMessage(HttpStatusCode.OK){Content=new StringContent("invalid json")},"malformed JSON is rejected");
        var large=new StringContent(new string('x',262145));large.Headers.ContentLength=262145;
        await Failure(new HttpResponseMessage(HttpStatusCode.OK){Content=large},"oversized declared response is rejected");
        await Failure(new HttpResponseMessage(HttpStatusCode.OK){Content=new StreamContent(new Unseekable(new byte[262145]))},"unknown-length response is bounded while streaming");
        using(var cancelled=new CancellationTokenSource())using(var client=new HttpClient(new Handler(new HttpResponseMessage(HttpStatusCode.OK)))) {
            cancelled.Cancel();bool failed=false;try{await Fetch(client,cancelled.Token);}catch{failed=true;}Check(failed,"cancellation stops the check");
        }
        Check((string)link.Invoke(null,new object[]{"telegram"})=="https://t.me/AmyraxVPN","Telegram opens the configured channel");
        Check((string)link.Invoke(null,new object[]{"release"})=="https://github.com/AmyraxVPN-Main/Vyrax/releases/latest","update opens latest release page");
        Check((string)link.Invoke(null,new object[]{"source"})=="https://github.com/AmyraxVPN-Main/Vyrax","source opens the configured repository");
        foreach(var target in new[]{"https://example.test","file:///C:/test","cmd.exe","release?redirect=1"}) {
            bool failed=false;try{link.Invoke(null,new object[]{target});}catch{failed=true;}Check(failed,"arbitrary external target is rejected");
        }
        Console.WriteLine(checks+" native update transport and link checks passed");
    }
    sealed class Handler : HttpMessageHandler {
        readonly HttpResponseMessage response;
        public string Method,Url,Accept,UserAgent;public HttpContent Body;public bool Authorization;
        public Handler(HttpResponseMessage value){response=value;}
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,CancellationToken stop) {
            stop.ThrowIfCancellationRequested();Method=request.Method.ToString();Url=request.RequestUri.ToString();Accept=request.Headers.Accept.ToString();UserAgent=request.Headers.UserAgent.ToString();Body=request.Content;Authorization=request.Headers.Authorization!=null;
            return Task.FromResult(response);
        }
    }
    sealed class Unseekable : MemoryStream {
        public Unseekable(byte[] bytes):base(bytes){}
        public override bool CanSeek{get{return false;}}
    }
}
