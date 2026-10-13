using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Net;
using System.Text.RegularExpressions;

namespace Vyrax {
public static class Preferences {
    public static Dictionary<string,object> Normalize(Dictionary<string,object> input) {
        var result=input==null?Json.Obj():new Dictionary<string,object>(input);
        // Disabled controls in older releases had true defaults. Do not silently
        // opt users into newly implemented automatic connection behaviour.
        if(Json.Int(result,"preferencesVersion")<1) {
            foreach(var key in new[]{"autoConnect","autoReconnect","splitTunneling","bypassSites","proxyShare"})result[key]=false;
        }
        result["preferencesVersion"]=1;
        return result;
    }
    public static string[] Addresses(IDictionary<string,object> settings,string key) {
        object raw;
        if(settings==null||!settings.TryGetValue(key,out raw)||raw==null)return new string[0];
        var items=raw is string?null:Json.Items(raw);
        var text=items==null?Convert.ToString(raw):String.Join("\n",items.Select(Convert.ToString).ToArray());
        if(text.Length>16000)throw new Exception("err.routeList");
        var result=new List<string>();
        foreach(var item in Regex.Split(text,@"[\s,;]+")) {
            if(item.Length==0)continue;
            var value=item.Trim().ToLowerInvariant();
            IPAddress ip;
            if(value.Contains("/")) {
                var parts=value.Split('/');int prefix;
                if(parts.Length!=2||!IPAddress.TryParse(parts[0],out ip)||!Int32.TryParse(parts[1],out prefix)||prefix<0||prefix>(ip.AddressFamily==System.Net.Sockets.AddressFamily.InterNetwork?32:128))throw new Exception("err.routeList");
                value=ip+"/"+prefix;
            } else if(IPAddress.TryParse(value,out ip))value=ip.ToString();
            else {
                if(value.StartsWith("*."))value=value.Substring(2);
                value=value.TrimEnd('.');
                try { value=new IdnMapping().GetAscii(value); } catch { throw new Exception("err.routeList"); }
                if(value.Length>253||!Regex.IsMatch(value,@"^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$"))throw new Exception("err.routeList");
            }
            if(!result.Contains(value))result.Add(value);
            if(result.Count>200)throw new Exception("err.routeList");
        }
        return result.ToArray();
    }
    public static bool IsIp(string value) { IPAddress ip;return IPAddress.TryParse(value.Split('/')[0],out ip); }
    public static void Validate(IDictionary<string,object> settings) {
        var split=Addresses(settings,"splitAddresses");var bypass=Addresses(settings,"bypassAddresses");
        if(Json.Bool(settings,"splitTunneling")&&Json.Bool(settings,"bypassSites"))throw new Exception("err.routeConflict");
        if((Json.Bool(settings,"splitTunneling")&&split.Length==0)||(Json.Bool(settings,"bypassSites")&&bypass.Length==0))throw new Exception("err.routeEmpty");
    }
}
}
