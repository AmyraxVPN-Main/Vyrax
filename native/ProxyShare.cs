using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Reflection;
using System.Runtime.InteropServices;

namespace Vyrax {
// A per-session Private-network firewall rule. Local-only control/metrics ports
// stay separate. No firewall changes are made while sharing is disabled.
public sealed class ProxyShare : IDisposable {
    readonly string name="Vyrax shared HTTP proxy - "+System.Diagnostics.Process.GetCurrentProcess().Id;
    bool active;
    public int Port { get; private set; }
    public static string[] Addresses() {
        return NetworkInterface.GetAllNetworkInterfaces()
            .Where(n=>n.OperationalStatus==OperationalStatus.Up&&n.NetworkInterfaceType!=NetworkInterfaceType.Loopback&&n.Name!="Vyrax"&&n.GetIPProperties().GatewayAddresses.Count>0)
            .SelectMany(n=>n.GetIPProperties().UnicastAddresses)
            .Where(a=>a.Address.AddressFamily==AddressFamily.InterNetwork)
            .Select(a=>a.Address.ToString()).Where(a=>a.StartsWith("10.")||a.StartsWith("192.168.")||(a.StartsWith("172.")&&Int32.Parse(a.Split('.')[1])>=16&&Int32.Parse(a.Split('.')[1])<=31)).Distinct().ToArray();
    }
    static object Get(object obj,string key) {return obj.GetType().InvokeMember(key,BindingFlags.GetProperty,null,obj,null);}
    static void Set(object obj,string key,object value) {obj.GetType().InvokeMember(key,BindingFlags.SetProperty,null,obj,new[]{value});}
    static void Call(object obj,string key,object value) {obj.GetType().InvokeMember(key,BindingFlags.InvokeMethod,null,obj,new[]{value});}
    public void Enable(string executable,int port) {
        if(Addresses().Length==0)throw new Exception("err.shareNetwork");
        object policy=null,rules=null,rule=null;
        try {
            policy=Activator.CreateInstance(Type.GetTypeFromProgID("HNetCfg.FwPolicy2"));rules=Get(policy,"Rules");
            if((Convert.ToInt32(Get(policy,"CurrentProfileTypes"))&2)==0)throw new Exception("err.sharePrivate");
            // Clean only this executable's rules from instances that have exited.
            var stale=new List<string>();
            foreach(var entry in (IEnumerable)rules) {
                try {
                    var ruleName=Convert.ToString(Get(entry,"Name"));int pid;
                    if(!ruleName.StartsWith("Vyrax shared HTTP proxy - ")||!String.Equals(Convert.ToString(Get(entry,"ApplicationName")),executable,StringComparison.OrdinalIgnoreCase)||!Int32.TryParse(ruleName.Substring("Vyrax shared HTTP proxy - ".Length),out pid))continue;
                    try {using(var process=System.Diagnostics.Process.GetProcessById(pid)){if(process.HasExited)stale.Add(ruleName);}}
                    catch(ArgumentException){stale.Add(ruleName);}
                } finally {if(Marshal.IsComObject(entry))Marshal.FinalReleaseComObject(entry);}
            }
            foreach(var ruleName in stale)Call(rules,"Remove",ruleName);
            // A previous crashed instance with this PID may have left its rule.
            Call(rules,"Remove",name);
            rule=Activator.CreateInstance(Type.GetTypeFromProgID("HNetCfg.FWRule"));
            Set(rule,"Name",name);Set(rule,"Description","Vyrax HTTP proxy for devices on the same private network");
            Set(rule,"ApplicationName",executable);Set(rule,"Protocol",6);Set(rule,"LocalPorts",port.ToString());
            Set(rule,"RemoteAddresses","LocalSubnet");Set(rule,"Direction",1);Set(rule,"Profiles",2);Set(rule,"Action",1);Set(rule,"Enabled",true);
            Call(rules,"Add",rule);active=true;Port=port;
        } catch(Exception e) {if(e.Message=="err.sharePrivate")throw;throw new Exception("err.shareFirewall");}
        finally {foreach(var obj in new[]{rule,rules,policy})if(obj!=null&&Marshal.IsComObject(obj))Marshal.FinalReleaseComObject(obj);}
    }
    public object Snapshot() {return active?Json.Obj("port",Port,"hosts",Addresses()):null;}
    public void Dispose() {
        if(!active)return;
        object policy=null,rules=null;
        try {policy=Activator.CreateInstance(Type.GetTypeFromProgID("HNetCfg.FwPolicy2"));rules=Get(policy,"Rules");Call(rules,"Remove",name);}
        finally {active=false;Port=0;foreach(var obj in new[]{rules,policy})if(obj!=null&&Marshal.IsComObject(obj))Marshal.FinalReleaseComObject(obj);}
    }
}
}
