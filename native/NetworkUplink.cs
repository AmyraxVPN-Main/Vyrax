using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Runtime.InteropServices;

namespace Vyrax {
// Capture the internet-facing interface before installing our TUN routes.
// Binding transport and bootstrap DNS to it keeps them outside the VPN path.
internal sealed class NetworkUplink {
    public readonly string Name;
    public readonly string[] Dns;
    NetworkUplink(string name,string[] dns) {Name=name;Dns=dns;}

    [StructLayout(LayoutKind.Sequential)]
    struct ForwardRow {
        public uint Destination,Mask,Policy,NextHop,InterfaceIndex,Type,Protocol,Age,NextHopAS,Metric1,Metric2,Metric3,Metric4,Metric5;
    }
    [DllImport("iphlpapi.dll")]static extern uint GetIpForwardTable(IntPtr table,ref uint size,bool ordered);
    [DllImport("iphlpapi.dll")]static extern uint GetBestInterface(uint destination,out uint index);

    static ForwardRow[] DefaultRoutes() {
        uint size=0;
        GetIpForwardTable(IntPtr.Zero,ref size,false);
        if(size<4||size>1024*1024)return new ForwardRow[0];
        // A route change between calls can grow the table; retry with its new size.
        for(int attempt=0;attempt<3;attempt++) {
            var buffer=Marshal.AllocHGlobal((int)size);
            try {
                var allocated=size;var result=GetIpForwardTable(buffer,ref size,false);
                if(result==122)continue;
                if(result!=0)return new ForwardRow[0];
                int count=Marshal.ReadInt32(buffer),rowSize=Marshal.SizeOf(typeof(ForwardRow));
                if(count<0||count>(allocated-4)/rowSize)return new ForwardRow[0];
                var routes=new List<ForwardRow>();
                for(int i=0;i<count;i++) {
                    var row=(ForwardRow)Marshal.PtrToStructure(IntPtr.Add(buffer,4+i*rowSize),typeof(ForwardRow));
                    if(row.Destination==0&&row.Mask==0&&row.Type!=2)routes.Add(row);
                }
                return routes.ToArray();
            } finally {Marshal.FreeHGlobal(buffer);}
        }
        return new ForwardRow[0];
    }

    internal static bool IsTunnel(string name,string description,NetworkInterfaceType type) {
        var text=(name+" "+description).ToLowerInvariant();
        return type==NetworkInterfaceType.Tunnel||String.Equals(name,"Vyrax",StringComparison.OrdinalIgnoreCase)||String.Equals(description,"Vyrax",StringComparison.OrdinalIgnoreCase)||text.Contains("tunnel")||text.Contains("wintun")||text.Contains("wireguard")||text.Contains("tap-")||text.Contains("tun adapter");
    }

    public static NetworkUplink Capture() {
        var routes=DefaultRoutes();uint best;
        GetBestInterface(BitConverter.ToUInt32(IPAddress.Parse("1.1.1.1").GetAddressBytes(),0),out best);
        var candidates=NetworkInterface.GetAllNetworkInterfaces()
            .Where(adapter=>adapter.OperationalStatus==OperationalStatus.Up&&adapter.NetworkInterfaceType!=NetworkInterfaceType.Loopback&&!IsTunnel(adapter.Name,adapter.Description,adapter.NetworkInterfaceType))
            .Select(adapter=>new {Adapter=adapter,Properties=adapter.GetIPProperties()})
            .Where(item=>item.Properties.GetIPv4Properties()!=null)
            .Select(item=>new {item.Adapter,item.Properties,Index=(uint)item.Properties.GetIPv4Properties().Index})
            .Where(item=>routes.Any(route=>route.InterfaceIndex==item.Index))
            .OrderBy(item=>item.Index==best?0:1)
            .ThenBy(item=>routes.Where(route=>route.InterfaceIndex==item.Index).Min(route=>route.Metric1));
        foreach(var item in candidates) {
            var dns=item.Properties.DnsAddresses.Where(address=>!IPAddress.IsLoopback(address)&&!address.Equals(IPAddress.Any)&&!address.Equals(IPAddress.IPv6Any)&&!address.IsIPv6LinkLocal&&(address.AddressFamily==AddressFamily.InterNetwork||address.AddressFamily==AddressFamily.InterNetworkV6)).Select(address=>address.ToString()).Distinct().ToArray();
            return new NetworkUplink(item.Adapter.Name,dns);
        }
        throw new Exception("err.uplink");
    }
}
}
