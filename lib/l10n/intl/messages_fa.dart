// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a fa locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'fa';

  static String m0(count, skipped) =>
      "${count} مورد برای افزودن؛ ${skipped} مورد تکراری کنار گذاشته شد";

  static String m1(detail) => "پاک کردن داده‌ها ممکن نشد: ${detail}";

  static String m2(code) =>
      "ویندوز اجرای VyraxCore.exe را رد کرد (خطای ${code}). سیاست کنترل برنامه مانند Smart App Control یا AppLocker اجرای برنامهٔ بدون امضا را مسدود کرده است؛ دسترسی Vyrax را در آن سیاست بررسی کنید.";

  static String m3(name) =>
      "برنامه دو بار پیاپی در راه‌اندازی ناموفق بود. برای شکستن چرخه، انتخاب پروفایل ${name} لغو شد و تنظیم خودکار انجام نشد. هر زمان می‌توانید دوباره آن را انتخاب کنید.";

  static String m4(url) => "پروفایلی از ${url} ساخته شود؟";

  static String m5(message) => "هسته این پروکسی را نمی‌پذیرد: ${message}";

  static String m6(proxy, target) =>
      "${proxy} از ${target} متصل می‌شود که دوباره به ${proxy} برمی‌گردد و حلقه می‌سازد";

  static String m7(name) =>
      "نام ${name} برای پروکسی یا گروه دیگری استفاده شده است";

  static String m8(path) =>
      "گروه‌های پروکسی به صورت حلقه به هم ارجاع می‌دهند: ${path}";

  static String m9(name) =>
      "جایگزین باید پروکسی باشد؛ اما ${name} وجود ندارد یا گروه است";

  static String m10(name, message) =>
      "${name} عبارت منظم معتبر نیست: ${message}";

  static String m11(name) => "پروکسی واسط ${name} وجود ندارد";

  static String m12(names) => "این ارائه‌دهندگان پروکسی وجود ندارند: ${names}";

  static String m13(names) => "این پروکسی‌ها یا سیاست‌ها وجود ندارند: ${names}";

  static String m14(name) =>
      "${name} نام یک سیاست داخلی است و اینجا قابل استفاده نیست";

  static String m15(count) =>
      "${count} مورد مشکل دارد و ممکن است اعمال پروفایل ناموفق باشد";

  static String m16(count) =>
      "${Intl.plural(count, one: '۱ روز پیش', other: '${count} روز پیش')}";

  static String m17(count) =>
      "${Intl.plural(count, other: '${count} روز پیش')}";

  static String m18(label) => "از حذف ${label} انتخاب‌شده مطمئن هستید؟";

  static String m19(label) => "از حذف این ${label} مطمئن هستید؟";

  static String m20(label) => "جزئیات ${label}";

  static String m21(name) =>
      "اتصال از ${name} به پروکسی استفاده‌کننده برمی‌گردد؛ بنابراین متوقف شد";

  static String m22(label) => "${label} نباید خالی باشد";

  static String m23(label) => "${label} از قبل وجود دارد";

  static String m24(count) => "${count} مورد ناموفق";

  static String m25(label, message) => "${label}: ${message}";

  static String m26(format, node) =>
      "نود ${node} از ${format} وارد نشد: تنظیمات اتصال نامعتبر یا پشتیبانی‌نشده است. هیچ نودی ذخیره نشد.";

  static String m27(name) => "${name} به‌روز است";

  static String m28(name) => "${name} به‌روز شد";

  static String m29(action) =>
      "قبلاً برای «${action}» استفاده شده است. ذخیره، آن را به این عمل منتقل می‌کند.";

  static String m30(modifiers) => "حداقل یکی از ${modifiers} را به کار ببرید";

  static String m31(count) =>
      "${Intl.plural(count, one: '۱ ساعت پیش', other: '${count} ساعت پیش')}";

  static String m32(count) =>
      "${Intl.plural(count, other: '${count} ساعت پیش')}";

  static String m33(count) =>
      "${Intl.plural(count, one: '۱ ساعت', other: '${count} ساعت')}";

  static String m34(target) => "${target} یک سیاست معتبر نیست";

  static String m35(proxyName) => "${proxyName} پروکسی معتبر نیست";

  static String m36(providerName) =>
      "${providerName} ارائه‌دهندهٔ پروکسی معتبر نیست";

  static String m37(ruleSet) => "${ruleSet} مجموعه‌قانون معتبر نیست";

  static String m38(subRule) => "${subRule} یک SUB_RULE معتبر نیست";

  static String m39(count) =>
      "${Intl.plural(count, one: '۱ مورد', other: '${count} مورد')}";

  static String m40(line, message) => "سطر ${line}: ${message}";

  static String m41(appName) =>
      "۱. تنظیمات سیستم ← حریم خصوصی و امنیت را باز کنید\n۲. خدمات مکان را انتخاب کنید\n۳. ${appName} را در فهرست فعال کنید\n\nسپس برای ادامه به برنامه برگردید.";

  static String m42(label, max) => "${label} باید حداکثر ${max} نویسه باشد";

  static String m43(size) => "${size} آزاد شد";

  static String m44(count) =>
      "${Intl.plural(count, one: '۱ دقیقه پیش', other: '${count} دقیقه پیش')}";

  static String m45(count) =>
      "${Intl.plural(count, other: '${count} دقیقه پیش')}";

  static String m46(count) =>
      "${Intl.plural(count, one: '۱ ماه پیش', other: '${count} ماه پیش')}";

  static String m47(count) =>
      "${Intl.plural(count, other: '${count} ماه پیش')}";

  static String m48(code) =>
      "سرور دسترسی را رد کرد (HTTP ${code}). ممکن است لینک منقضی یا اطلاعات ورود نادرست باشد";

  static String m49(code) => "سرور درخواست را رد کرد (HTTP ${code})";

  static String m50(code) =>
      "در این آدرس چیزی پیدا نشد (HTTP ${code}). URL را بررسی کنید";

  static String m51(detail) => "درخواست شبکه ناموفق بود: ${detail}";

  static String m52(code) =>
      "سرور دچار مشکل شد (HTTP ${code}). بعداً تلاش کنید";

  static String m53(label) => "هنوز ${label} وجود ندارد";

  static String m54(label, min, max) =>
      "${label} باید بین ${min} و ${max} باشد";

  static String m55(label) => "${label} باید عدد باشد";

  static String m56(label) => "${label} باید بین 1024 و 49151 باشد";

  static String m57(label, profiles) =>
      "${label} هنوز در ${profiles} استفاده می‌شود و حذف آن اختلال ایجاد می‌کند. حذف شود؟";

  static String m58(count, label) =>
      "${Intl.plural(count, one: '۱ پروکسی', other: '${label} پروکسی')}";

  static String m59(name, count) => "${name} و دیگران (${count} پروکسی)";

  static String m60(removed) =>
      "این پروکسی‌ها حذف می‌شوند: ${removed}. تغییر نام معادل پروکسی جدید است و ارجاع پروفایل‌های سفارشی به نام‌های حذف‌شده خراب می‌شود. اعمال شود؟";

  static String m61(removed, added) =>
      "حذف: ${removed}. افزودن: ${added}. تغییر نام معادل پروکسی جدید است و ارجاع پروفایل‌های سفارشی به نام‌های حذف‌شده خراب می‌شود. اعمال شود؟";

  static String m62(label) =>
      "${label} هنوز در قوانین، گروه‌ها، پروکسی‌های واسط، DNS یا NTP این پروفایل استفاده می‌شود و حذفش اختلال ایجاد می‌کند. حذف شود؟";

  static String m63(count, label) =>
      "${Intl.plural(count, one: '۱ قانون', other: '${label} قانون')}";

  static String m64(appName) => "${appName} (حالت امن)";

  static String m65(count) =>
      "${Intl.plural(count, one: '۱ ثانیه', other: '${count} ثانیه')}";

  static String m66(count) => "${count} بخش مؤثر";

  static String m67(count) => "${count} مورد انتخاب شده";

  static String m68(time) => "بررسی‌شده در ${time}";

  static String m69(count) =>
      "${Intl.plural(count, one: '۱ تنظیم', other: '${count} تنظیم')}";

  static String m70(link) => "از ${link} پروکسی خوانده نشد";

  static String m71(label) => "${label} باید یک مورد باشد";

  static String m72(label) => "${label} باید یک URL باشد";

  static String m73(count) =>
      "${Intl.plural(count, one: '۱ سال پیش', other: '${count} سال پیش')}";

  static String m74(count) =>
      "${Intl.plural(count, other: '${count} سال پیش')}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("درباره"),
    "accessControl": MessageLookupByLibrary.simpleMessage("کنترل دسترسی"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "فقط برنامه‌های انتخاب‌شده از VPN عبور می‌کنند",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "انتخاب برنامه‌هایی که از پروکسی استفاده می‌کنند",
    ),
    "accessControlDisabledDesc": MessageLookupByLibrary.simpleMessage(
      "کنترل دسترسی برنامه‌ها غیرفعال است",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "برنامه‌های انتخاب‌شده از VPN عبور نمی‌کنند",
    ),
    "accessControlSettings": MessageLookupByLibrary.simpleMessage(
      "تنظیمات کنترل دسترسی",
    ),
    "account": MessageLookupByLibrary.simpleMessage("حساب"),
    "action": MessageLookupByLibrary.simpleMessage("عملیات"),
    "actionDelayTest": MessageLookupByLibrary.simpleMessage("آزمایش تأخیر همه"),
    "actionDirectMode": MessageLookupByLibrary.simpleMessage("حالت مستقیم"),
    "actionGlobalMode": MessageLookupByLibrary.simpleMessage("حالت سراسری"),
    "actionMode": MessageLookupByLibrary.simpleMessage("تغییر حالت"),
    "actionProxy": MessageLookupByLibrary.simpleMessage("پروکسی سیستم"),
    "actionRuleMode": MessageLookupByLibrary.simpleMessage("حالت قانون"),
    "actionStart": MessageLookupByLibrary.simpleMessage("شروع/توقف"),
    "actionTun": MessageLookupByLibrary.simpleMessage("TUN"),
    "actionUpdateProfiles": MessageLookupByLibrary.simpleMessage(
      "بروزرسانی پروفایل‌ها",
    ),
    "actionView": MessageLookupByLibrary.simpleMessage("نمایش/پنهان‌کردن"),
    "add": MessageLookupByLibrary.simpleMessage("افزودن"),
    "addCustomProxy": MessageLookupByLibrary.simpleMessage("افزودن پروکسی"),
    "addFilters": MessageLookupByLibrary.simpleMessage("افزودن فیلترها"),
    "addNodes": MessageLookupByLibrary.simpleMessage("افزودن سرورها"),
    "addOverrideEntry": MessageLookupByLibrary.simpleMessage(
      "افزودن گزینهٔ جایگزین",
    ),
    "addProfile": MessageLookupByLibrary.simpleMessage("افزودن پروفایل"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage("افزودن گروه پروکسی"),
    "addProxyProviders": MessageLookupByLibrary.simpleMessage(
      "افزودن ارائه‌دهندگان پروکسی",
    ),
    "addRule": MessageLookupByLibrary.simpleMessage("افزودن قانون"),
    "addSettingEntry": MessageLookupByLibrary.simpleMessage("افزودن تنظیم"),
    "addSsid": MessageLookupByLibrary.simpleMessage("افزودن نام وای‌فای"),
    "addWidget": MessageLookupByLibrary.simpleMessage("افزودن کارت"),
    "addedRules": MessageLookupByLibrary.simpleMessage("قوانین افزوده"),
    "additionalParameters": MessageLookupByLibrary.simpleMessage(
      "پارامترهای بیشتر",
    ),
    "additionalPrefix": MessageLookupByLibrary.simpleMessage("پیشوند نام"),
    "additionalSuffix": MessageLookupByLibrary.simpleMessage("پسوند نام"),
    "address": MessageLookupByLibrary.simpleMessage("نشانی"),
    "addressHelp": MessageLookupByLibrary.simpleMessage("نشانی سرور WebDAV"),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "یک نشانی معتبر WebDAV وارد کن",
    ),
    "advancedConfig": MessageLookupByLibrary.simpleMessage("تنظیمات پیشرفته"),
    "advancedConfigDesc": MessageLookupByLibrary.simpleMessage(
      "شبکه، DNS، قوانین افزوده و اسکریپت‌ها",
    ),
    "ageEncryptedProfile": MessageLookupByLibrary.simpleMessage(
      "پروفایل رمزگذاری‌شده",
    ),
    "ageSecretKey": MessageLookupByLibrary.simpleMessage("کلید خصوصی age"),
    "ageSecretKeyRequiredTip": MessageLookupByLibrary.simpleMessage(
      "این پروفایل با age رمزگذاری شده و به کلید خصوصی age نیاز دارد",
    ),
    "agree": MessageLookupByLibrary.simpleMessage("می‌پذیرم"),
    "allowBypass": MessageLookupByLibrary.simpleMessage(
      "اجازهٔ عبور برنامه‌ها از خارج VPN",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("دسترسی شبکهٔ محلی"),
    "allowedIps": MessageLookupByLibrary.simpleMessage("IPهای مجاز"),
    "answers": MessageLookupByLibrary.simpleMessage("پاسخ‌ها"),
    "app": MessageLookupByLibrary.simpleMessage("برنامه"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "کنترل دسترسی برنامه‌ها",
    ),
    "appIconDesign": MessageLookupByLibrary.simpleMessage("طراحی نماد برنامه"),
    "appProxiesEmpty": MessageLookupByLibrary.simpleMessage(
      "پروکسی محلی وجود ندارد",
    ),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage("افزودن DNS سیستم"),
    "authentication": MessageLookupByLibrary.simpleMessage("احراز هویت"),
    "authenticationDesc": MessageLookupByLibrary.simpleMessage(
      "برای اتصال به درگاه محلی پروکسی، نام کاربری و رمز عبور درخواست می‌شود.",
    ),
    "authenticationSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "هنگام فعال‌بودن احراز هویت، پروکسی سیستم اعمال نمی‌شود.",
    ),
    "authorize": MessageLookupByLibrary.simpleMessage("دادن مجوز"),
    "authorized": MessageLookupByLibrary.simpleMessage("مجاز"),
    "auto": MessageLookupByLibrary.simpleMessage("خودکار"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage(
      "بررسی خودکار به‌روزرسانی",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "بستن خودکار اتصال‌ها",
    ),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "هنگام تغییر پروکسی، اتصال‌های باز بسته می‌شوند.",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("اجرا با شروع سیستم"),
    "autoRun": MessageLookupByLibrary.simpleMessage("اتصال خودکار"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "با بازشدن برنامه، پروکسی متصل می‌شود.",
    ),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage(
      "تنظیم خودکار DNS سیستم",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("به‌روزرسانی خودکار"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "فاصلهٔ به‌روزرسانی خودکار (دقیقه)",
    ),
    "back": MessageLookupByLibrary.simpleMessage("بازگشت"),
    "backup": MessageLookupByLibrary.simpleMessage("پشتیبان‌گیری"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage(
      "پشتیبان‌گیری و بازیابی",
    ),
    "backupAndRestoreDesc": MessageLookupByLibrary.simpleMessage(
      "ذخیره و بازیابی تنظیمات و پروفایل‌ها",
    ),
    "backupFromNewerVersion": MessageLookupByLibrary.simpleMessage(
      "این پشتیبان از نسخهٔ جدیدتر برنامه است. پیش از بازیابی، برنامه را به‌روز کنید",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage(
      "پشتیبان‌گیری موفق بود",
    ),
    "basicInfo": MessageLookupByLibrary.simpleMessage("اطلاعات پایه"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage("راهبردهای پایه"),
    "batchAdd": MessageLookupByLibrary.simpleMessage("افزودن گروهی"),
    "batchImport": MessageLookupByLibrary.simpleMessage("ورود گروهی"),
    "batchLinkInputTip": MessageLookupByLibrary.simpleMessage(
      "هر لینک در یک سطر",
    ),
    "batchListInputTip": MessageLookupByLibrary.simpleMessage(
      "هر مورد در یک سطر یا جداشده با ویرگول",
    ),
    "batchMapInputTip": MessageLookupByLibrary.simpleMessage(
      "هر مدخل در یک سطر: کلید، فاصله، سپس مقدار",
    ),
    "batchPreviewTip": m0,
    "batchUrlInputTip": MessageLookupByLibrary.simpleMessage(
      "هر URL در یک سطر",
    ),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "این گزینه به اجرای برنامه در پس‌زمینه کمک می‌کند.",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("اتصال"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("فهرست مسدود"),
    "blockConnection": MessageLookupByLibrary.simpleMessage("بستن این اتصال"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("دامنه‌های مستثنا"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "استثنای دامنه فقط هنگام فعال بودن پروکسی سیستم اعمال می‌شود.",
    ),
    "bypassPrivateRoute": MessageLookupByLibrary.simpleMessage(
      "عبور مستقیم آدرس‌های خصوصی",
    ),
    "bypassPrivateRouteDesc": MessageLookupByLibrary.simpleMessage(
      "با این گزینه، آدرس‌های شبکهٔ محلی، حلقهٔ محلی و چندپخشی از TUN عبور نمی‌کنند.",
    ),
    "cache": MessageLookupByLibrary.simpleMessage("حافظهٔ نهان"),
    "cacheAlgorithm": MessageLookupByLibrary.simpleMessage(
      "الگوریتم حافظهٔ نهان",
    ),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "حافظهٔ نهان خراب است. پاک شود؟",
    ),
    "cacheMaxSize": MessageLookupByLibrary.simpleMessage("اندازهٔ حافظهٔ نهان"),
    "cameraPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "برای اسکن QR، مجوز دوربین را در تنظیمات سیستم فعال کنید یا تصویر QR را از گالری انتخاب کنید.",
    ),
    "cameraPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "مجوز دوربین لازم است",
    ),
    "cameraUnavailable": MessageLookupByLibrary.simpleMessage(
      "دوربین در دسترس نیست",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("انصراف"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("لغو انتخاب همه"),
    "cannotSave": MessageLookupByLibrary.simpleMessage("امکان ذخیره نیست"),
    "changeProxyFailedTip": MessageLookupByLibrary.simpleMessage(
      "تغییر پروکسی ناموفق بود؛ انتخاب قبلی بازگردانده شد",
    ),
    "changelogBreaking": MessageLookupByLibrary.simpleMessage(
      "تغییرات ناسازگار",
    ),
    "changelogFeatures": MessageLookupByLibrary.simpleMessage(
      "قابلیت‌های جدید",
    ),
    "changelogFixes": MessageLookupByLibrary.simpleMessage("رفع اشکال"),
    "changelogPerformance": MessageLookupByLibrary.simpleMessage("کارایی"),
    "changelogReverts": MessageLookupByLibrary.simpleMessage("بازگردانی‌ها"),
    "checkCertificate": MessageLookupByLibrary.simpleMessage(
      "اعتبارسنجی گواهی‌های TLS",
    ),
    "checkCertificateDesc": MessageLookupByLibrary.simpleMessage(
      "با خاموش‌کردن اعتبارسنجی TLS، اشتراک‌ها و پشتیبان‌ها در برابر حملهٔ واسطه آسیب‌پذیر می‌شوند.",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("بررسی به‌روزرسانی"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage(
      "برنامه به‌روز است",
    ),
    "cipher": MessageLookupByLibrary.simpleMessage("رمزنگار"),
    "clearData": MessageLookupByLibrary.simpleMessage("پاک کردن داده‌ها"),
    "clearDataAndExitTip": MessageLookupByLibrary.simpleMessage(
      "همهٔ پروفایل‌ها، تنظیمات و داده‌های محلی پاک و برنامه بسته می‌شود. برای شروع تازه آن را دوباره باز کنید.",
    ),
    "clearDataFailed": m1,
    "clearSearch": MessageLookupByLibrary.simpleMessage("پاک کردن جست‌وجو"),
    "clientFingerprint": MessageLookupByLibrary.simpleMessage(
      "اثر انگشت کلاینت",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage(
      "خروجی به کلیپ‌بورد",
    ),
    "clipboardImport": MessageLookupByLibrary.simpleMessage(
      "ورود از کلیپ‌بورد",
    ),
    "clipboardProfilesHint": MessageLookupByLibrary.simpleMessage(
      "چسباندن لینک‌ها · Ctrl+V",
    ),
    "clipboardProfilesInvalid": MessageLookupByLibrary.simpleMessage(
      "کلیپ‌بورد باید شامل لینک معتبر اشتراک یا پروکسی باشد؛ هر لینک در یک خط (حداکثر ۱۰٬۰۰۰ لینک و ۲ مگابایت).",
    ),
    "clipboardWriteFailed": MessageLookupByLibrary.simpleMessage(
      "کپی در کلیپ‌بورد ممکن نشد؛ شاید حجم انتخاب زیاد باشد",
    ),
    "close": MessageLookupByLibrary.simpleMessage("بستن"),
    "closeConnections": MessageLookupByLibrary.simpleMessage("بستن اتصال‌ها"),
    "color": MessageLookupByLibrary.simpleMessage("رنگ"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("طرح‌های رنگ"),
    "columns": MessageLookupByLibrary.simpleMessage("ستون‌ها"),
    "compatible": MessageLookupByLibrary.simpleMessage("حالت سازگاری"),
    "confirm": MessageLookupByLibrary.simpleMessage("تأیید"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage(
      "از پاک کردن همهٔ داده‌ها مطمئن هستید؟",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "از حذف این گروه پروکسی مطمئن هستید؟",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage(
      "از بستن پنجرهٔ فعلی مطمئن هستید؟",
    ),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage(
      "از متوقف کردن اجباری هسته مطمئن هستید؟",
    ),
    "congestionControl": MessageLookupByLibrary.simpleMessage("کنترل ازدحام"),
    "congestionController": MessageLookupByLibrary.simpleMessage(
      "کنترل ازدحام TCP",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("متصل"),
    "connecting": MessageLookupByLibrary.simpleMessage("در حال اتصال…"),
    "connection": MessageLookupByLibrary.simpleMessage("اتصال"),
    "connections": MessageLookupByLibrary.simpleMessage("اتصال‌ها"),
    "connectivity": MessageLookupByLibrary.simpleMessage("وضعیت اتصال: "),
    "content": MessageLookupByLibrary.simpleMessage("محتوا"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage(
      "محتوا نباید خالی باشد",
    ),
    "contentScheme": MessageLookupByLibrary.simpleMessage("محتوا"),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage(
      "کنترل قوانین افزودهٔ سراسری",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("کپی"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage("کپی متغیرهای محیطی"),
    "copyLink": MessageLookupByLibrary.simpleMessage("کپی لینک"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("کپی شد"),
    "core": MessageLookupByLibrary.simpleMessage("هسته"),
    "coreBlockedByPolicyTip": m2,
    "coreBlockedBySmartAppControlTip": MessageLookupByLibrary.simpleMessage(
      "کنترل هوشمند برنامهٔ ویندوز، VyraxCore.exe را به دلیل نداشتن امضا مسدود کرد. تنظیمات آن در Windows Security ← App & browser control است. خاموش کردن این قابلیت برگشت‌پذیر نیست مگر با نصب دوبارهٔ ویندوز.",
    ),
    "coreStatus": MessageLookupByLibrary.simpleMessage("وضعیت هسته"),
    "country": MessageLookupByLibrary.simpleMessage("منطقه"),
    "crashDetected": MessageLookupByLibrary.simpleMessage("خرابی شناسایی شد"),
    "crashDetectedTip": m3,
    "crashTest": MessageLookupByLibrary.simpleMessage("تست خرابی"),
    "crashlytics": MessageLookupByLibrary.simpleMessage("تحلیل خرابی"),
    "crashlyticsTip": MessageLookupByLibrary.simpleMessage(
      "هنگام خرابی، گزارشی بدون اطلاعات حساس ارسال می‌شود.",
    ),
    "create": MessageLookupByLibrary.simpleMessage("ساختن"),
    "createProfileFromUrlTip": m4,
    "creationTime": MessageLookupByLibrary.simpleMessage("زمان ایجاد"),
    "custom": MessageLookupByLibrary.simpleMessage("سفارشی"),
    "customIssueCoreRejected": m5,
    "customIssueDialerLoop": m6,
    "customIssueDuplicateName": m7,
    "customIssueEmptyName": MessageLookupByLibrary.simpleMessage(
      "نام خالی است",
    ),
    "customIssueGroupLoop": m8,
    "customIssueInvalidEmptyFallback": m9,
    "customIssueInvalidFilter": m10,
    "customIssueMissingDialer": m11,
    "customIssueMissingProviders": m12,
    "customIssueMissingProxies": m13,
    "customIssueNoProxySource": MessageLookupByLibrary.simpleMessage(
      "پروکسی یا ارائه‌دهنده‌ای انتخاب نشده و هسته این گروه را رد می‌کند",
    ),
    "customIssueReservedName": m14,
    "customIssuesSummary": m15,
    "customProfile": MessageLookupByLibrary.simpleMessage("پروفایل سفارشی"),
    "customProfileDesc": MessageLookupByLibrary.simpleMessage(
      "ساخت گروه‌های پروکسی و قوانین از پروکسی‌های برنامه و پروفایل‌های دیگر",
    ),
    "customProfileResources": MessageLookupByLibrary.simpleMessage(
      "منابع سفارشی پروفایل",
    ),
    "customProfileResourcesDesc": MessageLookupByLibrary.simpleMessage(
      "پروکسی‌ها، ارائه‌دهندگان قانون، فیلترها و مجموعه‌آیکون‌ها",
    ),
    "cut": MessageLookupByLibrary.simpleMessage("برش"),
    "dark": MessageLookupByLibrary.simpleMessage("تیره"),
    "dashboard": MessageLookupByLibrary.simpleMessage("داشبورد"),
    "dataCollectionContent": MessageLookupByLibrary.simpleMessage(
      "این برنامه برای بهبود پایداری، اطلاعات خرابی را با Firebase Crashlytics گردآوری می‌کند.\nاطلاعات شامل مشخصات دستگاه و جزئیات خرابی است و دادهٔ حساس شخصی ندارد.\nمی‌توانید آن را در تنظیمات خاموش کنید.",
    ),
    "dataCollectionTip": MessageLookupByLibrary.simpleMessage(
      "اطلاعیهٔ گردآوری داده",
    ),
    "databaseWriteFailedTip": MessageLookupByLibrary.simpleMessage(
      "ذخیرهٔ تغییر ناموفق بود؛ تغییر بازگردانده شد",
    ),
    "daysAgo": m16,
    "daysAgoShort": m17,
    "defaultSelected": MessageLookupByLibrary.simpleMessage("انتخاب پیش‌فرض"),
    "defaultText": MessageLookupByLibrary.simpleMessage("پیش‌فرض"),
    "definitionNotMap": MessageLookupByLibrary.simpleMessage(
      "پیکربندی باید نگاشت YAML با نام و نوع باشد",
    ),
    "delay": MessageLookupByLibrary.simpleMessage("تأخیر"),
    "delayFailed": MessageLookupByLibrary.simpleMessage("آزمایش ناموفق"),
    "delayTest": MessageLookupByLibrary.simpleMessage("آزمایش تأخیر"),
    "delete": MessageLookupByLibrary.simpleMessage("حذف"),
    "deleteMultipTip": m18,
    "deleteTip": m19,
    "desc": MessageLookupByLibrary.simpleMessage(
      "یک کلاینت پروکسی چندسکویی بر پایهٔ ClashMeta؛ ساده، متن‌باز و بدون تبلیغ.",
    ),
    "destination": MessageLookupByLibrary.simpleMessage("مقصد"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage(
      "موقعیت آی‌پی مقصد",
    ),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage("ASN آی‌پی مقصد"),
    "details": m20,
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "وابسته به API شخص ثالث است؛ صرفاً جهت اطلاع",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("حالت توسعه‌دهنده"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "حالت توسعه‌دهنده فعال است.",
    ),
    "dialerProxy": MessageLookupByLibrary.simpleMessage("پروکسی شماره‌گیر"),
    "dialerProxyDesc": MessageLookupByLibrary.simpleMessage(
      "خروجی‌ای که برای دسترسی به سرور NTP استفاده می‌شود.",
    ),
    "dialerProxyLoopStopped": m21,
    "direct": MessageLookupByLibrary.simpleMessage("مستقیم"),
    "disableIcmpForwarding": MessageLookupByLibrary.simpleMessage(
      "غیرفعال کردن ارسال ICMP",
    ),
    "disableIcmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "در این حالت TUN خودش به ping پاسخ می‌دهد؛ بنابراین ping تأخیر واقعی را نشان نمی‌دهد.",
    ),
    "disableKeepAlive": MessageLookupByLibrary.simpleMessage(
      "غیرفعال کردن TCP keep-alive",
    ),
    "disableUDP": MessageLookupByLibrary.simpleMessage("غیرفعال کردن UDP"),
    "disabled": MessageLookupByLibrary.simpleMessage("غیرفعال"),
    "discardChanges": MessageLookupByLibrary.simpleMessage(
      "تغییرها کنار گذاشته شوند؟",
    ),
    "disclaimer": MessageLookupByLibrary.simpleMessage("شرایط استفاده"),
    "disclaimerAcceptContent": MessageLookupByLibrary.simpleMessage(
      "نصب، کپی یا استفاده از نرم‌افزار به معنی خواندن و پذیرفتن تمام این بیانیه است. در صورت مخالفت با هر بند، استفاده را متوقف و نرم‌افزار را حذف کنید.",
    ),
    "disclaimerAcceptTitle": MessageLookupByLibrary.simpleMessage("پذیرش"),
    "disclaimerAnalyticsContent": MessageLookupByLibrary.simpleMessage(
      "آمار پایهٔ استفاده به‌صورت خودکار با Firebase گردآوری می‌شود.\n\nداده‌ها: رویدادهایی مانند اولین اجرا، باز شدن برنامه، مدت نشست و به‌روزرسانی؛ شناسهٔ نمونهٔ برنامه؛ مدل دستگاه، نسخهٔ سیستم‌عامل و زبان سیستم؛ و موقعیت تقریبی در سطح کشور یا منطقه برآوردشده از IP.\n\nهدف: فقط شناخت تعداد دستگاه‌های فعال، توزیع نسخه‌ها و سازگاری سیستم‌عامل. این داده‌ها برای تبلیغات استفاده یا فروخته نمی‌شوند و به اشتراک‌ها یا پیکربندی‌های شما پیوند نمی‌خورند.",
    ),
    "disclaimerAnalyticsTitle": MessageLookupByLibrary.simpleMessage(
      "Firebase Analytics (آمار استفاده)",
    ),
    "disclaimerAndroidOnly": MessageLookupByLibrary.simpleMessage(
      "فقط اندروید",
    ),
    "disclaimerChangesContent": MessageLookupByLibrary.simpleMessage(
      "توسعه‌دهندگان ممکن است این بیانیه را با هر انتشار بازبینی کنند و بازبینی از زمان انتشار معتبر است. ادامهٔ استفاده پس از به‌روزرسانی به معنی پذیرش بیانیهٔ بازبینی‌شده است.",
    ),
    "disclaimerChangesTitle": MessageLookupByLibrary.simpleMessage(
      "تغییر این بیانیه",
    ),
    "disclaimerCrashlyticsContent": MessageLookupByLibrary.simpleMessage(
      "هنگام خرابی برنامه، گزارش خرابی خودکار ارسال می‌شود.\n\nداده‌های گردآوری‌شده: ردیابی پشته و پیام خطا، زمان خرابی، نسخه و شمارهٔ ساخت برنامه، برند و مدل دستگاه، نسخهٔ اندروید، جهت صفحه، حافظه و فضای آزاد، وضعیت روت و شناسهٔ تصادفی نصب که با نصب مجدد بازنشانی می‌شود.\n\nهدف: فقط یافتن و رفع خرابی‌ها.\n\nهر زمان از «ابزارها ← عمومی ← تحلیل خرابی» می‌توانید آن را خاموش کنید.",
    ),
    "disclaimerCrashlyticsTitle": MessageLookupByLibrary.simpleMessage(
      "Firebase Crashlytics (تحلیل خرابی)",
    ),
    "disclaimerDataProcessingContent": MessageLookupByLibrary.simpleMessage(
      "این داده‌ها توسط Google از طرف ما پردازش و ذخیره می‌شوند و ممکن است به سرورهای خارج از کشور یا منطقهٔ شما، مانند ایالات متحده، منتقل شوند. سیاست حریم خصوصی Google و اسناد حریم خصوصی و امنیت Firebase بر آن‌ها حاکم است. گزارش خرابی تا ۹۰ روز و آمار طبق سیاست پیش‌فرض Firebase نگهداری می‌شود.",
    ),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "پیش از استفاده از Vyrax («نرم‌افزار»)، این بیانیه را با دقت بخوانید و از درک کامل آن مطمئن شوید. انتخاب «می‌پذیرم» یعنی همهٔ بندهای زیر را خوانده، فهمیده و پذیرفته‌اید. در صورت مخالفت، «خروج» را بزنید و استفاده را متوقف کنید.",
    ),
    "disclaimerFirebasePrivacy": MessageLookupByLibrary.simpleMessage(
      "حریم خصوصی و امنیت Firebase",
    ),
    "disclaimerGooglePrivacy": MessageLookupByLibrary.simpleMessage(
      "سیاست حریم خصوصی Google",
    ),
    "disclaimerLiabilityContent": MessageLookupByLibrary.simpleMessage(
      "تا بیشترین حد مجاز قانونی، توسعه‌دهندگان و مشارکت‌کنندگان در برابر زیان مستقیم، غیرمستقیم، اتفاقی، ویژه، تنبیهی یا تبعی ناشی از استفاده یا ناتوانی در استفاده از نرم‌افزار مسئول نیستند؛ از جمله از دست رفتن داده، آسیب دستگاه، اختلال شبکه، توقف کسب‌وکار، از دست رفتن سود و اختلاف قانونی ناشی از آن، حتی اگر از احتمال زیان آگاه شده باشند.",
    ),
    "disclaimerLiabilityTitle": MessageLookupByLibrary.simpleMessage(
      "محدودیت مسئولیت",
    ),
    "disclaimerLicenseContent": MessageLookupByLibrary.simpleMessage(
      "نرم‌افزار تحت مجوز GPL-3.0 متن‌باز است. با رعایت مجوز می‌توانید آزادانه آن را استفاده، تغییر و توزیع کنید؛ آثار مشتق نیز باید با GPL-3.0 منتشر شوند و اعلان‌های حق نشر اصلی حفظ شوند.\n\nاجزای شخص ثالث، از جمله هستهٔ Clash.Meta، از مجوزهای خود پیروی می‌کنند. نویسندگان اصلی مسئول مشکلات نسخه‌های تغییریافته یا بازتوزیع‌شده نیستند.",
    ),
    "disclaimerLicenseTitle": MessageLookupByLibrary.simpleMessage(
      "مجوز متن‌باز",
    ),
    "disclaimerNoServiceStatement": MessageLookupByLibrary.simpleMessage(
      "خود نرم‌افزار ارائه‌دهندهٔ سرور پروکسی، سرور اتصال، اشتراک یا خدمات دسترسی شبکه نیست و با ارائه‌دهندگان این خدمات رابطهٔ شراکت، نمایندگی یا تضمین ندارد.",
    ),
    "disclaimerPrivacyContent": MessageLookupByLibrary.simpleMessage(
      "نرم‌افزار لینک‌های اشتراک، جزئیات سرورها، محتوای پیکربندی، وب‌سایت‌های بازدیدشده، سوابق اتصال، محتوای ترافیک یا گزارش‌های شما را گردآوری و ارسال نمی‌کند. این داده‌ها روی دستگاه می‌مانند و توسعه‌دهندگان به آن‌ها دسترسی ندارند.\n\nفقط هنگام استفاده از قابلیت نیازمند شبکه، مانند به‌روزرسانی پروفایل از URL ارائه‌شده یا بررسی به‌روزرسانی در GitHub، اتصال شبکه برقرار می‌شود.\n\nVyrax در هیچ‌یک از سیستم‌عامل‌ها سرویس تحلیل یا گزارش خرابی Google Firebase ندارد.",
    ),
    "disclaimerPrivacyTitle": MessageLookupByLibrary.simpleMessage(
      "گردآوری داده و حریم خصوصی",
    ),
    "disclaimerReadToEnd": MessageLookupByLibrary.simpleMessage(
      "تا پایان بخوانید",
    ),
    "disclaimerResponsibilityContent": MessageLookupByLibrary.simpleMessage(
      "مسئول اطمینان از قانونی بودن استفاده از نرم‌افزار در محل زندگی خود هستید و مسئولیت قانونی همهٔ اعمال و پیامدهای آن تنها بر عهدهٔ شماست.\n\nاشتراک‌ها، سرورها و پیکربندی‌های واردشده انتخاب خود شما هستند. قانونی بودن منبع، امنیت محتوا و قابلیت اعتماد خدمات، موضوعی میان شما و ارائه‌دهندگان آن‌هاست.",
    ),
    "disclaimerResponsibilityTitle": MessageLookupByLibrary.simpleMessage(
      "مسئولیت شما",
    ),
    "disclaimerRestateHint": MessageLookupByLibrary.simpleMessage(
      "عبارت بالا را وارد کنید",
    ),
    "disclaimerRestateMismatch": MessageLookupByLibrary.simpleMessage(
      "با عبارت مطابقت ندارد",
    ),
    "disclaimerRestateTip": MessageLookupByLibrary.simpleMessage(
      "برای تأیید درک خود، عبارت زیر را به‌طور کامل در کادر وارد کنید:",
    ),
    "disclaimerRestateTitle": MessageLookupByLibrary.simpleMessage(
      "بازنویسی بیانیه",
    ),
    "disclaimerSoftwareContent": MessageLookupByLibrary.simpleMessage(
      "این نرم‌افزار یک کلاینت متن‌باز پروکسی شبکه بر پایهٔ هستهٔ Clash.Meta (mihomo) است و ابزارهای محلی مدیریت پیکربندی، مسیریابی مبتنی بر قانون و هدایت ترافیک را فراهم می‌کند.",
    ),
    "disclaimerSoftwareTitle": MessageLookupByLibrary.simpleMessage(
      "ماهیت نرم‌افزار",
    ),
    "disclaimerThirdPartyContent": MessageLookupByLibrary.simpleMessage(
      "لینک‌های اشتراک، فایل‌های پیکربندی، مجموعه‌قوانین، اسکریپت‌ها، منابع خارجی و لینک‌های بیرونی توسط اشخاص ثالث فراهم می‌شوند. توسعه‌دهندگان قانونی بودن، دقت، امنیت یا دسترس‌پذیری آن‌ها را بررسی یا تضمین نمی‌کنند.\n\nهرگونه نشت داده، زیان مالی، مسدود شدن حساب یا زیان دیگر ناشی از محتوای شخص ثالث باید میان شما و آن طرف حل شود؛ توسعه‌دهندگان مسئولیتی ندارند.",
    ),
    "disclaimerThirdPartyTitle": MessageLookupByLibrary.simpleMessage(
      "محتوای شخص ثالث",
    ),
    "disclaimerUsageContent": MessageLookupByLibrary.simpleMessage(
      "این نرم‌افزار فقط برای استفاده‌های غیرتجاری مانند یادگیری، تبادل دانش و پژوهش فنی در نظر گرفته شده است. استفادهٔ تجاری، از جمله توزیع پولی، فروش همراه محصولات دیگر، استفاده در خدمات تجاری یا کسب‌وکار به نام نرم‌افزار، اکیداً ممنوع است. فعالیت‌های تجاری ارتباطی با نرم‌افزار و توسعه‌دهندگان آن ندارند.\n\nاستفادهٔ ناقض قوانین کشور یا منطقهٔ شما، از جمله دور زدن محدودیت‌های قانونی دسترسی شبکه، انتشار محتوای غیرقانونی، حملهٔ شبکه و نقض حقوق دیگران، اکیداً ممنوع است.",
    ),
    "disclaimerUsageTitle": MessageLookupByLibrary.simpleMessage(
      "محدودیت‌های استفاده",
    ),
    "disclaimerWarrantyContent": MessageLookupByLibrary.simpleMessage(
      "نرم‌افزار «به همین شکل» و «در صورت دسترسی» و بدون هیچ ضمانت صریح یا ضمنی ارائه می‌شود؛ از جمله ضمانت فروش‌پذیری، تناسب برای هدف خاص، عدم نقض حقوق، دسترسی بی‌وقفه، نبود خطا یا آسیب‌پذیری امنیتی.\n\nتوسعه‌دهندگان تضمین نمی‌کنند که نرم‌افزار نیازهای شما را برآورده کند یا بدون وقفه و خطا اجرا شود.",
    ),
    "disclaimerWarrantyTitle": MessageLookupByLibrary.simpleMessage(
      "بدون ضمانت",
    ),
    "disconnected": MessageLookupByLibrary.simpleMessage("قطع"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "نسخهٔ جدید پیدا شد",
    ),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("هدایت اجباری DNS"),
    "dnsMode": MessageLookupByLibrary.simpleMessage("حالت DNS"),
    "dnsOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "گزینه‌های این بخش جایگزین DNS پروفایل‌های پیوندی و فایلی می‌شوند؛ سایر گزینه‌ها از خود پروفایل می‌آیند. DNS پروفایل سفارشی در محتوای آن تنظیم می‌شود.",
    ),
    "dnsQueries": MessageLookupByLibrary.simpleMessage("درخواست‌های DNS"),
    "docked": MessageLookupByLibrary.simpleMessage("چسبیده"),
    "domain": MessageLookupByLibrary.simpleMessage("دامنه"),
    "download": MessageLookupByLibrary.simpleMessage("دریافت"),
    "downloadBandwidth": MessageLookupByLibrary.simpleMessage(
      "پهنای باند دریافت",
    ),
    "edit": MessageLookupByLibrary.simpleMessage("ویرایش"),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage(
      "ویرایش قوانین سراسری",
    ),
    "editProxy": MessageLookupByLibrary.simpleMessage("ویرایش پروکسی"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage(
      "ویرایش گروه پروکسی",
    ),
    "editRule": MessageLookupByLibrary.simpleMessage("ویرایش قانون"),
    "editSsid": MessageLookupByLibrary.simpleMessage("ویرایش نام وای‌فای"),
    "editorUnavailable": MessageLookupByLibrary.simpleMessage(
      "ویرایشگر در دسترس نیست",
    ),
    "emptyFallback": MessageLookupByLibrary.simpleMessage("جایگزین فهرست خالی"),
    "emptyTip": m22,
    "en": MessageLookupByLibrary.simpleMessage("English"),
    "enabled": MessageLookupByLibrary.simpleMessage("فعال"),
    "entries": MessageLookupByLibrary.simpleMessage(" مورد"),
    "error": MessageLookupByLibrary.simpleMessage("خطا"),
    "errorDetails": MessageLookupByLibrary.simpleMessage("جزئیات خطا"),
    "exclude": MessageLookupByLibrary.simpleMessage(
      "پنهان‌کردن از برنامه‌های اخیر",
    ),
    "excludeFilter": MessageLookupByLibrary.simpleMessage("فیلتر حذف"),
    "excludeInterface": MessageLookupByLibrary.simpleMessage("رابط‌های مستثنا"),
    "excludeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "این گزینه فقط در لینوکس کار می‌کند: ترافیک ورودی این رابط‌ها مانند docker0 از TUN عبور نمی‌کند.",
    ),
    "excludeSsids": MessageLookupByLibrary.simpleMessage(
      "شبکه‌های وای‌فای مستثنا",
    ),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "هنگام اتصال به این شبکه‌ها، وضعیت اجرای برنامه خودکار تغییر می‌کند.",
    ),
    "existsTip": m23,
    "exit": MessageLookupByLibrary.simpleMessage("خروج"),
    "exitFullScreen": MessageLookupByLibrary.simpleMessage("خروج از تمام‌صفحه"),
    "exitNodes": MessageLookupByLibrary.simpleMessage("سرورهای خروجی"),
    "expand": MessageLookupByLibrary.simpleMessage("استاندارد"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("وضعیت مورد انتظار"),
    "expireTime": MessageLookupByLibrary.simpleMessage("زمان انقضا"),
    "exportFile": MessageLookupByLibrary.simpleMessage("خروجی فایل"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("خروجی گزارش‌ها"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage(
      "خروجی با موفقیت تهیه شد",
    ),
    "expressiveScheme": MessageLookupByLibrary.simpleMessage("گویا"),
    "extend": MessageLookupByLibrary.simpleMessage("گسترش"),
    "extendMode": MessageLookupByLibrary.simpleMessage("حالت گسترش"),
    "extendScript": MessageLookupByLibrary.simpleMessage("اسکریپت گسترش"),
    "externalController": MessageLookupByLibrary.simpleMessage(
      "کنترل‌کنندهٔ خارجی",
    ),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "کنترل‌کنندهٔ خارجی امکان کنترل هسته از درگاه 9090 را فراهم می‌کند.",
    ),
    "externalControllerSecret": MessageLookupByLibrary.simpleMessage(
      "رمز کنترل‌کنندهٔ خارجی",
    ),
    "externalLink": MessageLookupByLibrary.simpleMessage("پیوند خارجی"),
    "extraLarge": MessageLookupByLibrary.simpleMessage("خیلی بزرگ"),
    "fa": MessageLookupByLibrary.simpleMessage("فارسی"),
    "fade": MessageLookupByLibrary.simpleMessage("محو شدن"),
    "failedCount": m24,
    "failedItem": m25,
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("فیلتر Fake-IP"),
    "fakeipFilterMode": MessageLookupByLibrary.simpleMessage(
      "حالت فیلتر Fake-IP",
    ),
    "fakeipFilterModeDesc": MessageLookupByLibrary.simpleMessage(
      "فهرست مسدود تطابق‌ها را کنار می‌گذارد؛ فهرست مجاز فقط تطابق‌ها را جعلی می‌کند؛ حالت قانون بر اساس قوانین عمل می‌کند.",
    ),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("محدودهٔ Fake-IP"),
    "fakeipRange6": MessageLookupByLibrary.simpleMessage(
      "محدودهٔ Fake-IP برای IPv6",
    ),
    "fakeipTtl": MessageLookupByLibrary.simpleMessage("زمان اعتبار Fake-IP"),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage(
      "فیلتر مسیر جایگزین",
    ),
    "fidelityScheme": MessageLookupByLibrary.simpleMessage("وفادار"),
    "file": MessageLookupByLibrary.simpleMessage("فایل"),
    "fileDesc": MessageLookupByLibrary.simpleMessage(
      "ورود مستقیم فایل پروفایل",
    ),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "فایل تغییر کرده است. تغییرات ذخیره شوند؟",
    ),
    "filter": MessageLookupByLibrary.simpleMessage("فیلتر"),
    "filters": MessageLookupByLibrary.simpleMessage("فیلترها"),
    "finalConfig": MessageLookupByLibrary.simpleMessage("پیکربندی نهایی"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("شناسایی فرایند"),
    "floating": MessageLookupByLibrary.simpleMessage("شناور"),
    "followProfile": MessageLookupByLibrary.simpleMessage("پیروی از پروفایل"),
    "followSystem": MessageLookupByLibrary.simpleMessage("پیروی از سیستم"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("قلم"),
    "fontSize": MessageLookupByLibrary.simpleMessage("اندازه"),
    "forceDnsMapping": MessageLookupByLibrary.simpleMessage("اجبار نگاشت DNS"),
    "forceDnsMappingDesc": MessageLookupByLibrary.simpleMessage(
      "اتصال‌هایی که دامنهٔ آن‌ها از نگاشت DNS آمده هم بررسی می‌شوند.",
    ),
    "forceDomain": MessageLookupByLibrary.simpleMessage("دامنه‌های اجباری"),
    "forceDomainDesc": MessageLookupByLibrary.simpleMessage(
      "این دامنه‌ها همیشه بررسی می‌شوند؛ سایر اتصال‌هایی که دامنه دارند دست‌نخورده می‌مانند.",
    ),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage(
      "از راه‌اندازی اجباری دوبارهٔ هسته مطمئن هستید؟",
    ),
    "foreignProfileHint": MessageLookupByLibrary.simpleMessage(
      "Clash، Xray یا sing-box",
    ),
    "foreignProfileUnsupported": m26,
    "fruitSaladScheme": MessageLookupByLibrary.simpleMessage("سالاد میوه"),
    "general": MessageLookupByLibrary.simpleMessage("عمومی"),
    "geoResources": MessageLookupByLibrary.simpleMessage("منابع جغرافیایی"),
    "geoSkipped": m27,
    "geoUpdated": m28,
    "geodataLoader": MessageLookupByLibrary.simpleMessage(
      "حالت کم‌حافظهٔ داده‌های جغرافیایی",
    ),
    "global": MessageLookupByLibrary.simpleMessage("سراسری"),
    "go": MessageLookupByLibrary.simpleMessage("رفتن"),
    "goDownload": MessageLookupByLibrary.simpleMessage("دانلود"),
    "goToConfigureAddedRules": MessageLookupByLibrary.simpleMessage(
      "رفتن به تنظیم قوانین افزوده",
    ),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage(
      "رفتن به تنظیم اسکریپت",
    ),
    "hasCacheChange": MessageLookupByLibrary.simpleMessage(
      "تغییرات در حافظهٔ نهان بمانند؟",
    ),
    "hashByInUser": MessageLookupByLibrary.simpleMessage(
      "هش بر اساس کاربر ورودی",
    ),
    "healthCheck": MessageLookupByLibrary.simpleMessage("بررسی سلامت"),
    "helperCorruptTip": MessageLookupByLibrary.simpleMessage(
      "سرویس کمکی در دسترس نیست و TUN فعال نمی‌شود. برای بازیابی، Vyrax را دوباره نصب کنید.",
    ),
    "hideFromList": MessageLookupByLibrary.simpleMessage("پنهان کردن از فهرست"),
    "hideIp": MessageLookupByLibrary.simpleMessage("پنهان کردن IP"),
    "hidePassword": MessageLookupByLibrary.simpleMessage("پنهان کردن گذرواژه"),
    "hideTimeoutProxies": MessageLookupByLibrary.simpleMessage(
      "پنهان کردن پروکسی‌های بی‌پاسخ",
    ),
    "hideTimeoutProxiesDesc": MessageLookupByLibrary.simpleMessage(
      "پروکسی‌هایی را پنهان می‌کند که آخرین تست تأخیرشان بی‌پاسخ بوده است",
    ),
    "hideUpdateNotice": MessageLookupByLibrary.simpleMessage(
      "پنهان‌کردن این به‌روزرسانی",
    ),
    "hopInterval": MessageLookupByLibrary.simpleMessage("بازهٔ پرش"),
    "host": MessageLookupByLibrary.simpleMessage("میزبان"),
    "hostname": MessageLookupByLibrary.simpleMessage("نام میزبان"),
    "hotkeyConflictWith": m29,
    "hotkeyDesc": MessageLookupByLibrary.simpleMessage(
      "میان‌برهای سراسری حتی با پنجرهٔ پنهان کار می‌کنند. برای ثبت ترکیب کلید، روی یک عمل بزنید.",
    ),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage(
      "میان‌برهای صفحه‌کلید",
    ),
    "hotkeyNeedsModifier": m30,
    "hotkeyNotSet": MessageLookupByLibrary.simpleMessage("تنظیم نشده"),
    "hotkeyUnavailable": MessageLookupByLibrary.simpleMessage(
      "ثبت نشد؛ شاید برنامهٔ دیگری از آن استفاده می‌کند",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("ساعت"),
    "hoursAgo": m31,
    "hoursAgoShort": m32,
    "hoursCount": m33,
    "icon": MessageLookupByLibrary.simpleMessage("آیکون"),
    "iconRecords": MessageLookupByLibrary.simpleMessage("سوابق آیکون"),
    "iconSets": MessageLookupByLibrary.simpleMessage("مجموعه‌آیکون‌ها"),
    "iconSetsEmptyTip": MessageLookupByLibrary.simpleMessage(
      "مجموعه‌آیکونی وجود ندارد. از منابع پروفایل سفارشی ← مجموعه‌آیکون‌ها اضافه کنید",
    ),
    "iconStyle": MessageLookupByLibrary.simpleMessage("سبک آیکون"),
    "iconStyleFilled": MessageLookupByLibrary.simpleMessage("پر"),
    "iconStyleHidden": MessageLookupByLibrary.simpleMessage("مخفی"),
    "iconStylePlain": MessageLookupByLibrary.simpleMessage("ساده"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("URL آیکون"),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage(
      "نادیده گرفتن بهینه‌سازی باتری",
    ),
    "import": MessageLookupByLibrary.simpleMessage("واردکردن"),
    "importConfigInvalid": MessageLookupByLibrary.simpleMessage(
      "این فایل پیکربندی قابل ورود نیست",
    ),
    "importConfigReplaceTip": MessageLookupByLibrary.simpleMessage(
      "ورود فایل، گروه‌های پروکسی، قوانین و تنظیمات فعلی این پروفایل را جایگزین می‌کند",
    ),
    "importFile": MessageLookupByLibrary.simpleMessage("ورود فایل"),
    "importFromLink": MessageLookupByLibrary.simpleMessage("ورود از پیوند"),
    "importUrl": MessageLookupByLibrary.simpleMessage("ورود از URL"),
    "inbound": MessageLookupByLibrary.simpleMessage("ورودی"),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("بدون انقضا"),
    "init": MessageLookupByLibrary.simpleMessage("آغازین"),
    "initFailed": MessageLookupByLibrary.simpleMessage("راه‌اندازی ناموفق"),
    "initFailedTip": MessageLookupByLibrary.simpleMessage(
      "Vyrax هنگام راه‌اندازی با خطا روبه‌رو شد. جزئیات را برای گزارش مشکل کپی کنید. اگر ادامه داشت، پاک کردن داده‌ها معمولاً راه‌اندازی را ممکن می‌کند.",
    ),
    "initiator": MessageLookupByLibrary.simpleMessage("آغازگر"),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage(
      "نام گروه پروکسی را وارد کنید",
    ),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage(
      "محتوای قانون را وارد کنید",
    ),
    "installedAppsPermissionDeniedMessage":
        MessageLookupByLibrary.simpleMessage(
          "مجوز فهرست برنامه‌ها رد شد. آن را دستی در تنظیمات سیستم فعال کنید.",
        ),
    "installedAppsPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "سیستم تا دریافت مجوز، فهرست برنامه‌ها را پنهان می‌کند. برای تنظیم پروکسی هر برنامه مجوز بدهید.",
    ),
    "installedAppsPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "مجوز فهرست برنامه‌ها لازم است",
    ),
    "installedFonts": MessageLookupByLibrary.simpleMessage("قلم‌های نصب‌شده"),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage(
      "انتخاب هوشمند",
    ),
    "interfaceName": MessageLookupByLibrary.simpleMessage("نام رابط"),
    "interfaceNameDesc": MessageLookupByLibrary.simpleMessage(
      "رابط شبکه‌ای که اتصال‌های خروجی از آن استفاده می‌کنند.",
    ),
    "interfaceNameMode": MessageLookupByLibrary.simpleMessage("رابط خروجی"),
    "interfaceNameModeClear": MessageLookupByLibrary.simpleMessage("پاک کردن"),
    "interfaceNameModeCustom": MessageLookupByLibrary.simpleMessage("سفارشی"),
    "interfaceNameModeFollow": MessageLookupByLibrary.simpleMessage(
      "پیروی از پیکربندی",
    ),
    "internet": MessageLookupByLibrary.simpleMessage("اینترنت"),
    "interval": MessageLookupByLibrary.simpleMessage("بازه"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("آی‌پی داخلی"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage(
      "فایل پشتیبان نامعتبر است",
    ),
    "invalidCidrContent": MessageLookupByLibrary.simpleMessage(
      "بازهٔ IP را به شکل CIDR مانند 192.168.0.0/16 وارد کنید",
    ),
    "invalidDscpContent": MessageLookupByLibrary.simpleMessage(
      "نشان DSCP نباید بیشتر از 63 باشد",
    ),
    "invalidHostContent": MessageLookupByLibrary.simpleMessage(
      "دامنه یا IP وارد کنید",
    ),
    "invalidIconSet": MessageLookupByLibrary.simpleMessage(
      "مجموعه‌آیکون معتبر نیست",
    ),
    "invalidLinkTip": MessageLookupByLibrary.simpleMessage(
      "لینک اشتراک یا اشتراک‌گذاری پروکسی نیست",
    ),
    "invalidListenContent": MessageLookupByLibrary.simpleMessage(
      "آدرس و پورت مانند 0.0.0.0:1053 وارد کنید",
    ),
    "invalidNetworkContent": MessageLookupByLibrary.simpleMessage(
      "فقط tcp و udp پشتیبانی می‌شود",
    ),
    "invalidPolicy": m34,
    "invalidPortRangeContent": MessageLookupByLibrary.simpleMessage(
      "پورت یا بازه‌ای مانند 443 یا 8000-9000 وارد کنید",
    ),
    "invalidProfileQrcode": MessageLookupByLibrary.simpleMessage(
      "این QR لینک پروفایل ندارد",
    ),
    "invalidProxy": m35,
    "invalidProxyProvider": m36,
    "invalidRangeContent": MessageLookupByLibrary.simpleMessage(
      "عدد یا بازه مانند 80 یا 8000-9000 وارد کنید؛ جداساز / است",
    ),
    "invalidRuleSet": m37,
    "invalidSubRule": m38,
    "ipAddress": MessageLookupByLibrary.simpleMessage("آدرس IP"),
    "ipAsn": MessageLookupByLibrary.simpleMessage("ASN"),
    "ipFlagAbuser": MessageLookupByLibrary.simpleMessage("سابقهٔ سوءاستفاده"),
    "ipFlagProxy": MessageLookupByLibrary.simpleMessage("پروکسی"),
    "ipFlagTor": MessageLookupByLibrary.simpleMessage("Tor"),
    "ipFlagVpn": MessageLookupByLibrary.simpleMessage("VPN"),
    "ipFlags": MessageLookupByLibrary.simpleMessage("نشان‌ها"),
    "ipOrganization": MessageLookupByLibrary.simpleMessage("سازمان"),
    "ipQualityFailed": MessageLookupByLibrary.simpleMessage("نوع IP مشخص نشد"),
    "ipQualityGood": MessageLookupByLibrary.simpleMessage("خوب"),
    "ipQualityLevel": MessageLookupByLibrary.simpleMessage("سطح"),
    "ipQualityNormal": MessageLookupByLibrary.simpleMessage("عادی"),
    "ipQualityRetry": MessageLookupByLibrary.simpleMessage("بررسی دوباره"),
    "ipQualityRisky": MessageLookupByLibrary.simpleMessage("پرخطر"),
    "ipQualitySource": MessageLookupByLibrary.simpleMessage("پاسخ‌دهنده"),
    "ipQualitySources": MessageLookupByLibrary.simpleMessage("منابع"),
    "ipSourceIpMismatch": MessageLookupByLibrary.simpleMessage(
      "IP خروجی متفاوت",
    ),
    "ipSourceNoType": MessageLookupByLibrary.simpleMessage("بدون نوع"),
    "ipSourceRateLimited": MessageLookupByLibrary.simpleMessage(
      "محدودیت درخواست",
    ),
    "ipType": MessageLookupByLibrary.simpleMessage("نوع"),
    "ipTypeBusiness": MessageLookupByLibrary.simpleMessage("تجاری"),
    "ipTypeHosting": MessageLookupByLibrary.simpleMessage("مرکز داده"),
    "ipTypeMobile": MessageLookupByLibrary.simpleMessage("شبکهٔ همراه"),
    "ipTypeResidential": MessageLookupByLibrary.simpleMessage("خانگی"),
    "ipVersion": MessageLookupByLibrary.simpleMessage("نسخهٔ IP"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "ترافیک IPv6 فقط در صورت فعال‌بودن آن دریافت می‌شود.",
    ),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage(
      "با فعال بودن IPv6، اتصال ورودی IPv6 در VPN مجاز است.",
    ),
    "ipv6Timeout": MessageLookupByLibrary.simpleMessage(
      "مهلت IPv6 (میلی‌ثانیه)",
    ),
    "itemsCount": m39,
    "ja": MessageLookupByLibrary.simpleMessage("日本語"),
    "justNow": MessageLookupByLibrary.simpleMessage("همین حالا"),
    "keepAliveIdle": MessageLookupByLibrary.simpleMessage(
      "زمان بیکاری TCP keep-alive",
    ),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "فاصلهٔ زنده‌نگه‌داشتن اتصال TCP",
    ),
    "key": MessageLookupByLibrary.simpleMessage("کلید"),
    "label": MessageLookupByLibrary.simpleMessage("برچسب"),
    "language": MessageLookupByLibrary.simpleMessage("زبان"),
    "large": MessageLookupByLibrary.simpleMessage("بزرگ"),
    "lastUpdated": MessageLookupByLibrary.simpleMessage("آخرین به‌روزرسانی"),
    "launchInterrupted": MessageLookupByLibrary.simpleMessage(
      "راه‌اندازی کامل نشد",
    ),
    "launchInterruptedTip": MessageLookupByLibrary.simpleMessage(
      "برنامه در راه‌اندازی قبلی ناگهان بسته شد. تنظیم خودکار این بار انجام نشد؛ می‌توانید دستی آن را شروع کنید.",
    ),
    "layout": MessageLookupByLibrary.simpleMessage("چیدمان"),
    "light": MessageLookupByLibrary.simpleMessage("روشن"),
    "lineIssueTip": m40,
    "lineWrap": MessageLookupByLibrary.simpleMessage("شکستن سطرهای بلند"),
    "link": MessageLookupByLibrary.simpleMessage("پیوند"),
    "linkDesc": MessageLookupByLibrary.simpleMessage("لینک ساب یا کانفیگ"),
    "list": MessageLookupByLibrary.simpleMessage("لیست"),
    "listen": MessageLookupByLibrary.simpleMessage("گوش دادن"),
    "listenRoutingMark": MessageLookupByLibrary.simpleMessage(
      "نشان مسیریابی ورودی",
    ),
    "listenRoutingMarkDesc": MessageLookupByLibrary.simpleMessage(
      "این نشان فقط در لینوکس کار می‌کند.",
    ),
    "liveConnections": MessageLookupByLibrary.simpleMessage("اتصال‌های زنده"),
    "loading": MessageLookupByLibrary.simpleMessage("در حال بارگذاری"),
    "local": MessageLookupByLibrary.simpleMessage("محلی"),
    "localImage": MessageLookupByLibrary.simpleMessage("تصویر محلی"),
    "localNetworkDeniedTip": MessageLookupByLibrary.simpleMessage(
      "مجوز شبکهٔ محلی داده نشده است؛ با پشتهٔ gvisor، شبکهٔ محلی در دسترس نیست.",
    ),
    "localProxies": MessageLookupByLibrary.simpleMessage("پروکسی‌های محلی"),
    "locationPermission": MessageLookupByLibrary.simpleMessage("مجوز مکان"),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "مجوز مکان رد شد و نام وای‌فای فعلی قابل خواندن نیست. آن را دستی در تنظیمات سیستم فعال کنید.",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "برای خواندن نام وای‌فای، مجوز مکان لازم است. در اندروید «همیشه مجاز» را انتخاب کنید تا خواندن در پس‌زمینه هم ممکن باشد.",
    ),
    "locationPermissionGuide": m41,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "مجوز مکان لازم است",
    ),
    "log": MessageLookupByLibrary.simpleMessage("گزارش"),
    "logLevel": MessageLookupByLibrary.simpleMessage("سطح گزارش"),
    "logcat": MessageLookupByLibrary.simpleMessage("Logcat"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "با خاموش‌کردن Logcat، بخش گزارش‌ها پنهان می‌شود.",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("گزارش‌ها"),
    "logsAndDiagnostics": MessageLookupByLibrary.simpleMessage(
      "گزارش‌ها و عیب‌یابی",
    ),
    "logsTest": MessageLookupByLibrary.simpleMessage("تست گزارش‌ها"),
    "loopback": MessageLookupByLibrary.simpleMessage("معافیت حلقهٔ محلی UWP"),
    "loose": MessageLookupByLibrary.simpleMessage("باز"),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage("تطبیق IP مبدأ"),
    "matchTarget": MessageLookupByLibrary.simpleMessage("MATCH-TARGET"),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage("حداکثر شکست"),
    "maxLengthTip": m42,
    "maximize": MessageLookupByLibrary.simpleMessage("بزرگ کردن"),
    "memoryAppResident": MessageLookupByLibrary.simpleMessage("حافظهٔ مقیم"),
    "memoryAppShared": MessageLookupByLibrary.simpleMessage(
      "برنامه و حافظهٔ مشترک",
    ),
    "memoryCoreHeapIdle": MessageLookupByLibrary.simpleMessage("هیپ آزاد"),
    "memoryCoreHeapInuse": MessageLookupByLibrary.simpleMessage(
      "هیپ در حال استفاده",
    ),
    "memoryCoreNotRunning": MessageLookupByLibrary.simpleMessage(
      "هسته اجرا نشده است",
    ),
    "memoryCoreRuntime": MessageLookupByLibrary.simpleMessage("سربار اجرا"),
    "memoryCoreStack": MessageLookupByLibrary.simpleMessage(
      "پشته‌های Goroutine",
    ),
    "memoryEstimateDesc": MessageLookupByLibrary.simpleMessage(
      "برآوردی از حافظهٔ مقیم فرایند است؛ ممکن است با گزارش سیستم تفاوت داشته باشد.",
    ),
    "memoryEstimateSharedDesc": MessageLookupByLibrary.simpleMessage(
      "هسته در فرایند برنامه اجرا می‌شود. سهم آن از آمار اجرا برآورد می‌شود و بقیه، حافظهٔ برنامه و مشترک است.",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("اطلاعات حافظه"),
    "memoryReleased": MessageLookupByLibrary.simpleMessage("حافظه آزاد شد"),
    "memoryReleasedSize": m43,
    "messageTest": MessageLookupByLibrary.simpleMessage("تست پیام"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage(
      "این یک پیام آزمایشی است.",
    ),
    "min": MessageLookupByLibrary.simpleMessage("کوچک"),
    "minimize": MessageLookupByLibrary.simpleMessage("کوچک کردن"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage(
      "کوچک‌کردن هنگام خروج",
    ),
    "minutesAgo": m44,
    "minutesAgoShort": m45,
    "mixedPort": MessageLookupByLibrary.simpleMessage("پورت ترکیبی"),
    "mode": MessageLookupByLibrary.simpleMessage("حالت"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("تک‌رنگ"),
    "monthsAgo": m46,
    "monthsAgoShort": m47,
    "more": MessageLookupByLibrary.simpleMessage("بیشتر"),
    "quickAccess": MessageLookupByLibrary.simpleMessage("دسترسی سریع"),
    "mozillaAccounts": MessageLookupByLibrary.simpleMessage(
      "حساب‌های ذخیره‌شده",
    ),
    "mozillaAccountsError": MessageLookupByLibrary.simpleMessage(
      "حداکثر ۱۰ حساب می‌توان ذخیره کرد. برای افزودن حساب جدید، یکی را حذف کن.",
    ),
    "mozillaActivate": MessageLookupByLibrary.simpleMessage(
      "فعال‌سازی دسترسی رایگان",
    ),
    "mozillaActivationError": MessageLookupByLibrary.simpleMessage(
      "سرویس هنوز دسترسی این حساب را فعال نکرده است. وضعیت و شرایط حساب را در سایت رسمی Mozilla بررسی کن.",
    ),
    "mozillaAddAccount": MessageLookupByLibrary.simpleMessage(
      "افزودن حساب دیگر",
    ),
    "mozillaAllowance": MessageLookupByLibrary.simpleMessage(
      "این سرویس برای حساب‌های واجد شرایط تا ۵۰ گیگابایت در ماه ارائه می‌کند. سهمیه، کشورها و دسترسی را Mozilla تعیین می‌کند؛ عدد این صفحه پاسخ واقعی حساب است. برای دریافت سهمیهٔ حساب دیگر، از بخش حساب‌ها جابه‌جا شو.",
    ),
    "mozillaAllowanceTitle": MessageLookupByLibrary.simpleMessage(
      "سهمیهٔ ماهانه",
    ),
    "mozillaAuthError": MessageLookupByLibrary.simpleMessage(
      "مجوز حساب معتبر نیست؛ دوباره وارد حساب Firefox شو.",
    ),
    "mozillaChallengeError": MessageLookupByLibrary.simpleMessage(
      "محافظت وب Mozilla درخواست مستقیم برنامه را متوقف کرد (۴۰۶). این پاسخ، اشتباه بودن رمز یا مجاز نبودن حساب را مشخص نمی‌کند.",
    ),
    "mozillaCodeError": MessageLookupByLibrary.simpleMessage(
      "کد تأیید درست نیست یا منقضی شده است. دوباره وارد حساب شو.",
    ),
    "mozillaCreateAccount": MessageLookupByLibrary.simpleMessage(
      "ساخت حساب Firefox",
    ),
    "mozillaCredentialsError": MessageLookupByLibrary.simpleMessage(
      "ایمیل یا رمز حساب درست نیست.",
    ),
    "mozillaEligibilityError": MessageLookupByLibrary.simpleMessage(
      "سرویس دسترسی را تأیید نکرد؛ ممکن است حساب یا منطقه واجد شرایط نباشد یا نیاز به تأیید در سایت رسمی باشد.",
    ),
    "mozillaEmail": MessageLookupByLibrary.simpleMessage("ایمیل حساب Firefox"),
    "mozillaGuide": MessageLookupByLibrary.simpleMessage(
      "راهنمای سرورهای رایگان",
    ),
    "mozillaGuideSteps": MessageLookupByLibrary.simpleMessage(
      "1. حساب Firefox بساز\nاز دکمهٔ «ساخت حساب Firefox» وارد سایت رسمی شو. اگر حساب داری، از همان حساب استفاده کن.\n\n2. وارد حساب شو و ایمیل را تأیید کن\nبه این بخش برگرد و ایمیل و رمز حساب را وارد کن. اگر کد تأیید برایت ایمیل شد، آن را در مرحلهٔ بعد بنویس. رمز در Vyrax ذخیره نمی‌شود.\n\n3. سهمیه را فعال کن\nاگر حساب هنوز فعال نیست، «فعال‌سازی دسترسی رایگان» را بزن. حجم باقی‌مانده و زمان تمدید از پاسخ همان حساب نمایش داده می‌شوند.\n\n4. سرور را انتخاب کن و وصل شو\n«استفاده از سرورها» را بزن. یک اشتراک جدا به لیست اضافه می‌شود؛ می‌توانی سرور دلخواه، سریع‌ترین یا بالانس را انتخاب کنی و از صفحهٔ اصلی وصل شوی.",
    ),
    "mozillaImported": MessageLookupByLibrary.simpleMessage(
      "فهرست سرورها اضافه شد. یک سرور انتخاب کن و از داشبورد وصل شو.",
    ),
    "mozillaIntro": MessageLookupByLibrary.simpleMessage(
      "با حساب Firefox خودت از سرورهای سرویس Firefox VPN استفاده کن؛ نیازی به وارد کردن کانفیگ نیست.",
    ),
    "mozillaNetworkError": MessageLookupByLibrary.simpleMessage(
      "ارتباط با Mozilla برقرار نشد. اینترنت یا مسیر اتصال را بررسی کن و دوباره تلاش کن.",
    ),
    "mozillaOfficialHelp": MessageLookupByLibrary.simpleMessage(
      "راهنمای رسمی Mozilla",
    ),
    "mozillaOpenAccount": MessageLookupByLibrary.simpleMessage(
      "باز کردن سایت حساب Mozilla",
    ),
    "mozillaPassword": MessageLookupByLibrary.simpleMessage("رمز حساب"),
    "mozillaPrivacy": MessageLookupByLibrary.simpleMessage(
      "رمز ذخیره نمی‌شود. مجوزهای ورود در فضای رمزگذاری‌شدهٔ همین دستگاه نگه داشته می‌شوند.",
    ),
    "mozillaProfile": MessageLookupByLibrary.simpleMessage(
      "سرورهای رایگان Mozilla",
    ),
    "mozillaQuotaError": MessageLookupByLibrary.simpleMessage(
      "سهمیه تمام شده یا درخواست‌ها بیش از حد بوده‌اند. وضعیت حساب و زمان تمدید را بررسی کن.",
    ),
    "mozillaQuotaSnapshot": MessageLookupByLibrary.simpleMessage(
      "مقدار اعلام‌شده در آخرین بررسی حساب؛ برای مقدار تازه دکمهٔ به‌روزرسانی را بزن.",
    ),
    "mozillaQuotaUnknown": MessageLookupByLibrary.simpleMessage(
      "سرویس هنوز حجم باقی‌مانده را اعلام نکرده است. وضعیت حساب را به‌روزرسانی کن.",
    ),
    "mozillaRemaining": MessageLookupByLibrary.simpleMessage("باقی‌مانده"),
    "mozillaRemoveAccount": MessageLookupByLibrary.simpleMessage(
      "حذف حساب از این دستگاه",
    ),
    "mozillaRemoveHint": MessageLookupByLibrary.simpleMessage(
      "اطلاعات ذخیره‌شدهٔ این حساب از دستگاه حذف می‌شود؛ حساب Mozilla حذف نخواهد شد.",
    ),
    "mozillaReset": MessageLookupByLibrary.simpleMessage("بازنشانی سهمیه"),
    "mozillaServersError": MessageLookupByLibrary.simpleMessage(
      "فعلاً سرور قابل استفاده‌ای در فهرست رسمی پیدا نشد.",
    ),
    "mozillaServiceError": MessageLookupByLibrary.simpleMessage(
      "سرویس پاسخ قابل استفاده نداد؛ کمی بعد دوباره تلاش کن.",
    ),
    "mozillaSignIn": MessageLookupByLibrary.simpleMessage(
      "ورود به حساب Firefox",
    ),
    "mozillaStorageError": MessageLookupByLibrary.simpleMessage(
      "اطلاعات حساب رایگان قابل خواندن نیست؛ برای بازیابی، دوباره وارد حساب شو.",
    ),
    "mozillaSwitchHint": MessageLookupByLibrary.simpleMessage(
      "سوییچ یا حذف حساب فعال، اتصال سرور رایگان را قطع می‌کند. حذف حساب فقط اطلاعات آن را از این دستگاه پاک می‌کند.",
    ),
    "mozillaTcpOnly": MessageLookupByLibrary.simpleMessage(
      "این روش ترافیک TCP را عبور می‌دهد؛ برای بعضی بازی‌ها و برنامه‌های نیازمند UDP مناسب نیست. اگر سرویس در منطقه یا شبکهٔ تو در دسترس نباشد، یک اشتراک شخصی انتخاب کن.",
    ),
    "powTitle": MessageLookupByLibrary.simpleMessage("وایرکس رایگان"),
    "powIntro": MessageLookupByLibrary.simpleMessage("تونل Psiphon + Cloudflare WARP (UAC PoW) روی همین دستگاه، برای شبکه‌هایی که تونل مستقیم جواب نمی‌دهد."),
    "powConnect": MessageLookupByLibrary.simpleMessage("متصل شو"),
    "powDisconnect": MessageLookupByLibrary.simpleMessage("قطع کن"),
    "powSettings": MessageLookupByLibrary.simpleMessage("تنظیمات"),
    "powRegion": MessageLookupByLibrary.simpleMessage("کشور خروج"),
    "powRegionAuto": MessageLookupByLibrary.simpleMessage("خودکار (همسایه)"),
    "powAuto": MessageLookupByLibrary.simpleMessage("خودکار"),
    "powOuterTransport": MessageLookupByLibrary.simpleMessage("حمل‌ونقل WARP"),
    "powRecipe": MessageLookupByLibrary.simpleMessage("دستور لینک"),
    "powFirewall": MessageLookupByLibrary.simpleMessage("پروفایل فایروال"),
    "powFirewallAuto": MessageLookupByLibrary.simpleMessage("خودکار (همراه اول)"),
    "powFirewallIrancell": MessageLookupByLibrary.simpleMessage("ایرانسل"),
    "powFirewallMci": MessageLookupByLibrary.simpleMessage("همراه اول"),
    "powScanMode": MessageLookupByLibrary.simpleMessage("جست‌وجوی IP"),
    "powScanTurbo": MessageLookupByLibrary.simpleMessage("توربو"),
    "powScanBalanced": MessageLookupByLibrary.simpleMessage("متعادل"),
    "powScanThorough": MessageLookupByLibrary.simpleMessage("کامل"),
    "powKeyFetch": MessageLookupByLibrary.simpleMessage("مسیرِ گرفتن کلید"),
    "powKeyAuto": MessageLookupByLibrary.simpleMessage("خودکار (مسابقه ECH و ClientHello تکه‌ای)"),
    "powKeyEch": MessageLookupByLibrary.simpleMessage("فقط ECH"),
    "powKeyFragment": MessageLookupByLibrary.simpleMessage("فقط ClientHello تکه‌ای"),
    "powKeyExternal": MessageLookupByLibrary.simpleMessage("فقط شبکه فعلی"),
    "powObfuscation": MessageLookupByLibrary.simpleMessage("پدینگ مبهم‌سازی"),
    "powChainPsiphon": MessageLookupByLibrary.simpleMessage("زنجیره Psiphon"),
    "powChainPsiphonDesc": MessageLookupByLibrary.simpleMessage("خاموشش کن تا فقط WARP به‌کار رود (بدون پرش Psiphon)."),
    "powH2Fragment": MessageLookupByLibrary.simpleMessage("ClientHello تکه‌ای (HTTP/2)"),
    "powOptimized": MessageLookupByLibrary.simpleMessage("حالت بهینه (زمان‌های کمتر)"),
    "powIrancellH3": MessageLookupByLibrary.simpleMessage("HTTP/3 روی ایرانسل"),
    "powDirectFirst": MessageLookupByLibrary.simpleMessage("اول Psiphon مستقیم"),
    "powStatus": MessageLookupByLibrary.simpleMessage("وضعیت"),
    "powStatusIdle": MessageLookupByLibrary.simpleMessage("آماده. برای شروع تونل «متصل شو» را بزن."),
    "powLogs": MessageLookupByLibrary.simpleMessage("گزارش‌ها"),
    "powShowLogs": MessageLookupByLibrary.simpleMessage("نمایش گزارش‌ها"),
    "powHideLogs": MessageLookupByLibrary.simpleMessage("بستن گزارش‌ها"),
    "powForgetNetworks": MessageLookupByLibrary.simpleMessage("فراموشی حافظه شبکه‌ها"),
    "powForgetNetworksDesc": MessageLookupByLibrary.simpleMessage("کشورهای خروج و برنده‌های راهبردِ به‌یادسپاری‌شده برای شبکه‌هایت را پاک می‌کند."),
    "powWindowsOnly": MessageLookupByLibrary.simpleMessage("این قابلیت فقط روی ویندوز در دسترس است."),
        "powServers": MessageLookupByLibrary.simpleMessage("سرورها"),
        "powAddServer": MessageLookupByLibrary.simpleMessage("افزودن سرور"),
    "powRemove": MessageLookupByLibrary.simpleMessage("حذف وایرکس رایگان"),
    "powRemoveDesc": MessageLookupByLibrary.simpleMessage("سرور و پروفایل وایرکس رایگان از این دستگاه حذف می‌شود. با زدن Connect دوباره ساخته می‌شود."),
    "powRescanStopped": MessageLookupByLibrary.simpleMessage("هنوز سرور سالمی برای Vyrax Free پیدا نشد. برای تلاش دوباره «متصل شو» را بزن."),
        "spoofTitle": MessageLookupByLibrary.simpleMessage("تونل دور زدن SNI"),
    "spoofIntro": MessageLookupByLibrary.simpleMessage("لینک‌های vless و trojan و vmess خودتان را درون‌ریزی کنید و از طریق تونل محلی Xray با تکه‌بندی TLS متصل شوید تا عبور از فیلترینگ سخت‌تر باشد."),
    "spoofImport": MessageLookupByLibrary.simpleMessage("درون‌ریزی لینک‌ها"),
    "spoofImportHint": MessageLookupByLibrary.simpleMessage("لینک‌های vless:// یا trojan:// یا vmess:// را بچسبانید (هر لینک در یک خط)"),
    "spoofImported": MessageLookupByLibrary.simpleMessage("لینک‌ها درون‌ریزی شد"),
    "spoofImportFailed": MessageLookupByLibrary.simpleMessage("هیچ لینک معتبری در متن پیدا نشد"),
    "spoofEmpty": MessageLookupByLibrary.simpleMessage("هنوز لینکی وجود ندارد. برای شروع یک لینک درون‌ریزی کنید."),
    "spoofConnect": MessageLookupByLibrary.simpleMessage("متصل شو"),
    "spoofDisconnect": MessageLookupByLibrary.simpleMessage("قطع"),
    "spoofRemoveConfirm": MessageLookupByLibrary.simpleMessage("این لینک الان انتخاب شده است. با این حال حذف شود؟"),
    "spoofCarrierAuto": MessageLookupByLibrary.simpleMessage("خودکار"),
    "spoofCarrierMci": MessageLookupByLibrary.simpleMessage("همراه اول"),
    "spoofCarrierIrancell": MessageLookupByLibrary.simpleMessage("ایرانسل"),
    "spoofIranDirect": MessageLookupByLibrary.simpleMessage("سایت‌های ایران مستقیم بمانند"),
    "spoofFragmentPlain": MessageLookupByLibrary.simpleMessage("بدون تکه‌بندی"),
    "spoofDownloading": MessageLookupByLibrary.simpleMessage("در حال دانلود Xray"),
    "spoofIdle": MessageLookupByLibrary.simpleMessage("غیرفعال"),
    "spoofRunning": MessageLookupByLibrary.simpleMessage("در حال اجرا"),
    "spoofFailed": MessageLookupByLibrary.simpleMessage("خطا"),
    "spoofExit": MessageLookupByLibrary.simpleMessage("خروجی"),
    "spoofCarrier": MessageLookupByLibrary.simpleMessage("اپراتور"),
    "spoofFragment": MessageLookupByLibrary.simpleMessage("تکه‌بندی"),
    "spoofSettings": MessageLookupByLibrary.simpleMessage("تنظیمات دور زدن"),
    "spoofLinks": MessageLookupByLibrary.simpleMessage("لینک‌ها"),
    "spoofStatus": MessageLookupByLibrary.simpleMessage("وضعیت"),
    "spoofServers": MessageLookupByLibrary.simpleMessage("سرور"),
    "mozillaTitle": MessageLookupByLibrary.simpleMessage("سرورهای رایگان فایرفاکس"),
    "free": MessageLookupByLibrary.simpleMessage("رایگان"),
    "powRescanStarted": MessageLookupByLibrary.simpleMessage(
      "سرور Vyrax Free در دسترس نیست — اسکن مجدد برای یافتن سرور جدید…",
    ),
    "powRescanCompleted": MessageLookupByLibrary.simpleMessage(
      "اسکن Vyrax Free کامل شد — دوباره متصل شدید.",
    ),
    "powRescanFailed": MessageLookupByLibrary.simpleMessage(
      "اسکن مجدد Vyrax Free ناموفق بود؛ به‌صورت خودکار تلاش می‌شود.",
    ),
    "powFlowConnecting": MessageLookupByLibrary.simpleMessage(
      "در حال اتصال Vyrax Free…",
    ),
    "powFlowConnected": MessageLookupByLibrary.simpleMessage(
      "Vyrax Free متصل شد.",
    ),
    "powFlowFailed": MessageLookupByLibrary.simpleMessage(
      "اتصال Vyrax Free برقرار نشد.",
    ),
    "powFlowRetry": MessageLookupByLibrary.simpleMessage("تلاش دوباره"),
    "powFlowDone": MessageLookupByLibrary.simpleMessage("انجام شد"),
    "dnsPresets": MessageLookupByLibrary.simpleMessage("پریست‌های DNS"),
    "optimization": MessageLookupByLibrary.simpleMessage("بهینه‌سازی"),
    "optimizationDesc": MessageLookupByLibrary.simpleMessage(
      "با یک ضربه، مجموعهٔ تنظیمات بهینه‌شدهٔ هسته اعمال می‌شود.",
    ),
    "gamePreset": MessageLookupByLibrary.simpleMessage("گیمینگ"),
    "litePreset": MessageLookupByLibrary.simpleMessage("سبک"),
    "standardPresetDesc": MessageLookupByLibrary.simpleMessage(
      "پرچم‌های تاخیر کم: تاخیر یکپارچه و اتصال همزمان چند TCP.",
    ),
    "gamePresetDesc": MessageLookupByLibrary.simpleMessage(
      "پرچم‌های گیمینگ به‌علاوهٔ DNSهای رادار گیم برای پینگ بهتر داخل بازی.",
    ),
    "litePresetDesc": MessageLookupByLibrary.simpleMessage(
      "لودر سبک geo به‌علاوهٔ DNS ادگارد که تبلیغات را هم فیلتر می‌کند.",
    ),
    "mozillaUseServers": MessageLookupByLibrary.simpleMessage(
      "استفاده از سرورها",
    ),
    "mozillaVerificationCode": MessageLookupByLibrary.simpleMessage(
      "کد تأیید ایمیل",
    ),
    "mozillaVerificationHint": MessageLookupByLibrary.simpleMessage(
      "ورود به حساب Firefox؛ اطلاعات ورود فقط به سرویس حساب‌های Mozilla فرستاده می‌شود.",
    ),
    "mozillaVerify": MessageLookupByLibrary.simpleMessage("تأیید و ادامه"),
    "name": MessageLookupByLibrary.simpleMessage("نام"),
    "navigationBarStyle": MessageLookupByLibrary.simpleMessage("نوار پایین"),
    "network": MessageLookupByLibrary.simpleMessage("شبکه"),
    "networkAccessDeniedError": m48,
    "networkBadResponseError": m49,
    "networkCancelledError": MessageLookupByLibrary.simpleMessage(
      "درخواست لغو شد",
    ),
    "networkConnectionError": MessageLookupByLibrary.simpleMessage(
      "اتصال به سرور ممکن نشد. شبکه و تنظیمات پروکسی را بررسی کنید",
    ),
    "networkDetection": MessageLookupByLibrary.simpleMessage("بررسی شبکه"),
    "networkHostLookupError": MessageLookupByLibrary.simpleMessage(
      "آدرس سرور پیدا نشد. URL و DNS را بررسی کنید",
    ),
    "networkName": MessageLookupByLibrary.simpleMessage("نام شبکه"),
    "networkNotFoundError": m50,
    "networkRateLimitedError": MessageLookupByLibrary.simpleMessage(
      "درخواست‌ها بیش از حد است (HTTP 429). کمی صبر کنید",
    ),
    "networkRequestFailed": m51,
    "networkSecret": MessageLookupByLibrary.simpleMessage("راز شبکه"),
    "networkServerError": m52,
    "networkSpeed": MessageLookupByLibrary.simpleMessage("سرعت شبکه"),
    "networkTimeoutError": MessageLookupByLibrary.simpleMessage(
      "مهلت درخواست تمام شد. شبکه یا پروکسی را بررسی و دوباره تلاش کنید",
    ),
    "networkTlsError": MessageLookupByLibrary.simpleMessage(
      "اتصال امن ناموفق بود. گواهی سرور ممکن است نامعتبر باشد یا اتصال رهگیری شده باشد",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("نوع شبکه"),
    "neutralScheme": MessageLookupByLibrary.simpleMessage("خنثی"),
    "nextMatch": MessageLookupByLibrary.simpleMessage("نتیجهٔ بعدی"),
    "no": MessageLookupByLibrary.simpleMessage("خیر"),
    "noData": MessageLookupByLibrary.simpleMessage("داده‌ای وجود ندارد"),
    "noInfo": MessageLookupByLibrary.simpleMessage("اطلاعاتی نیست"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage(
      "دوباره یادآوری نکن",
    ),
    "noNetwork": MessageLookupByLibrary.simpleMessage("بدون شبکه"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage(
      "برنامه‌های بدون شبکه",
    ),
    "noRecords": MessageLookupByLibrary.simpleMessage("بدون سابقه"),
    "noResolve": MessageLookupByLibrary.simpleMessage("عدم تبدیل دامنه به IP"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage(
      "عدم تبدیل نام میزبان",
    ),
    "noSearchResults": MessageLookupByLibrary.simpleMessage(
      "نتیجه‌ای پیدا نشد",
    ),
    "nodes": MessageLookupByLibrary.simpleMessage("سرورها"),
    "nonTextProviderFile": MessageLookupByLibrary.simpleMessage(
      "این منبع خارجی فایل متنی نیست",
    ),
    "none": MessageLookupByLibrary.simpleMessage("هیچ‌کدام"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "در گروه فعلی امکان انتخاب پروکسی وجود ندارد",
    ),
    "ntpInterval": MessageLookupByLibrary.simpleMessage(
      "فاصلهٔ همگام‌سازی (دقیقه)",
    ),
    "ntpStatusDesc": MessageLookupByLibrary.simpleMessage(
      "زمان از سرور NTP دریافت می‌شود و جایگزین ساعت سیستم می‌شود.",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "برای شروع یک پروفایل اضافه کن",
    ),
    "nullTip": m53,
    "numberRangeTip": m54,
    "numberTip": m55,
    "obfs": MessageLookupByLibrary.simpleMessage("مبهم‌سازی"),
    "obfsHost": MessageLookupByLibrary.simpleMessage("میزبان مبهم‌سازی"),
    "obfsMode": MessageLookupByLibrary.simpleMessage("حالت مبهم‌سازی"),
    "obfsParam": MessageLookupByLibrary.simpleMessage("پارامتر مبهم‌سازی"),
    "obfsPassword": MessageLookupByLibrary.simpleMessage("گذرواژهٔ مبهم‌سازی"),
    "onDemand": MessageLookupByLibrary.simpleMessage("برحسب نیاز"),
    "onDemandDesc": MessageLookupByLibrary.simpleMessage(
      "پروکسی را روی شبکه‌های وای‌فای مستثنا متوقف می‌کند.",
    ),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "فقط شمارش ترافیک پروکسی",
    ),
    "optional": MessageLookupByLibrary.simpleMessage("اختیاری"),
    "options": MessageLookupByLibrary.simpleMessage("گزینه‌ها"),
    "other": MessageLookupByLibrary.simpleMessage("سایر"),
    "otherContributors": MessageLookupByLibrary.simpleMessage(
      "سایر مشارکت‌کنندگان",
    ),
    "outbound": MessageLookupByLibrary.simpleMessage("خروجی"),
    "outboundIp": MessageLookupByLibrary.simpleMessage("IP خروجی"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("حالت خروجی"),
    "overrideDestination": MessageLookupByLibrary.simpleMessage(
      "جایگزینی مقصد",
    ),
    "overrideDestinationDesc": MessageLookupByLibrary.simpleMessage(
      "به‌جای نشانی اصلی، اتصال به دامنهٔ شناسایی‌شده برقرار می‌شود.",
    ),
    "overrideEntries": MessageLookupByLibrary.simpleMessage(
      "گزینه‌های جایگزین",
    ),
    "palette": MessageLookupByLibrary.simpleMessage("پالت"),
    "parsePureIp": MessageLookupByLibrary.simpleMessage("بررسی IP خالص"),
    "parsePureIpDesc": MessageLookupByLibrary.simpleMessage(
      "اتصال‌هایی که فقط نشانی IP دارند هم بررسی می‌شوند.",
    ),
    "password": MessageLookupByLibrary.simpleMessage("رمز عبور"),
    "paste": MessageLookupByLibrary.simpleMessage("چسباندن"),
    "peers": MessageLookupByLibrary.simpleMessage("همتاها"),
    "pickFromAlbum": MessageLookupByLibrary.simpleMessage("انتخاب از گالری"),
    "pinWindow": MessageLookupByLibrary.simpleMessage("سنجاق پنجره"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "ابتدا WebDAV را متصل کن",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "نام اسکریپت را وارد کنید",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "یک کد QR معتبر وارد کن",
    ),
    "plugin": MessageLookupByLibrary.simpleMessage("افزونه"),
    "pluginHost": MessageLookupByLibrary.simpleMessage("میزبان افزونه"),
    "pluginMode": MessageLookupByLibrary.simpleMessage("حالت افزونه"),
    "port": MessageLookupByLibrary.simpleMessage("درگاه"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "پورت دیگری وارد کنید",
    ),
    "portHopping": MessageLookupByLibrary.simpleMessage("پرش پورت"),
    "portTip": m56,
    "ports": MessageLookupByLibrary.simpleMessage("درگاه‌ها"),
    "preSharedKey": MessageLookupByLibrary.simpleMessage("کلید از پیش مشترک"),
    "prerequisites": MessageLookupByLibrary.simpleMessage("پیش‌نیازها"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage(
      "ترکیب کلیدها را فشار دهید",
    ),
    "preview": MessageLookupByLibrary.simpleMessage("پیش‌نمایش"),
    "previousMatch": MessageLookupByLibrary.simpleMessage("نتیجهٔ قبلی"),
    "privateKey": MessageLookupByLibrary.simpleMessage("کلید خصوصی"),
    "privateKeyPassphrase": MessageLookupByLibrary.simpleMessage(
      "گذرواژهٔ کلید خصوصی",
    ),
    "process": MessageLookupByLibrary.simpleMessage("برنامه"),
    "profile": MessageLookupByLibrary.simpleMessage("پروفایل"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("یک فاصلهٔ زمانی معتبر وارد کن"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage("فاصلهٔ به‌روزرسانی را وارد کن"),
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "پروفایل تغییر کرده است. به‌روزرسانی خودکار خاموش شود؟",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "نام پروفایل را وارد کن",
    ),
    "profileSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "فقط روی این پروفایل اعمال می‌شود؛ گزینه‌های اضافه‌نشده از مقدار پیش‌فرض استفاده می‌کنند.",
    ),
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "یک نشانی معتبر برای پروفایل وارد کن",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "نشانی پروفایل را وارد کن",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("پروفایل‌ها"),
    "profilesSort": MessageLookupByLibrary.simpleMessage(
      "مرتب‌سازی پروفایل‌ها",
    ),
    "project": MessageLookupByLibrary.simpleMessage("پروژه"),
    "protocol": MessageLookupByLibrary.simpleMessage("پروتکل"),
    "protocolParam": MessageLookupByLibrary.simpleMessage("پارامتر پروتکل"),
    "protocolVersion": MessageLookupByLibrary.simpleMessage("نسخهٔ پروتکل"),
    "providerInUse": m57,
    "providerUrlTip": MessageLookupByLibrary.simpleMessage(
      "فقط ارائه‌دهندگان راه دور پشتیبانی می‌شوند",
    ),
    "providers": MessageLookupByLibrary.simpleMessage("ارائه‌دهندگان"),
    "proxies": MessageLookupByLibrary.simpleMessage("پروکسی‌ها"),
    "proxiesCount": m58,
    "proxiesEmpty": MessageLookupByLibrary.simpleMessage(
      "پروکسی‌ای وجود ندارد",
    ),
    "proxiesProfileLabel": m59,
    "proxiesRemovedTip": m60,
    "proxiesReplacedTip": m61,
    "proxyChains": MessageLookupByLibrary.simpleMessage("زنجیرهٔ پروکسی"),
    "proxyFavoriteAdd": MessageLookupByLibrary.simpleMessage(
      "افزودن به نشان‌شده‌ها",
    ),
    "proxyFavoriteRemove": MessageLookupByLibrary.simpleMessage(
      "حذف از نشان‌شده‌ها",
    ),
    "proxyFavorites": MessageLookupByLibrary.simpleMessage("سرورهای نشان‌شده"),
    "proxyFavoritesOnly": MessageLookupByLibrary.simpleMessage(
      "فقط سرورهای نشان‌شده",
    ),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("گروه پروکسی"),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage(
      "گروه پروکسی خالی است",
    ),
    "proxyGroupInUse": m62,
    "proxyGroupNameDuplicate": MessageLookupByLibrary.simpleMessage(
      "نام گروه پروکسی تکراری است",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage(
      "ارائه‌دهندگان پروکسی",
    ),
    "proxyProvidersEmpty": MessageLookupByLibrary.simpleMessage(
      "ارائه‌دهندگان پروکسی خالی است",
    ),
    "proxyProvidersNotEmpty": MessageLookupByLibrary.simpleMessage(
      "ارائه‌دهندگان پروکسی نباید خالی باشند",
    ),
    "proxySharing": MessageLookupByLibrary.simpleMessage("اشتراک پروکسی"),
    "proxySharingAuthentication": MessageLookupByLibrary.simpleMessage(
      "احراز هویت پروکسی فعال است. نام کاربری و رمز عبورِ تنظیم‌شده در بخش «عمومی» را در دستگاه دوم هم وارد کن.",
    ),
    "proxySharingConnect": MessageLookupByLibrary.simpleMessage(
      "برای استفاده از این نشانی‌ها، متصل شو و دسترسی شبکهٔ محلی را فعال کن.",
    ),
    "proxySharingEndpoint": MessageLookupByLibrary.simpleMessage(
      "برای کپی بزن · HTTP / SOCKS",
    ),
    "proxySharingHint": MessageLookupByLibrary.simpleMessage(
      "دستگاه‌های دیگرِ شبکهٔ محلی بتوانند از این پروکسی استفاده کنند.",
    ),
    "proxySharingInstructions": MessageLookupByLibrary.simpleMessage(
      "در این برنامه متصل شو و دسترسی شبکهٔ محلی را فعال کن. در دستگاه دوم، یکی از نشانی‌های زیر را به‌عنوان پروکسی HTTP یا SOCKS وارد کن. هر دو دستگاه باید در یک شبکهٔ مطمئن باشند و فایروال ویندوز اجازهٔ اتصال بدهد.",
    ),
    "proxySharingNoAddresses": MessageLookupByLibrary.simpleMessage(
      "نشانی IPv4 محلی پیدا نشد. به وای‌فای یا کابل شبکه وصل شو و تازه‌سازی کن.",
    ),
    "proxyType": MessageLookupByLibrary.simpleMessage("نوع پروکسی"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("پاک‌سازی حافظهٔ نهان"),
    "publicKey": MessageLookupByLibrary.simpleMessage("کلید عمومی"),
    "pureBlack": MessageLookupByLibrary.simpleMessage("مشکی محض"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("حالت مشکی خالص"),
    "qrcode": MessageLookupByLibrary.simpleMessage("کد QR"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "دریافت پروفایل با اسکن کد QR",
    ),
    "quickActions": MessageLookupByLibrary.simpleMessage("عملیات سریع"),
    "quickEdit": MessageLookupByLibrary.simpleMessage("ویرایش سریع"),
    "rainbowScheme": MessageLookupByLibrary.simpleMessage("رنگین‌کمان"),
    "recentRequests": MessageLookupByLibrary.simpleMessage("درخواست‌های اخیر"),
    "recommendedIcons": MessageLookupByLibrary.simpleMessage("پیشنهادی"),
    "recordType": MessageLookupByLibrary.simpleMessage("نوع رکورد"),
    "redirPort": MessageLookupByLibrary.simpleMessage("پورت Redir"),
    "redo": MessageLookupByLibrary.simpleMessage("انجام دوباره"),
    "regex": MessageLookupByLibrary.simpleMessage("عبارت منظم"),
    "releaseMemory": MessageLookupByLibrary.simpleMessage("آزادسازی حافظه"),
    "releaseMemoryFailed": MessageLookupByLibrary.simpleMessage(
      "آزادسازی حافظه ناموفق بود",
    ),
    "remote": MessageLookupByLibrary.simpleMessage("راه دور"),
    "remoteDestination": MessageLookupByLibrary.simpleMessage("مقصد راه دور"),
    "remoteDnsResolve": MessageLookupByLibrary.simpleMessage(
      "تبدیل DNS راه دور",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("حذف"),
    "rename": MessageLookupByLibrary.simpleMessage("تغییر نام"),
    "replace": MessageLookupByLibrary.simpleMessage("جایگزینی"),
    "replaceAll": MessageLookupByLibrary.simpleMessage("جایگزینی همه"),
    "request": MessageLookupByLibrary.simpleMessage("درخواست"),
    "requests": MessageLookupByLibrary.simpleMessage("درخواست‌ها"),
    "requestsAndUpdates": MessageLookupByLibrary.simpleMessage(
      "درخواست‌ها و به‌روزرسانی‌ها",
    ),
    "required": MessageLookupByLibrary.simpleMessage("الزامی"),
    "reset": MessageLookupByLibrary.simpleMessage("بازنشانی"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "این صفحه تغییراتی دارد. از بازنشانی مطمئن هستید؟",
    ),
    "resetTip": MessageLookupByLibrary.simpleMessage(
      "از بازنشانی مطمئن هستید؟",
    ),
    "resourceUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "بازهٔ به‌روزرسانی خودکار",
    ),
    "resourceUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "بازهٔ به‌روزرسانی باید بیشتر از صفر باشد",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("منابع"),
    "respectRules": MessageLookupByLibrary.simpleMessage("رعایت قوانین"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "اتصال‌های DNS بر اساس قوانین هدایت می‌شوند و به DNS مخصوص سرور پروکسی نیاز دارند.",
    ),
    "responseCode": MessageLookupByLibrary.simpleMessage("کد پاسخ"),
    "restart": MessageLookupByLibrary.simpleMessage("راه‌اندازی مجدد"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage(
      "از راه‌اندازی دوبارهٔ هسته مطمئن هستید؟",
    ),
    "restore": MessageLookupByLibrary.simpleMessage("بازیابی"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage(
      "بازیابی همهٔ داده‌ها",
    ),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage(
      "فقط بازیابی پروفایل‌ها",
    ),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage("روش بازیابی"),
    "restoreStrategyCompatible": MessageLookupByLibrary.simpleMessage("سازگار"),
    "restoreStrategyOverride": MessageLookupByLibrary.simpleMessage("جایگزینی"),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage("بازیابی انجام شد"),
    "retry": MessageLookupByLibrary.simpleMessage("تلاش دوباره"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("آدرس‌های مسیریابی"),
    "routeExcludeAddress": MessageLookupByLibrary.simpleMessage(
      "آدرس‌های مستثنا از مسیریابی",
    ),
    "routingMark": MessageLookupByLibrary.simpleMessage("نشان مسیریابی"),
    "ru": MessageLookupByLibrary.simpleMessage("Русский"),
    "rule": MessageLookupByLibrary.simpleMessage("قانون"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage("عملگر منطقی و"),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق کامل دامنه",
    ),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق کلمهٔ کلیدی دامنه",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق عبارت منظم دامنه",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق پسوند دامنه",
    ),
    "ruleActionDomainWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق الگو؛ فقط * و ? پشتیبانی می‌شوند",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق نشان DSCP؛ فقط ورودی tproxy UDP",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق بازهٔ پورت مقصد",
    ),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق کد کشور IP",
    ),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق دامنه‌ها در Geosite",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق نام ورودی",
    ),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق پورت ورودی",
    ),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق نوع ورودی",
    ),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق نام کاربری ورودی؛ چند نام را با / جدا کنید",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق ASN آدرس IP",
    ),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "تطبیق بازهٔ IP؛ IP-CIDR6 فقط یک نام جایگزین است",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق بازهٔ IP",
    ),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق بازهٔ پسوند IP",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق همهٔ درخواست‌ها بدون شرط",
    ),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق TCP یا UDP",
    ),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage(
      "عملگر منطقی نقیض",
    ),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage("عملگر منطقی یا"),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق نام فرایند؛ در اندروید نام بسته را تطبیق می‌دهد",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق عبارت منظم نام فرایند؛ در اندروید نام بسته را تطبیق می‌دهد",
    ),
    "ruleActionProcessNameWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق الگوی نام فرایند؛ فقط * و ? مجاز است",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق مسیر کامل فرایند",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق عبارت منظم مسیر فرایند",
    ),
    "ruleActionProcessPathWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق الگوی مسیر فرایند؛ فقط * و ? مجاز است",
    ),
    "ruleActionRematchNameDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق نام بازتطبیق؛ چند نام را با / جدا کنید",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "ارجاع به مجموعه‌قانون؛ نیازمند rule-providers",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق کد کشور IP مبدأ",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق ASN آدرس IP مبدأ",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق بازهٔ IP مبدأ",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق بازهٔ پسوند IP مبدأ",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق بازهٔ پورت مبدأ",
    ),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق با زیرقانون؛ به پرانتزها دقت کنید",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "تطبیق شناسهٔ کاربر لینوکس",
    ),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("قانون خالی است"),
    "ruleListInvalid": MessageLookupByLibrary.simpleMessage(
      "قوانین باید فهرست YAML با یک قانون در هر مورد باشند، مانند - DOMAIN,example.com,DIRECT",
    ),
    "ruleName": MessageLookupByLibrary.simpleMessage("نام قانون"),
    "rulePresetBittorrentDirect": MessageLookupByLibrary.simpleMessage(
      "اتصال مستقیم BitTorrent",
    ),
    "rulePresetBlockDot": MessageLookupByLibrary.simpleMessage(
      "مسدود کردن DNS بر TLS",
    ),
    "rulePresetBlockLoopback": MessageLookupByLibrary.simpleMessage(
      "جلوگیری از حلقهٔ پروکسی",
    ),
    "rulePresetBlockQuic": MessageLookupByLibrary.simpleMessage(
      "مسدود کردن QUIC",
    ),
    "rulePresetBlockStun": MessageLookupByLibrary.simpleMessage(
      "مسدود کردن STUN",
    ),
    "rulePresetLanDirect": MessageLookupByLibrary.simpleMessage(
      "اتصال مستقیم شبکهٔ محلی",
    ),
    "rulePresetSystemServicesDirect": MessageLookupByLibrary.simpleMessage(
      "اتصال مستقیم Apple و Microsoft",
    ),
    "ruleProviders": MessageLookupByLibrary.simpleMessage(
      "ارائه‌دهندگان قانون",
    ),
    "ruleSet": MessageLookupByLibrary.simpleMessage("مجموعه‌قانون"),
    "ruleSetEmptyTip": MessageLookupByLibrary.simpleMessage(
      "مجموعهٔ قوانین مورد قابل‌استفاده‌ای ندارد",
    ),
    "ruleSetInvalidTip": MessageLookupByLibrary.simpleMessage(
      "خواندن این فایل mrs ممکن نیست",
    ),
    "ruleSetMixedTip": MessageLookupByLibrary.simpleMessage(
      "این مجموعه دامنه و محدودهٔ IP را مخلوط کرده و نوع آن مشخص نیست",
    ),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("مقصد قانون"),
    "ruleTextInvalid": MessageLookupByLibrary.simpleMessage(
      "قانون باید با نوع پشتیبانی‌شده مانند DOMAIN,example.com,DIRECT شروع شود",
    ),
    "rules": MessageLookupByLibrary.simpleMessage("قوانین"),
    "rulesCount": m63,
    "runTime": MessageLookupByLibrary.simpleMessage("زمان اجرا"),
    "safeMode": MessageLookupByLibrary.simpleMessage("حالت امن"),
    "safeModeAppTitle": m64,
    "save": MessageLookupByLibrary.simpleMessage("ذخیره"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("تغییرات ذخیره شوند؟"),
    "savedExitIpAdd": MessageLookupByLibrary.simpleMessage(
      "نشان‌کردن IP خروجی",
    ),
    "savedExitIpRemove": MessageLookupByLibrary.simpleMessage(
      "حذف IP خروجی از نشان‌شده‌ها",
    ),
    "savedExitIps": MessageLookupByLibrary.simpleMessage(
      "IPهای خروجی نشان‌شده",
    ),
    "savedExitIpsError": MessageLookupByLibrary.simpleMessage(
      "خواندن IPهای نشان‌شده ممکن نشد.",
    ),
    "savedExitIpsHint": MessageLookupByLibrary.simpleMessage(
      "این فهرست، IPهای خروجیِ مشاهده‌شده را نگه می‌دارد؛ نشانی را رزرو نمی‌کند و مسیر اتصال را تغییر نمی‌دهد. برای کپی، روی نشانی بزن.",
    ),
    "script": MessageLookupByLibrary.simpleMessage("اسکریپت"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage(
      "حالت اسکریپت: کل پروفایل را با اسکریپت گسترش بازنویسی می‌کند",
    ),
    "scrollToSelected": MessageLookupByLibrary.simpleMessage(
      "رفتن به سرور انتخاب‌شده",
    ),
    "search": MessageLookupByLibrary.simpleMessage("جست‌وجو"),
    "seconds": MessageLookupByLibrary.simpleMessage("ثانیه"),
    "secondsCount": m65,
    "secretKey": MessageLookupByLibrary.simpleMessage("کلید"),
    "sectionsInEffect": m66,
    "selectAll": MessageLookupByLibrary.simpleMessage("انتخاب همه"),
    "selectProxies": MessageLookupByLibrary.simpleMessage("انتخاب پروکسی‌ها"),
    "selectProxyProviders": MessageLookupByLibrary.simpleMessage(
      "انتخاب ارائه‌دهندگان پروکسی",
    ),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage(
      "یک مجموعه‌قانون انتخاب کنید",
    ),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage(
      "یک راهبرد تفکیک انتخاب کنید",
    ),
    "selectSubRule": MessageLookupByLibrary.simpleMessage(
      "یک زیرقانون انتخاب کنید",
    ),
    "selected": MessageLookupByLibrary.simpleMessage("انتخاب‌شده"),
    "selectedCountTitle": m67,
    "server": MessageLookupByLibrary.simpleMessage("سرور"),
    "serviceAvailable": MessageLookupByLibrary.simpleMessage("در دسترس"),
    "serviceBlocked": MessageLookupByLibrary.simpleMessage("مسدود"),
    "serviceCheck": MessageLookupByLibrary.simpleMessage("بررسی"),
    "serviceCheckAll": MessageLookupByLibrary.simpleMessage("بررسی همه"),
    "serviceCheckedAt": m68,
    "serviceComingSoon": MessageLookupByLibrary.simpleMessage("به‌زودی"),
    "serviceDisallowedIsp": MessageLookupByLibrary.simpleMessage(
      "ارائه‌دهندهٔ اینترنت پشتیبانی نمی‌شود",
    ),
    "serviceFailed": MessageLookupByLibrary.simpleMessage("بررسی ناموفق"),
    "serviceManage": MessageLookupByLibrary.simpleMessage("مدیریت سرویس‌ها"),
    "serviceOriginalsOnly": MessageLookupByLibrary.simpleMessage(
      "فقط محتوای اصلی",
    ),
    "servicePending": MessageLookupByLibrary.simpleMessage("بررسی نشده"),
    "serviceRestricted": MessageLookupByLibrary.simpleMessage("دسترسی محدود"),
    "serviceStatus": MessageLookupByLibrary.simpleMessage("وضعیت سرویس"),
    "serviceUnavailable": MessageLookupByLibrary.simpleMessage("خارج از دسترس"),
    "serviceUnsupportedRegion": MessageLookupByLibrary.simpleMessage(
      "منطقه پشتیبانی نمی‌شود",
    ),
    "settingEntries": MessageLookupByLibrary.simpleMessage("تنظیمات"),
    "settings": MessageLookupByLibrary.simpleMessage("تنظیمات"),
    "settingsCount": m69,
    "shareLinkUnreadable": m70,
    "shareLinksInvalid": MessageLookupByLibrary.simpleMessage(
      "پروکسی‌ای از لینک‌ها خوانده نشد",
    ),
    "show": MessageLookupByLibrary.simpleMessage("نمایش"),
    "showLess": MessageLookupByLibrary.simpleMessage("جمع کردن"),
    "showMore": MessageLookupByLibrary.simpleMessage("باز کردن"),
    "showNotificationStopAction": MessageLookupByLibrary.simpleMessage(
      "دکمهٔ توقف در اعلان",
    ),
    "showPassword": MessageLookupByLibrary.simpleMessage("نمایش گذرواژه"),
    "shrink": MessageLookupByLibrary.simpleMessage("جمع‌وجور"),
    "sidebarBlur": MessageLookupByLibrary.simpleMessage("تاریِ نوار کناری"),
    "sidebarBlurDesc": MessageLookupByLibrary.simpleMessage(
      "نمایش محوِ دسکتاپ از پشت نوار کناری پنجره",
    ),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("اجرای بی‌صدا"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "اجرای بی‌صدا پنجرهٔ برنامه را نشان نمی‌دهد.",
    ),
    "singleAdd": MessageLookupByLibrary.simpleMessage("افزودن تکی"),
    "singleImport": MessageLookupByLibrary.simpleMessage("ورود تکی"),
    "singleShareLinkOnly": MessageLookupByLibrary.simpleMessage(
      "اینجا یک لینک وارد کنید؛ چند لینک را از ویرایش سریع فهرست تغییر دهید",
    ),
    "singleValueTip": m71,
    "size": MessageLookupByLibrary.simpleMessage("اندازه"),
    "skipCertVerify": MessageLookupByLibrary.simpleMessage(
      "رد شدن از بررسی گواهی",
    ),
    "skipDomain": MessageLookupByLibrary.simpleMessage(
      "دامنه‌های نادیده‌گرفته‌شده",
    ),
    "skipDomainDesc": MessageLookupByLibrary.simpleMessage(
      "دامنه‌های این فهرست پس از شناسایی استفاده نمی‌شوند.",
    ),
    "skipDstAddress": MessageLookupByLibrary.simpleMessage(
      "نادیده‌گرفتن نشانی‌های مقصد",
    ),
    "skipSrcAddress": MessageLookupByLibrary.simpleMessage(
      "نادیده‌گرفتن نشانی‌های مبدأ",
    ),
    "slide": MessageLookupByLibrary.simpleMessage("لغزش"),
    "sniffProtocols": MessageLookupByLibrary.simpleMessage("پروتکل‌ها"),
    "sniffer": MessageLookupByLibrary.simpleMessage("شناسایی دامنه"),
    "snifferStatusDesc": MessageLookupByLibrary.simpleMessage(
      "دامنه از ترافیک TLS، HTTP و QUIC شناسایی می‌شود تا قوانین روی آن اعمال شوند.",
    ),
    "socksPort": MessageLookupByLibrary.simpleMessage("پورت SOCKS"),
    "sort": MessageLookupByLibrary.simpleMessage("مرتب‌سازی"),
    "source": MessageLookupByLibrary.simpleMessage("مبدأ"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("IP مبدأ"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("پروکسی ویژه"),
    "specialRules": MessageLookupByLibrary.simpleMessage("قوانین ویژه"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage("آمار سرعت"),
    "splitStrategy": MessageLookupByLibrary.simpleMessage("راهبرد تفکیک"),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage(
      "راهبرد تفکیک نباید خالی باشد",
    ),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage(
      "نام وای‌فای وجود ندارد",
    ),
    "stackMode": MessageLookupByLibrary.simpleMessage("نوع پشته"),
    "stackTrace": MessageLookupByLibrary.simpleMessage("ردیابی پشته"),
    "standard": MessageLookupByLibrary.simpleMessage("استاندارد"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "حالت استاندارد: قوانین را به پروفایل اضافه می‌کند",
    ),
    "start": MessageLookupByLibrary.simpleMessage("شروع"),
    "startFromScratch": MessageLookupByLibrary.simpleMessage("شروع از صفر"),
    "startVpn": MessageLookupByLibrary.simpleMessage("در حال شروع VPN…"),
    "startupAndBackground": MessageLookupByLibrary.simpleMessage(
      "شروع و اجرای پس‌زمینه",
    ),
    "status": MessageLookupByLibrary.simpleMessage("وضعیت"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "با خاموش‌بودن DNS، از DNS سیستم استفاده می‌شود.",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("توقف"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("در حال توقف VPN…"),
    "strategy": MessageLookupByLibrary.simpleMessage("راهبرد"),
    "strictRoute": MessageLookupByLibrary.simpleMessage("مسیریابی سخت‌گیرانه"),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "مسیریابی سخت‌گیرانه مانع عبور ترافیکی مانند DNS از بیرون TUN می‌شود و دستگاه‌های دیگر دیگر به این دستگاه دسترسی ندارند.",
    ),
    "style": MessageLookupByLibrary.simpleMessage("سبک"),
    "subRule": MessageLookupByLibrary.simpleMessage("زیرقانون"),
    "subRuleEmpty": MessageLookupByLibrary.simpleMessage("زیرقانون خالی است"),
    "subRuleNotEmpty": MessageLookupByLibrary.simpleMessage(
      "زیرقانون نباید خالی باشد",
    ),
    "submit": MessageLookupByLibrary.simpleMessage("ثبت"),
    "subscriptionInfo": MessageLookupByLibrary.simpleMessage("اطلاعات اشتراک"),
    "sudoPasswordTitle": MessageLookupByLibrary.simpleMessage(
      "گذرواژهٔ sudo را وارد کنید",
    ),
    "suspended": MessageLookupByLibrary.simpleMessage("معلق…"),
    "switchProfile": MessageLookupByLibrary.simpleMessage("تغییر پروفایل"),
    "sync": MessageLookupByLibrary.simpleMessage("همگام‌سازی"),
    "system": MessageLookupByLibrary.simpleMessage("سیستم"),
    "systemApp": MessageLookupByLibrary.simpleMessage("برنامه‌های سیستمی"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("پروکسی سیستم"),
    "tab": MessageLookupByLibrary.simpleMessage("تب"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("پویانمایی زبانه‌ها"),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage(
      "برای دادن مجوز بزنید",
    ),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("اتصال هم‌زمان TCP"),
    "testInterval": MessageLookupByLibrary.simpleMessage("بازهٔ تست"),
    "testUrl": MessageLookupByLibrary.simpleMessage("نشانی آزمایش"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage("تست هنگام استفاده"),
    "textScale": MessageLookupByLibrary.simpleMessage("اندازهٔ متن"),
    "textScalePreview": MessageLookupByLibrary.simpleMessage(
      "متن برنامه به این شکل نمایش داده می‌شود",
    ),
    "theme": MessageLookupByLibrary.simpleMessage("ظاهر"),
    "themeColor": MessageLookupByLibrary.simpleMessage("رنگ ظاهر"),
    "themeDesc": MessageLookupByLibrary.simpleMessage(
      "انتخاب حالت روشن یا تیره و تنظیم رنگ‌ها",
    ),
    "themeMode": MessageLookupByLibrary.simpleMessage("حالت ظاهر"),
    "tight": MessageLookupByLibrary.simpleMessage("فشرده"),
    "time": MessageLookupByLibrary.simpleMessage("زمان"),
    "timeout": MessageLookupByLibrary.simpleMessage("پایان مهلت"),
    "tip": MessageLookupByLibrary.simpleMessage("نکته"),
    "toggle": MessageLookupByLibrary.simpleMessage("تغییر وضعیت"),
    "tolerance": MessageLookupByLibrary.simpleMessage("تلورانس"),
    "tonalSpotScheme": MessageLookupByLibrary.simpleMessage("لکهٔ رنگی"),
    "tools": MessageLookupByLibrary.simpleMessage("ابزارها"),
    "torch": MessageLookupByLibrary.simpleMessage("چراغ‌قوه"),
    "total": MessageLookupByLibrary.simpleMessage("کل سهمیه"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("کل ترافیک"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("پورت TProxy"),
    "trafficUsage": MessageLookupByLibrary.simpleMessage("مصرف ترافیک"),
    "transport": MessageLookupByLibrary.simpleMessage("انتقال"),
    "tun": MessageLookupByLibrary.simpleMessage("تونل"),
    "tunAuthorizationFailed": MessageLookupByLibrary.simpleMessage(
      "مجوز TUN دریافت نشد و خاموش شد.",
    ),
    "tunDesc": MessageLookupByLibrary.simpleMessage(
      "تونل فقط با دسترسی مدیر کار می‌کند.",
    ),
    "turnOff": MessageLookupByLibrary.simpleMessage("خاموش کردن"),
    "turnOn": MessageLookupByLibrary.simpleMessage("روشن کردن"),
    "udpRelayMode": MessageLookupByLibrary.simpleMessage("حالت رلهٔ UDP"),
    "undo": MessageLookupByLibrary.simpleMessage("واگرد"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("تأخیر یکپارچه"),
    "unknown": MessageLookupByLibrary.simpleMessage("نامشخص"),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage(
      "خطای نامشخص شبکه",
    ),
    "unmaximize": MessageLookupByLibrary.simpleMessage(
      "بازگشت به اندازهٔ قبلی",
    ),
    "unnamed": MessageLookupByLibrary.simpleMessage("بدون نام"),
    "unpinWindow": MessageLookupByLibrary.simpleMessage("برداشتن سنجاق پنجره"),
    "update": MessageLookupByLibrary.simpleMessage("به‌روزرسانی"),
    "upload": MessageLookupByLibrary.simpleMessage("ارسال"),
    "uploadBandwidth": MessageLookupByLibrary.simpleMessage("پهنای باند ارسال"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlTip": m72,
    "useHosts": MessageLookupByLibrary.simpleMessage("استفاده از hosts"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage(
      "استفاده از hosts سیستم",
    ),
    "usedTraffic": MessageLookupByLibrary.simpleMessage("ترافیک مصرف‌شده"),
    "userAgent": MessageLookupByLibrary.simpleMessage("User-Agent"),
    "username": MessageLookupByLibrary.simpleMessage("نام کاربری"),
    "value": MessageLookupByLibrary.simpleMessage("مقدار"),
    "vibrantScheme": MessageLookupByLibrary.simpleMessage("زنده"),
    "view": MessageLookupByLibrary.simpleMessage("نمایش"),
    "virtualIpv4": MessageLookupByLibrary.simpleMessage("IPv4 مجازی"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "تغییر پیکربندی مرتبط با VPN شناسایی شد",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "ترافیک سیستم به‌طور خودکار از VpnService عبور می‌کند.",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage(
      "تغییرها پس از راه‌اندازی مجدد VPN اعمال می‌شوند",
    ),
    "vyraxBlack": MessageLookupByLibrary.simpleMessage("مشکی"),
    "vyraxCrimson": MessageLookupByLibrary.simpleMessage("زرشکی"),
    "vyraxGold": MessageLookupByLibrary.simpleMessage("طلایی"),
    "vyraxGraphite": MessageLookupByLibrary.simpleMessage("گرافیتی"),
    "vyraxLight": MessageLookupByLibrary.simpleMessage("روشن گرم"),
    "vyraxOcean": MessageLookupByLibrary.simpleMessage("اقیانوسی"),
    "vyraxRose": MessageLookupByLibrary.simpleMessage("صورتی"),
    "vyraxThemes": MessageLookupByLibrary.simpleMessage("تم‌های Vyrax"),
    "vyraxViolet": MessageLookupByLibrary.simpleMessage("بنفش"),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage(
      "تنظیمات WebDAV",
    ),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("فهرست مجاز"),
    "writeToSystem": MessageLookupByLibrary.simpleMessage("نوشتن در سیستم"),
    "writeToSystemDesc": MessageLookupByLibrary.simpleMessage(
      "ساعت سیستم هم تنظیم می‌شود؛ اندروید این گزینه را نادیده می‌گیرد.",
    ),
    "yearsAgo": m73,
    "yearsAgoShort": m74,
    "yes": MessageLookupByLibrary.simpleMessage("بله"),
    "zhCN": MessageLookupByLibrary.simpleMessage("简体中文"),
  };
}
