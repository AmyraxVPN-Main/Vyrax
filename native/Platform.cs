using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using Microsoft.Win32;

namespace Vyrax {
/* ذخیره‌سازی رمزنگاری‌شده با DPAPI برای همان حساب ویندوز. */
public sealed class Store {
    public readonly string Root;
    readonly string file;
    public Store(string customRoot=null) {
        Root=customRoot??Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Vyrax");
        Directory.CreateDirectory(Root);
        try { Restrict(Root); } catch { /* روی فایل‌سیستم‌های غیر NTFS بی‌اهمیت است */ }
        file=Path.Combine(Root,"profiles.bin");
    }
    /* پوشهٔ دادهٔ خودِ برنامه: فقط کاربرِ جاری و SYSTEM.
       دقت کن این یک مرزِ امنیتی نیست — کاربرِ جاری همان کسی است که ممکن است
       مهاجم باشد. برای پوشه‌ای که پروسهٔ ممتاز در آن می‌نویسد از RestrictAdmin
       استفاده کن. */
    public static void Restrict(string folder) {
        var sec=new DirectorySecurity();sec.SetAccessRuleProtection(true,false);
        sec.AddAccessRule(new FileSystemAccessRule(WindowsIdentity.GetCurrent().User,FileSystemRights.FullControl,InheritanceFlags.ContainerInherit|InheritanceFlags.ObjectInherit,PropagationFlags.None,AccessControlType.Allow));
        sec.AddAccessRule(new FileSystemAccessRule(new SecurityIdentifier(WellKnownSidType.LocalSystemSid,null),FileSystemRights.FullControl,InheritanceFlags.ContainerInherit|InheritanceFlags.ObjectInherit,PropagationFlags.None,AccessControlType.Allow));
        Directory.SetAccessControl(folder,sec);
    }

    /* همان کار، ولی بدونِ دادنِ دسترسی به کاربرِ جاری: فقط SYSTEM و Administrators.
       برای پوشه‌ای که هلپرِ ممتاز در آن می‌نویسد تا کاربرِ بی‌دسترسی نتواند بین
       نوشتن و خواندن محتوا را عوض کند.

       مالک را هم Administrators می‌کنیم: مالکِ فعلی هر وقت بخواهد می‌تواند با
       WRITE_DAC قفل را باز کند، پس DACL تنها کافی نیست. اگر خودمان پوشه را ساخته
       باشیم مالک از قبل Administrators است و این خط عملاً تأییدی است؛ روی بعضی
       سیستم‌ها هم SetOwner به SeTakeOwnershipPrivilege نیاز دارد، پس شکستش را
       نمی‌کشیم — فراخوان (HelperServer.PrepareRoot) *قبل* از این‌جا بررسی می‌کند
       که پوشهٔ موجود مالکِ غیرمدیر نباشد. */
    public static void RestrictAdmin(string folder) {
        var sec=new DirectorySecurity();sec.SetAccessRuleProtection(true,false);
        var inherit=InheritanceFlags.ContainerInherit|InheritanceFlags.ObjectInherit;
        sec.AddAccessRule(new FileSystemAccessRule(new SecurityIdentifier(WellKnownSidType.LocalSystemSid,null),FileSystemRights.FullControl,inherit,PropagationFlags.None,AccessControlType.Allow));
        sec.AddAccessRule(new FileSystemAccessRule(new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid,null),FileSystemRights.FullControl,inherit,PropagationFlags.None,AccessControlType.Allow));
        try { sec.SetOwner(new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid,null)); } catch { }
        Directory.SetAccessControl(folder,sec);
    }
    public Dictionary<string,object> Load() {
        if(!File.Exists(file))return Json.Obj("profiles",new object[0],"selectedId","","settings",Json.Obj("theme","dark","mode","proxy","mtu",1280));
        try { var saved=Json.Read(Encoding.UTF8.GetString(ProtectedData.Unprotect(File.ReadAllBytes(file),null,DataProtectionScope.CurrentUser)));object raw;saved["settings"]=Preferences.Normalize(saved.TryGetValue("settings",out raw)?raw as Dictionary<string,object>:null);return saved; }
        catch { throw new Exception("err.storeRead"); }
    }
    public void Save(object value) {
        var text=Json.Write(value);
        if(text.Length>8*1024*1024)throw new Exception("err.storeWrite");
        var bytes=ProtectedData.Protect(Encoding.UTF8.GetBytes(text),null,DataProtectionScope.CurrentUser);
        var temp=file+".tmp";File.WriteAllBytes(temp,bytes);
        if(File.Exists(file))File.Replace(temp,file,null);else File.Move(temp,file);
    }
}

/* پروکسی سیستم؛ تنظیمات قبلی را در دفترچه‌ای نگه می‌دارد تا همیشه بازگردانی شود. */
public sealed class ProxySettings {
    readonly string RegistryPath;
    readonly bool notify;
    readonly string journal;
    [DllImport("wininet.dll",SetLastError=true)]static extern bool InternetSetOption(IntPtr handle,int option,IntPtr buffer,int length);
    public ProxySettings(string root,string testRegistryPath=null,bool broadcast=true) {
        RegistryPath=testRegistryPath??@"Software\Microsoft\Windows\CurrentVersion\Internet Settings";
        notify=broadcast;journal=Path.Combine(root,"proxy-recovery.json");Recover();
    }
    void Notify(){if(notify){InternetSetOption(IntPtr.Zero,39,IntPtr.Zero,0);InternetSetOption(IntPtr.Zero,37,IntPtr.Zero,0);}}
    public void Enable(int port) {
        if(File.Exists(journal))throw new Exception("err.proxyPending");
        using(var key=Registry.CurrentUser.OpenSubKey(RegistryPath,true)) {
            var values=Json.Obj();
            foreach(var name in new[]{"ProxyEnable","ProxyServer","ProxyOverride","AutoConfigURL"})values[name]=key.GetValue(name,null);
            var marker="http=127.0.0.1:"+port+";https=127.0.0.1:"+port;
            File.WriteAllText(journal,Json.Write(Json.Obj("values",values,"marker",marker)),Encoding.UTF8);
            key.SetValue("ProxyServer",marker);
            key.SetValue("ProxyOverride","<local>;localhost;127.*;10.*;192.168.*");
            key.DeleteValue("AutoConfigURL",false);
            key.SetValue("ProxyEnable",1,RegistryValueKind.DWord);
        }
        Notify();
    }
    public void Recover() {
        if(!File.Exists(journal))return;
        var data=Json.Read(File.ReadAllText(journal,Encoding.UTF8));
        var values=(Dictionary<string,object>)data["values"];
        using(var key=Registry.CurrentUser.OpenSubKey(RegistryPath,true)) {
            if(Convert.ToString(key.GetValue("ProxyServer",""))==Json.Str(data,"marker")) {
                foreach(var pair in values) {
                    if(pair.Value==null)key.DeleteValue(pair.Key,false);
                    else if(pair.Key=="ProxyEnable")key.SetValue(pair.Key,Convert.ToInt32(pair.Value),RegistryValueKind.DWord);
                    else key.SetValue(pair.Key,Convert.ToString(pair.Value),RegistryValueKind.String);
                }
            }
        }
        File.Delete(journal);Notify();
    }
}

/* هسته‌های اتصال در یک Job Object بسته می‌شوند تا با بسته شدن برنامه تمام شوند. */
public sealed class ChildJob : IDisposable {
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode)]static extern IntPtr CreateJobObject(IntPtr attributes,string name);
    [DllImport("kernel32.dll")]static extern bool SetInformationJobObject(IntPtr job,int type,ref ExtendedLimit info,uint length);
    [DllImport("kernel32.dll")]static extern bool AssignProcessToJobObject(IntPtr job,IntPtr process);
    [DllImport("kernel32.dll")]static extern bool CloseHandle(IntPtr handle);
    [StructLayout(LayoutKind.Sequential)]struct BasicLimit {public long PerProcessUserTimeLimit,PerJobUserTimeLimit;public uint LimitFlags;public UIntPtr MinimumWorkingSetSize,MaximumWorkingSetSize;public uint ActiveProcessLimit;public UIntPtr Affinity;public uint PriorityClass,SchedulingClass;}
    [StructLayout(LayoutKind.Sequential)]struct Io {public ulong ReadOperationCount,WriteOperationCount,OtherOperationCount,ReadTransferCount,WriteTransferCount,OtherTransferCount;}
    [StructLayout(LayoutKind.Sequential)]struct ExtendedLimit {public BasicLimit BasicLimitInformation;public Io IoInfo;public UIntPtr ProcessMemoryLimit,JobMemoryLimit,PeakProcessMemoryUsed,PeakJobMemoryUsed;}
    readonly IntPtr handle;
    public ChildJob() {
        handle=CreateJobObject(IntPtr.Zero,null);
        var info=new ExtendedLimit();info.BasicLimitInformation.LimitFlags=0x2000;
        if(handle==IntPtr.Zero||!SetInformationJobObject(handle,9,ref info,(uint)Marshal.SizeOf(info)))throw new Exception("err.guard");
    }
    public void Add(Process p) { if(!AssignProcessToJobObject(handle,p.Handle)){try{p.Kill();}catch{}throw new Exception("err.procManage");} }
    public void Dispose(){CloseHandle(handle);}
}

/* پایگاه دادهٔ آفلاین کشورها. فایل geo.bin کنار برنامه ساخته می‌شود
   (.tools/gen-geo.mjs) و هیچ پرس‌وجویی به بیرون نمی‌رود. */
public sealed class Geo : IDisposable {
    readonly string[] countries = new string[0];
    readonly uint[] ends = new uint[0];
    readonly ushort[] codes = new ushort[0];

    public bool Ready { get { return ends.Length > 0; } }

    public Geo(string file) {
        if(!File.Exists(file))return;
        var bytes=File.ReadAllBytes(file);
        int at=0;
        int count=BitConverter.ToUInt16(bytes,at);at+=2;
        countries=new string[count];
        for(int i=0;i<count;i++){countries[i]=Encoding.ASCII.GetString(bytes,at,2);at+=2;}
        int ranges=(int)BitConverter.ToUInt32(bytes,at);at+=4;
        ends=new uint[ranges];codes=new ushort[ranges];
        for(int i=0;i<ranges;i++){ends[i]=BitConverter.ToUInt32(bytes,at);at+=4;codes[i]=BitConverter.ToUInt16(bytes,at);at+=2;}
    }

    /* اولین بازه‌ای که انتهایش از مقدار بزرگ‌تر است */
    public string Lookup(uint value) {
        if(ends.Length==0)return null;
        int min=0,max=ends.Length-1;
        while(min<max) { var mid=(min+max)>>1;if(ends[mid]<=value)min=mid+1;else max=mid; }
        var cc=countries[codes[min]];
        return cc=="--"?null:cc;
    }

    public string Lookup(string ip) {
        if(!Ready||String.IsNullOrEmpty(ip))return null;
        var parts=ip.Split('.');
        if(parts.Length!=4)return null;   /* پایگاه داده فقط IPv4 را پوشش می‌دهد */
        long n=0;
        foreach(var part in parts) { int octet;if(!int.TryParse(part,out octet)||octet<0||octet>255)return null;n=n*256+octet; }
        return Lookup((uint)n);
    }

    public void Dispose() { }
}
}
