import { FLAG_CODES } from './flag-codes.js';

/* تشخیص کشور یک سرور.
   ترتیب اولویت مهم است:
     ۱. نامی که خودِ کاربر گذاشته («DE1»، «deFast2»، «Tokyo Japan») — معتبرترین نشانه،
        چون کانفیگ‌های تانل‌شده ممکن است IP ورودی‌شان جای دیگری باشد.
     ۲. برچسب‌های خودِ میزبان، بدون دامنهٔ سطح‌اول. پس «netbazshop.ir» کشور ایران نیست.
     ۳. و در آخر پرسیدن از میزبان (resolve + پایگاه دادهٔ کشور).
   هیچ پرس‌وجویی به بیرون نمی‌رود. */

const IPV4 = /^\d{1,3}(\.\d{1,3}){3}$/;

export function isIpv4(host) {
  if (!IPV4.test(host)) return false;
  return host.split('.').every((n) => Number(n) >= 0 && Number(n) <= 255);
}

export function isIpv6(host) {
  return Boolean(host) && host.includes(':') && /^[0-9a-f:]+$/i.test(host);
}

export function isIp(host) {
  return isIpv4(host) || isIpv6(host);
}

/* ---------- حدس از روی متن ----------
   نام‌ها هم انگلیسی‌اند و هم فارسی، چون کاربر کانفیگ‌هایش را فارسی نام‌گذاری
   می‌کند («آلمان1»، «هلندFast2»). نام شهرها هم آمده‌اند چون خیلی از سرورها با
   شهر شناخته می‌شوند. */

const NAMES = {
  /* انگلیسی */
  'united arab emirates': 'ae', 'united kingdom': 'gb', 'united states': 'us',
  'south africa': 'za', 'new zealand': 'nz', 'saudi arabia': 'sa', 'hong kong': 'hk',
  'los angeles': 'us', 'new york': 'us',
  germany: 'de', netherlands: 'nl', holland: 'nl', france: 'fr', austria: 'at',
  belgium: 'be', sweden: 'se', turkey: 'tr', türkiye: 'tr', turkiye: 'tr',
  usa: 'us', america: 'us', brazil: 'br', croatia: 'hr', albania: 'al',
  australia: 'au', bulgaria: 'bg', canada: 'ca', switzerland: 'ch', czechia: 'cz',
  denmark: 'dk', estonia: 'ee', spain: 'es', finland: 'fi', britain: 'gb',
  england: 'gb', georgia: 'ge', greece: 'gr', hungary: 'hu', ireland: 'ie',
  israel: 'il', india: 'in', iceland: 'is', iran: 'ir', italy: 'it', japan: 'jp',
  korea: 'kr', lithuania: 'lt', luxembourg: 'lu', latvia: 'lv', moldova: 'md',
  norway: 'no', poland: 'pl', portugal: 'pt', romania: 'ro', serbia: 'rs',
  singapore: 'sg', slovenia: 'si', slovakia: 'sk', ukraine: 'ua', russia: 'ru',
  china: 'cn', hongkong: 'hk', taiwan: 'tw', vietnam: 'vn', thailand: 'th',
  malaysia: 'my', indonesia: 'id', philippines: 'ph', egypt: 'eg', nigeria: 'ng',
  kenya: 'ke', mexico: 'mx', argentina: 'ar', chile: 'cl', colombia: 'co',
  peru: 'pe', qatar: 'qa', emirates: 'ae', pakistan: 'pk', bangladesh: 'bd',
  armenia: 'am', azerbaijan: 'az', cyprus: 'cy', malta: 'mt', mongolia: 'mn',
  /* شهرها */
  frankfurt: 'de', amsterdam: 'nl', london: 'gb', paris: 'fr', istanbul: 'tr',
  moscow: 'ru', dubai: 'ae', tokyo: 'jp', seoul: 'kr', sydney: 'au',
  toronto: 'ca', chicago: 'us', miami: 'us', dallas: 'us', seattle: 'us',
  vienna: 'at', zurich: 'ch', brussels: 'be', stockholm: 'se', oslo: 'no',
  copenhagen: 'dk', helsinki: 'fi', warsaw: 'pl', prague: 'cz', madrid: 'es',
  barcelona: 'es', lisbon: 'pt', rome: 'it', milan: 'it', athens: 'gr',
  budapest: 'hu', bucharest: 'ro', sofia: 'bg', belgrade: 'rs', zagreb: 'hr',
  kyiv: 'ua', kiev: 'ua', riga: 'lv', tallinn: 'ee', vilnius: 'lt',
  tbilisi: 'ge', yerevan: 'am', baku: 'az', tehran: 'ir',
  /* فارسی */
  'امارات متحده عربی': 'ae', 'عربستان سعودی': 'sa', 'آفریقای جنوبی': 'za',
  'کره جنوبی': 'kr', 'کره شمالی': 'kp', 'ایالات متحده': 'us', 'هنگ کنگ': 'hk',
  'لس آنجلس': 'us', 'نیویورک': 'us', 'نیو یورک': 'us',
  آلمان: 'de', هلند: 'nl', هالند: 'nl', فرانسه: 'fr', اتریش: 'at',
  بلژیک: 'be', سوئد: 'se', ترکیه: 'tr', امریکا: 'us', آمریکا: 'us',
  کانادا: 'ca', استرالیا: 'au', بلغارستان: 'bg', سوئیس: 'ch',
  سوِیس: 'ch', چک: 'cz', دانمارک: 'dk', استونی: 'ee', اسپانیا: 'es',
  فنلاند: 'fi', انگلیس: 'gb', انگلستان: 'gb', بریتانیا: 'gb', گرجستان: 'ge',
  یونان: 'gr', مجارستان: 'hu', ایرلند: 'ie', اسرائیل: 'il', هند: 'in',
  ایسلند: 'is', ایران: 'ir', ایتالیا: 'it', ژاپن: 'jp', کره: 'kr',
  لیتوانی: 'lt', لوکزامبورگ: 'lu', لتونی: 'lv', مولداوی: 'md', نروژ: 'no',
  لهستان: 'pl', پرتغال: 'pt', رومانی: 'ro', صربستان: 'rs', سنگاپور: 'sg',
  اسلوونی: 'si', اسلواکی: 'sk', اوکراین: 'ua', اکراین: 'ua', روسیه: 'ru',
  چین: 'cn', هنگ‌کنگ: 'hk', تایوان: 'tw', ویتنام: 'vn', تایلند: 'th',
  مالزی: 'my', اندونزی: 'id', فیلیپین: 'ph', مصر: 'eg', نیجریه: 'ng',
  کنیا: 'ke', مکزیک: 'mx', آرژانتین: 'ar', شیلی: 'cl', کلمبیا: 'co',
  پرو: 'pe', قطر: 'qa', پاکستان: 'pk', بنگلادش: 'bd', ارمنستان: 'am',
  آذربایجان: 'az', قبرس: 'cy', کرواسی: 'hr', آلبانی: 'al', برزیل: 'br',
  عراق: 'iq', افغانستان: 'af', تاجیکستان: 'tj', ازبکستان: 'uz', قزاقستان: 'kz',
  لبنان: 'lb', اردن: 'jo', کویت: 'kw', بحرین: 'bh', عمان: 'om', سوریه: 'sy',
  مغولستان: 'mn', مالت: 'mt',
  /* شهرهای فارسی */
  فرانکفورت: 'de', آمستردام: 'nl', لندن: 'gb', پاریس: 'fr', استانبول: 'tr',
  مسکو: 'ru', دبی: 'ae', توکیو: 'jp', سئول: 'kr', سیدنی: 'au', تورنتو: 'ca',
  شیکاگو: 'us', میامی: 'us', دالاس: 'us', سیاتل: 'us', وین: 'at', زوریخ: 'ch',
  بروکسل: 'be', استکهلم: 'se', اسلو: 'no', کپنهاگ: 'dk', هلسینکی: 'fi',
  ورشو: 'pl', پراگ: 'cz', مادرید: 'es', بارسلونا: 'es', لیسبون: 'pt',
  رم: 'it', میلان: 'it', آتن: 'gr', بوداپست: 'hu', بخارست: 'ro', صوفیه: 'bg',
  بلگراد: 'rs', زاگرب: 'hr', کیف: 'ua', ریگا: 'lv', تالین: 'ee',
  ویلنیوس: 'lt', تفلیس: 'ge', ایروان: 'am', باکو: 'az', تهران: 'ir'
};

/* کدهایی که خودشان کلمهٔ رایج انگلیسی‌اند و بدون عدد قابل اعتماد نیستند */
const AMBIGUOUS = new Set(['in', 'is', 'it', 'no', 'at', 'be', 'me', 'so', 'to', 'my', 'by']);

/* نام‌ها با مرزِ حرفی و رقمی تطبیق داده می‌شوند. «آلمان1» بله، ولی «پرو» داخل
   «پروتکل» نه و «GB» داخل «100GB» هم نه. بلندترین نام اول می‌آید تا
   «امارات متحده عربی» بر «عربستان» مقدم باشد. */
const NAME_MATCHERS = Object.entries(NAMES)
  .sort((a, b) => b[0].length - a[0].length)
  .map(([name, cc]) => [
    new RegExp(
      `(?<![\\p{L}\\p{N}])${name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(?!\\p{L})`,
      'iu'
    ),
    cc
  ]);

/* «deFast2» باید دو تکه شود: de و Fast2 */
export function tokenize(text) {
  const out = [];
  for (const chunk of String(text || '').split(/[^A-Za-z0-9]+/)) {
    if (!chunk) continue;
    for (const part of chunk.split(/(?<=[a-z0-9])(?=[A-Z])/)) {
      if (part) out.push(part.toLowerCase());
    }
  }
  return out;
}

/* یک کد دوحرفی باید «تمام» یک تکه باشد یا با عدد ادامه یابد («de» و «de2»).
   پیشوندِ خالی را قبول نمی‌کنیم وگرنه «Ads» می‌شود آندورا و «server» می‌شود سوئد. */
function countryFromTokens(tokens) {
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];
    if (token.length === 2 && FLAG_CODES.has(token) && !AMBIGUOUS.has(token)) {
      /* «30 GB» یعنی گیگابایت، نه بریتانیا */
      if (/^\d+$/.test(tokens[i - 1] || '')) continue;
      return token;
    }
    const tail = token.slice(2);
    if (tail && /^\d+$/.test(tail) && FLAG_CODES.has(token.slice(0, 2))) return token.slice(0, 2);
  }
  return null;
}

function countryFromNames(text) {
  const hay = String(text || '');
  if (!hay) return null;
  for (const [re, cc] of NAME_MATCHERS) if (re.test(hay)) return cc;
  return null;
}

/* ---------- پرچمِ داخل نام ----------
   کاربر کشور را با ایموجی پرچم در نام می‌گذارد («🇩🇪1»، «🇫🇮Fast8»). ویندوز ایموجی
   پرچم را رندر نمی‌کند و جای آن حروف «DE» را نشان می‌دهد؛ پس به‌جای تکیه بر متن،
   کد کشور را مستقیم از خودِ ایموجی می‌خوانیم. قوی‌ترین نشانه است. */

const REGIONAL = /[\u{1F1E6}-\u{1F1FF}]{2}/u;

export function codeFromEmoji(text) {
  const hit = String(text || '').match(REGIONAL);
  if (!hit) return null;
  const cc = [...hit[0]]
    .map((ch) => String.fromCharCode(ch.codePointAt(0) - 0x1f1e6 + 97))
    .join('');
  return /^[a-z]{2}$/.test(cc) ? cc : null;
}

/* نامی که در فهرست نشان داده می‌شود: پرچم جایش را به پرچم واقعیِ خودمان می‌دهد و
   بقیهٔ ایموجی‌ها هم برداشته می‌شوند، چون ویندوز بیشترشان را ناخوش می‌کشد. */
const EMOJI = /[\u{1F1E6}-\u{1F1FF}\u{1F3FB}-\u{1F3FF}\u{FE0F}\u{20E3}\u{200D}]|\p{Extended_Pictographic}/gu;

export function cleanName(name) {
  return String(name || '')
    .replace(EMOJI, ' ')
    .replace(/\(\s*\)/g, '')
    .replace(/\s+/g, ' ')
    .replace(/\s+\)/g, ')')
    .trim();
}

/* نام کانفیگ — قوی‌ترین نشانه */
export function countryFromName(profile) {
  return (
    codeFromEmoji(profile.name) ||
    countryFromNames(profile.name) ||
    countryFromTokens(tokenize(profile.name))
  );
}

/* برچسب‌های میزبان، بدون دامنهٔ سطح‌اول تا «‎.ir» و «‎.de» با کشور اشتباه نشوند */
export function countryFromHost(profile) {
  const host = String(profile.host || '');
  if (!host || isIp(host)) return null;

  const labels = host.toLowerCase().split('.');
  const withoutTld = labels.slice(0, -1);

  const byName = countryFromNames(withoutTld.join(' '));
  if (byName) return byName;

  return countryFromTokens(withoutTld.flatMap(tokenize));
}

/* ---------- ترتیب نهایی ---------- */

export function countryOf(profile) {
  if(profile.protocol==='firefox')return profile.cc || null;
  return countryFromName(profile) || countryFromHost(profile) || profile.cc || null;
}

/* فقط وقتی از میزبان بپرسیم که از روی متن چیزی نفهمیده باشیم */
export function needsGeo(profile) {
  if(profile.protocol==='firefox')return false;
  if (!profile.host || profile.cc) return false;
  return !countryFromName(profile) && !countryFromHost(profile);
}

const PROTO = { vless: 'VL', vmess: 'VM', trojan: 'TR', shadowsocks: 'SS', firefox:'FX' };

export function protoLabel(profile) {
  return PROTO[profile.protocol] || String(profile.protocol || '??').slice(0, 2).toUpperCase();
}
