using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using Vyrax;

/* آزمونِ خودکارِ بخش‌های بدونِ‌ممتازِ Helper: قالبِ پیام و مقایسهٔ توکن.
   اینها همان جاهایی هستند که خرابی‌شان سخت پیدا می‌شود و نیازی به UAC ندارند.
   با .tools/selftest/run.ps1 اجرا می‌شود. */
public static class HelperSelfTest {
    static int failed;

    static void Check(string name,bool ok,string detail="") {
        Console.WriteLine((ok?"  ok   ":"  FAIL ")+name+(ok||detail.Length==0?"":"  — "+detail));
        if(!ok)failed++;
    }

    public static int Main() {
        Console.WriteLine("Helper framing / token self-test");

        /* ۱) رفت و برگشتِ ساده */
        using(var stream=new MemoryStream()) {
            Helper.WriteFrame(stream,Json.Obj("id","7","cmd","tun.start","socksPort",1080));
            stream.Position=0;
            var back=Helper.ReadFrame(stream);
            Check("round-trip id",Json.Str(back,"id")=="7",Json.Str(back,"id"));
            Check("round-trip cmd",Json.Str(back,"cmd")=="tun.start");
            Check("round-trip number",Json.Int(back,"socksPort")==1080,Json.Int(back,"socksPort").ToString());
        }

        /* ۲) متنِ غیرِASCII (فارسی) باید سالم برگردد */
        using(var stream=new MemoryStream()) {
            var text="حالت اتصال — VPN (TUN)";
            Helper.WriteFrame(stream,Json.Obj("t",text));
            stream.Position=0;
            Check("utf-8 round-trip",Json.Str(Helper.ReadFrame(stream),"t")==text);
        }

        /* ۳) چند پیام پشت سر هم روی یک جریان */
        using(var stream=new MemoryStream()) {
            Helper.WriteFrame(stream,Json.Obj("n",1));
            Helper.WriteFrame(stream,Json.Obj("n",2));
            Helper.WriteFrame(stream,Json.Obj("n",3));
            stream.Position=0;
            bool ordered=Json.Int(Helper.ReadFrame(stream),"n")==1
                &&Json.Int(Helper.ReadFrame(stream),"n")==2
                &&Json.Int(Helper.ReadFrame(stream),"n")==3;
            Check("three frames in order",ordered);
        }

        /* ۴) جریانِ خالی یعنی «طرف مقابل رفت»، نه خطا */
        using(var stream=new MemoryStream()) {
            Check("empty stream -> null",Helper.ReadFrame(stream)==null);
        }

        /* ۵) طولِ اعلام‌شدهٔ بزرگ‌تر از سقف باید رد شود، نه اینکه حافظه بخورد */
        using(var stream=new MemoryStream()) {
            stream.Write(new byte[]{0x7F,0xFF,0xFF,0xFF},0,4);
            stream.Position=0;
            bool threw=false;
            try { Helper.ReadFrame(stream); } catch(Exception e) { threw=e.Message=="err.helperFrame"; }
            Check("oversized frame rejected",threw);
        }

        /* ۶) طولِ صفر هم نامعتبر است */
        using(var stream=new MemoryStream()) {
            stream.Write(new byte[]{0,0,0,0},0,4);
            stream.Position=0;
            bool threw=false;
            try { Helper.ReadFrame(stream); } catch(Exception e) { threw=e.Message=="err.helperFrame"; }
            Check("zero-length frame rejected",threw);
        }

        /* ۷) بدنهٔ ناقص (سرصفحه می‌گوید ۱۰ بایت، ۳ بایت هست) → null، نه حلقهٔ بی‌پایان */
        using(var stream=new MemoryStream()) {
            stream.Write(new byte[]{0,0,0,10,(byte)'a',(byte)'b',(byte)'c'},0,7);
            stream.Position=0;
            Check("truncated body -> null",Helper.ReadFrame(stream)==null);
        }

        /* ۸) مقایسهٔ توکن */
        var t=Helper.NewToken();
        Check("token is 64 hex",t.Length==64&&System.Text.RegularExpressions.Regex.IsMatch(t,"^[0-9a-f]{64}$"));
        Check("token is unique",Helper.NewToken()!=t);
        Check("secret equal",Helper.SameSecret(t,t));
        Check("secret differs",!Helper.SameSecret(t,t.Substring(0,63)+"0"));
        Check("secret prefix rejected",!Helper.SameSecret(t.Substring(0,32),t));
        Check("secret null rejected",!Helper.SameSecret(null,t)&&!Helper.SameSecret(t,null));

        /* ۹) نام لوله باید ثابت و مخصوص همین کاربر باشد */
        var p1=Helper.PipeName();
        Check("pipe name stable",p1==Helper.PipeName(),p1);
        Check("pipe name prefixed",p1.StartsWith("Vyrax-helper-"),p1);
        Check("pipe name not raw sid",!p1.Contains("-100-")&&p1.Length==29,p1);

        Console.WriteLine(failed==0?"PASS":"FAILED: "+failed);
        return failed==0?0:1;
    }
}
