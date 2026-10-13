using System;
using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Vyrax;

public static class TunnelProbeSelfTest {
    public static int Main() {
        try { Run().GetAwaiter().GetResult();return 0; }
        catch(Exception e) { Console.WriteLine("FAIL: "+e);return 1; }
    }

    static async Task Run() {
        using(var cancelled=new CancellationTokenSource()) {
            cancelled.Cancel();
            try { await Engine.ProbeTls(IPAddress.Loopback,new IPEndPoint(IPAddress.Loopback,1),"dns.google",cancelled.Token);throw new Exception("Cancellation ignored"); }
            catch(OperationCanceledException) { Console.WriteLine("PASS: already-cancelled probe never connects"); }
        }
        await StalledTls(false);
        await StalledTls(true);
        await InvalidTls();
        await HealthyRace();
        await FailedRace();
        await CancelledRace();
    }

    static async Task HealthyRace() {
        int stopped=0;
        var timer=Stopwatch.StartNew();
        var winner=await Engine.FirstHealthy(new Func<CancellationToken,Task>[] {
            async token=>{try{await Task.Delay(12000,token);}finally{Interlocked.Increment(ref stopped);}},
            async token=>{await Task.Delay(60,token);},
            async token=>{try{await Task.Delay(12000,token);}finally{Interlocked.Increment(ref stopped);}}
        },CancellationToken.None);
        if(winner!=1||stopped!=2||timer.ElapsedMilliseconds>1500)throw new Exception("Healthy second target waited for the blocked first target or left probes alive");
        Console.WriteLine("PASS: healthy second target wins in "+timer.ElapsedMilliseconds+" ms; both losing probes are cancelled and drained");
    }
    static async Task FailedRace() {
        var winner=await Engine.FirstHealthy(new Func<CancellationToken,Task>[] {
            async token=>{await Task.Delay(10,token);throw new Exception("unhealthy");},
            async token=>{await Task.Delay(30,token);throw new TimeoutException();}
        },CancellationToken.None);
        if(winner!=-1)throw new Exception("Failed health probes marked the connection healthy");
        Console.WriteLine("PASS: all-failed checks cannot mark the connection healthy");
    }
    static async Task CancelledRace() {
        using(var cancel=new CancellationTokenSource(80)) {
            int stopped=0;
            Func<CancellationToken,Task> wait=async token=>{try{await Task.Delay(12000,token);}finally{Interlocked.Increment(ref stopped);}};
            try {await Engine.FirstHealthy(new[]{wait,wait,wait},cancel.Token);throw new Exception("User cancellation ignored");}
            catch(OperationCanceledException){if(stopped!=3)throw new Exception("Cancelled probes remained alive");}
        }
        Console.WriteLine("PASS: user cancellation drains all concurrent health probes");
    }

    static async Task StalledTls(bool cancel) {
        var server=new TcpListener(IPAddress.Loopback,0);
        server.Start();
        try {
            using(var source=new CancellationTokenSource()) {
                var timer=Stopwatch.StartNew();
                var task=Engine.ProbeTls(IPAddress.Loopback,(IPEndPoint)server.LocalEndpoint,"dns.google",source.Token,cancel?5000:400);
                using(var client=await server.AcceptTcpClientAsync()) {
                    var hello=new byte[4096];
                    int count=await client.GetStream().ReadAsync(hello,0,hello.Length);
                    if(count<11||hello[0]!=22||hello[9]!=3||hello[10]!=3)throw new Exception("Probe did not offer TLS 1.2");
                    if(!Encoding.ASCII.GetString(hello,0,count).Contains("dns.google"))throw new Exception("Probe sent the wrong SNI");
                    if(cancel)source.Cancel();
                    if(await Task.WhenAny(task,Task.Delay(3000))!=task)throw new Exception("Probe hung on a stalled TLS peer");
                    try { await task;throw new Exception("Stalled TLS was accepted"); }
                    catch(OperationCanceledException) { if(!cancel)throw; }
                    catch(TimeoutException e) { if(cancel||!e.Message.Contains("TLS handshake"))throw; }
                    if(timer.ElapsedMilliseconds>3000)throw new Exception("Probe did not stop promptly");
                }
            }
            Console.WriteLine("PASS: TLS 1.2 + correct SNI; stalled handshake "+(cancel?"cancelled":"timed out"));
        } finally { server.Stop(); }
    }

    static async Task InvalidTls() {
        var server=new TcpListener(IPAddress.Loopback,0);
        server.Start();
        try {
            var task=Engine.ProbeTls(IPAddress.Loopback,(IPEndPoint)server.LocalEndpoint,"dns.google",CancellationToken.None,2000);
            using(var client=await server.AcceptTcpClientAsync()) {
                var response=Encoding.ASCII.GetBytes("HTTP/1.1 200 OK\r\n\r\n");
                await client.GetStream().WriteAsync(response,0,response.Length);
            }
            bool failed=false;
            try { await task; } catch(Exception e) { failed=!(e is TimeoutException); }
            if(!failed)throw new Exception("Invalid TLS was accepted or not detected promptly");
            Console.WriteLine("PASS: TCP-only / invalid TLS response cannot mark the VPN connected");
        } finally { server.Stop(); }
    }
}
