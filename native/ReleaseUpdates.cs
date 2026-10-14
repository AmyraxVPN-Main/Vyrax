// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Reflection;
using System.Security.Authentication;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;

namespace Vyrax {
public static class AppUpdates {
    static readonly Dictionary<string,object> project=ReadProject();
    static readonly HttpClient client=CreateClient();
    static Dictionary<string,object> ReadProject() {
        using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("Vyrax.project.json"))
        using(var reader=new StreamReader(stream,Encoding.UTF8))return Json.Read(reader.ReadToEnd());
    }
    static string Repository {
        get {
            var value=Json.Str(project,"repository");
            if(!Regex.IsMatch(value,@"\A[A-Za-z0-9-]+/[A-Za-z0-9_.-]+\z"))throw new Exception("err.action");
            return value;
        }
    }
    static HttpClient CreateClient() {
        // Respect the user's active system proxy; no profile/config data is sent.
        var handler=new HttpClientHandler{UseProxy=true,UseCookies=false,AllowAutoRedirect=false,
            AutomaticDecompression=DecompressionMethods.GZip|DecompressionMethods.Deflate,SslProtocols=SslProtocols.Tls12};
        return new HttpClient(handler){Timeout=Timeout.InfiniteTimeSpan};
    }
    public static async Task<object> Latest() {
        using(var deadline=new CancellationTokenSource(TimeSpan.FromSeconds(12)))
            return await FetchLatest(client,new Uri("https://api.github.com/repos/"+Repository+"/releases/latest"),deadline.Token);
    }
    internal static async Task<object> FetchLatest(HttpClient transport,Uri endpoint,CancellationToken stop) {
        using(var request=new HttpRequestMessage(HttpMethod.Get,endpoint)) {
            request.Headers.UserAgent.ParseAdd("Vyrax/"+Assembly.GetExecutingAssembly().GetName().Version.ToString(3));
            request.Headers.Accept.ParseAdd("application/vnd.github+json");
            request.Headers.Add("X-GitHub-Api-Version","2022-11-28");
            using(var response=await transport.SendAsync(request,HttpCompletionOption.ResponseHeadersRead,stop)) {
                if(response.StatusCode==HttpStatusCode.NotFound)return Json.Obj("release",null);
                if(!response.IsSuccessStatusCode)throw new Exception("err.updateCheck");
                const int limit=262144;
                if(response.Content.Headers.ContentLength>limit)throw new Exception("err.updateCheck");
                using(var input=await response.Content.ReadAsStreamAsync())
                using(var output=new MemoryStream()) {
                    var buffer=new byte[8192];int n;
                    while((n=await input.ReadAsync(buffer,0,buffer.Length,stop))>0) {
                        if(output.Length+n>limit)throw new Exception("err.updateCheck");
                        output.Write(buffer,0,n);
                    }
                    var data=Json.Read(Encoding.UTF8.GetString(output.ToArray()));
                    var safe=new Dictionary<string,object>();
                    foreach(var key in new[]{"tag_name","draft","prerelease","published_at","html_url"}) {
                        object value;if(data.TryGetValue(key,out value))safe[key]=value;
                    }
                    return Json.Obj("release",safe);
                }
            }
        }
    }
    public static string Link(string target) {
        if(target=="firefoxAccount")return "https://accounts.firefox.com/";
        if(target=="firefoxHelp")return "https://support.mozilla.org/en-US/kb/firefox-vpn";
        if(target=="source")return "https://github.com/"+Repository;
        if(target=="release")return "https://github.com/"+Repository+"/releases/latest";
        if(target=="telegram") {
            var url=Json.Str(project,"telegram");
            if(Regex.IsMatch(url,@"\Ahttps://t\.me/[A-Za-z0-9_]{5,32}\z"))return url;
        }
        throw new Exception("err.action");
    }
    public static void Open(string target) { Process.Start(new ProcessStartInfo(Link(target)){UseShellExecute=true}); }
}
}
