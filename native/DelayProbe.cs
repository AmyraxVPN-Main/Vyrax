using System;
using System.Diagnostics;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

namespace Vyrax {
// FlClash/Mihomo URLTest defaults: one URL, HEAD, eight-second probe budget,
// and a second HEAD on the warmed connection for unified delay.
internal static class DelayProbe {
    internal const string TestUrl="https://www.gstatic.com/generate_204";
    internal const int TimeoutMilliseconds=8000;

    internal static async Task<long?> Measure(int port,string url=TestUrl,int timeoutMilliseconds=TimeoutMilliseconds) {
        using(var handler=new HttpClientHandler {
            UseProxy=true,Proxy=new WebProxy("http://127.0.0.1:"+port),
            AllowAutoRedirect=false,UseCookies=false,
            SslProtocols=System.Security.Authentication.SslProtocols.Tls12
        })
        using(var client=new HttpClient(handler){Timeout=Timeout.InfiniteTimeSpan})
        using(var deadline=new CancellationTokenSource(timeoutMilliseconds)) {
            long first;
            try { first=await Head(client,url,deadline.Token); }
            catch(HttpRequestException) { return null; }
            catch(OperationCanceledException) { return null; }
            // A peer may close its keep-alive connection. As in Mihomo,
            // preserve the successful first measurement if the repeat fails.
            try { return await Head(client,url,deadline.Token); }
            catch(HttpRequestException) { return first; }
            catch(OperationCanceledException) { return first; }
        }
    }

    static async Task<long> Head(HttpClient client,string url,CancellationToken token) {
        var watch=Stopwatch.StartNew();
        using(var request=new HttpRequestMessage(HttpMethod.Head,url))
        using(var response=await client.SendAsync(request,HttpCompletionOption.ResponseHeadersRead,token)) {
            // URLTest measures a received HTTP response, regardless of status.
            // Redirects remain responses; their destination is never fetched.
            return Math.Max(1,watch.ElapsedMilliseconds);
        }
    }
}
}
