/* حالت اولیهٔ رابط. در نسخهٔ نصب‌شده، کانفیگ‌ها و تنظیمات از میزبان می‌آیند. */

/* چند سرور نمونه که فقط در پیش‌نمایش مرورگر دیده می‌شوند.
   در نسخهٔ نصب‌شده رابط همیشه داخل میزبان بومی اجرا می‌شود و این‌ها هرگز نمی‌آیند. */
export const DEMO_PROFILES = [
  { id: 'd1', name: 'Fast (No Ads)', host: 'fast.example.test', protocol: 'vless', port: 443 },
  { id: 'd2', name: 'de1', host: 'laptu6.example.test', protocol: 'vless', port: 443 },
  { id: 'd3', name: 'de2', host: 'laptu7.example.test', protocol: 'vless', port: 443 },
  { id: 'd4', name: 'de3', host: 'laptu8.example.test', protocol: 'vless', port: 443 },
  { id: 'd5', name: 'de4', host: 'laptu9.example.test', protocol: 'vless', port: 443 },
  { id: 'd6', name: 'de5', host: 'laptu10.example.test', protocol: 'vless', port: 443 },
  { id: 'd7', name: 'de6', host: 'laptu11.example.test', protocol: 'vless', port: 443 },
  { id: 'd8', name: 'de7', host: 'laptu12.example.test', protocol: 'vless', port: 443 },
  { id: 'd9', name: 'de8', host: 'laptu13.example.test', protocol: 'vless', port: 443 },
  { id: 'd10', name: 'deFast1', host: 'de-fast.example.test', protocol: 'vmess', port: 8443 },
  { id: 'd11', name: 'deFast2', host: 'de-fast2.example.test', protocol: 'vmess', port: 8443 },
  { id: 'd12', name: 'nl1', host: 'ams.example.net', protocol: 'trojan', port: 443 },
  { id: 'd13', name: 'nl2', host: 'rtm.example.net', protocol: 'trojan', port: 443 },
  { id: 'd14', name: 'us-premium', host: 'x.example.com', protocol: 'shadowsocks', port: 8388 },
  { id: 'd15', name: 'tr1', host: 'ist.example.net', protocol: 'vless', port: 443 },
  { id: 'd16', name: 'favourite one', host: 'fav.example.net', protocol: 'vless', port: 443, favorite: true }
];

export const INITIAL_STATE = {
  connected: false,
  connecting: false,
  /* هیچ عدد نمایشی از پیش پر نمی‌شود؛ تا وقتی چیزی اندازه‌گیری نشده «‎--» نشان می‌دهیم */
  stage: '',
  latency: null,
  baseline: null,
  jitter: null,
  loss: null,
  uptime: 0,
  up: 0,
  down: 0,
  upRate: 0,
  downRate: 0,
  ip: null,
  exit: null,
  starIp: false,
  settings: {
    preferencesVersion: 1,
    autoConnect: false,
    autoReconnect: false,
    splitTunneling: false,
    bypassSites: false,
    proxyShare: false,
    splitAddresses: [],
    bypassAddresses: [],
    theme: 'dark',
    /* 'proxy' = پروکسی سیستم، 'tun' = VPN کاملِ دستگاه.
       عمداً پیش‌فرض 'proxy' است: بار اول بدون پیام UAC باز می‌شود و هر مودی که
       کاربر آخرین بار انتخاب کرده باشد از همان‌جا ذخیره و برگردانده می‌شود. */
    mode: 'proxy',
    mtu: 1280
  }
};
