namespace Vyrax {
/* نقطهٔ ورودِ VyraxHelper.exe.

   عمداً جدا از Program.cs است: هلپر باید بدون کشیدنِ WinForms، WebView2 و خودِ
   موتورِ اتصال کامپایل شود. اسکریپتِ ساخت این فایل را از کامپایلِ Vyrax.exe
   کنار می‌گذارد تا آن‌جا فقط Program.Main نقطهٔ ورود باشد. */
public static class HelperEntry {
    public static int Main(string[] args) {
        return HelperServer.Run(args);
    }
}
}
