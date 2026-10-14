/* Vyrax site: Copyright (c) 2026 Amyrax. MIT.
   Night ridge interactions adapted from PromptPad by Ramin Turne.
   See assets/REFERENCE-NOTICE.md. */
'use strict';
const repo = 'https://github.com/AmyraxVPN-Main/Vyrax';
const $ = (s) => document.querySelector(s);
const copy = {
  "en": {
    "skip": "Skip to content",
    "features": "Features",
    "download": "Download",
    "releaseLabel": "Public release",
    "intro": "Keep your subscriptions together. Pick your route and connect with a tap. Vyrax is a free, open-source VPN client for mobile and desktop.",
    "getVyrax": "Get Vyrax",
    "everywhere": "At home on your devices",
    "featuresTitle": "Everything in its place.",
    "featuresIntro": "From your first subscription link to your next route. The tools you use every day.",
    "smartTitle": "Let the route find you.",
    "smartBody": "Try automatic and balanced selection, or take control and choose one server. Your choices stay within the active subscription.",
    "subTitle": "Subscriptions, organised.",
    "subBody": "Import a subscription link or several configs as one group. Switch groups, copy links, and share them with a QR code.",
    "delayTitle": "Test the actual route.",
    "delayBody": "Response time is measured through each config so you can compare routes. The lowest latency does not always mean the fastest download.",
    "uiTitle": "A familiar place, everywhere.",
    "uiBody": "Persian and English, multiple themes, and smooth transitions. The same familiar connection screen on your phone and desktop.",
    "openTitle": "Open code. Your choice.",
    "openBody": "Read the code, change it, and share it with the copyright and license intact. Follow Amyrax for news and new releases.",
    "viewCode": "Explore the code on GitHub ↗",
    "startTitle": "From download to connected.",
    "startIntro": "Bring your own config or subscription link. Vyrax takes care of the client.",
    "step1": "Get your version",
    "step1Body": "Download and install the file for your operating system and device architecture.",
    "step2": "Add a subscription",
    "step2Body": "Open Add and paste your subscription link or a group of configs.",
    "step3": "Choose a route and connect",
    "step3Body": "Approve the VPN permission, then use automatic selection or your preferred server.",
    "panel": "Want your own panel? Explore Amyrax Panel.",
    "downloadTitle": "One download to get started.",
    "stable": "Stable version",
    "freeOpen": "Free & open source",
    "chooseFile": "Choose a build",
    "downloadFile": "Download installer",
    "allFiles": "All files & release notes ↗",
    "iosNote": "iPhone / iPad: no public installer yet. The iOS build needs Apple signing and distribution.",
    "iosDetails": "About iOS ↗",
    "faqTitle": "Before you connect.",
    "faq1": "Does Vyrax include free servers?",
    "faq1Body": "Vyrax is a free client. You need a config or subscription link from your own provider. The app does not include servers or a paid subscription.",
    "faq2": "Which Android file do I need?",
    "faq2Body": "Most recent phones use arm64-v8a. armeabi-v7a is for 32-bit devices. Choose Universal if you are unsure; it is larger and covers both. Android 10 or later is required.",
    "faq3": "Why is there an installation warning?",
    "faq3Body": "Windows builds do not have a commercial publisher certificate, and macOS builds are not yet notarized. Your operating system may show a trust warning. Android may also flag installation outside an app store. Get official files from this repository’s releases and read the platform installation guide.",
    "faq4": "How do I find updates?",
    "faq4Body": "When a new stable version is published on GitHub, the app shows a small, dismissible notification. Clicking it opens the latest release page.",
    "communityTitle": "Made by Amyrax.",
    "communityBody": "Release news on Telegram. Ideas and bug reports on GitHub.",
    "telegram": "Telegram channel ↗",
    "issue": "Report an issue ↗",
    "license": "License",
    "themes": "Themes",
    "heroKicker": "[ Vyrax · a free, open-source VPN client ]",
    "themesTitle": "A connection with your colours.",
    "themesIntro": "Eight themes. Your own atmosphere. Browse screenshots of each theme inside the actual app.",
    "themeCaption": "Screenshots show the actual Vyrax interface with example server and connection data.",
    "realInterface": "The actual Vyrax interface",
    "serversCaption": "Choose your route in Vyrax",
    "subscriptionsCaption": "All your subscriptions, together",
    "delayCaption": "Compare route delays",
    "appearanceCaption": "Your colours. Your language.",
    "aboutCaption": "Vyrax, made by Amyrax",
    "shotHome": "Screenshot of the actual Vyrax connection screen",
    "shotTheme": "Screenshot of the {theme} theme in Vyrax",
    "shotServers": "Actual Vyrax server selection and automatic routing screen",
    "shotSubscriptions": "Actual subscription management screen in Vyrax",
    "shotDelay": "Example results in the actual Vyrax delay test screen",
    "shotAppearance": "Theme and language choices in the actual Vyrax account screen",
    "shotAbout": "The actual Vyrax About screen, MIT license and Amyrax links"
  },
  "fa": {
    "shotHome": "اسکرین‌شات صفحهٔ اتصال واقعی Vyrax",
    "shotTheme": "اسکرین‌شات تم {theme} در Vyrax",
    "shotServers": "صفحهٔ واقعی انتخاب سرور و حالت‌های خودکار Vyrax",
    "shotSubscriptions": "صفحهٔ واقعی مدیریت اشتراک‌ها در Vyrax",
    "shotDelay": "نتایج نمونه در صفحهٔ واقعی تست تأخیر Vyrax",
    "shotAppearance": "انتخاب تم و زبان در صفحهٔ واقعی حساب Vyrax",
    "shotAbout": "صفحهٔ واقعی دربارهٔ Vyrax، مجوز MIT و لینک‌های Amyrax"
  }
};
let lang='fa', os='windows', release=null, galleryTheme=0;
const palettes=[['dark','Dark','کلاسیک','#52d887'],['crimson','Crimson','مشکی و قرمز','#ff3b4f'],['black','Black','مشکی محض','#ffffff'],['ocean','Ocean','اقیانوس','#3b9bff'],['violet','Violet','بنفش','#a371f7'],['gold','Gold','مشکی و طلایی','#e8b931'],['rose','Rose','رز','#ff5c8a'],['light','Light','روشن','#0eb09f']];
function renderScreenshots(){
  document.querySelectorAll('img[data-shot]').forEach(img=>{
    const src='assets/screenshots/'+img.dataset.shot+'-'+lang+'.jpg';
    if(img.getAttribute('src')!==src)img.src=src;
    const text=copy[lang][img.dataset.shotAlt];
    img.alt=text.replace('{theme}',palettes[galleryTheme][lang==='fa'?2:1]);
    img.closest('a').href=src;
  });
  $('#gallery-name').textContent=palettes[galleryTheme][lang==='fa'?2:1];
  $('#previous-theme').setAttribute('aria-label',lang==='fa'?'تم قبلی':'Previous theme');
  $('#next-theme').setAttribute('aria-label',lang==='fa'?'تم بعدی':'Next theme');
  $('#theme-dots').setAttribute('aria-label',lang==='fa'?'انتخاب تم':'Choose a theme');
  $('#theme-dots').querySelectorAll('button').forEach((b,i)=>b.setAttribute('aria-label',palettes[i][lang==='fa'?2:1]));
}
palettes.forEach(([id,name,faName,accent],index)=>{const button=document.createElement('button');button.className='fxdot';button.type='button';button.role='tab';button.id='theme-'+id;button.setAttribute('aria-label',faName);button.setAttribute('aria-controls','theme-stage');button.style.setProperty('--dot',accent);button.addEventListener('click',()=>chooseTheme(index));$('#theme-dots').append(button);});
function chooseTheme(index){
  galleryTheme=(index+palettes.length)%palettes.length;
  const [id,name,faName,accent]=palettes[galleryTheme];
  $('#theme-stage').style.setProperty('--theme-accent',accent);
  $('#theme-stage').setAttribute('aria-labelledby','theme-'+id);
  $('#gallery-image').dataset.shot='home-'+id;
  $('#gallery-count').textContent=String(galleryTheme+1).padStart(2,'0')+' / 08';
  $('#theme-dots').querySelectorAll('button').forEach((b,i)=>{b.setAttribute('aria-selected',String(i===galleryTheme));b.tabIndex=i===galleryTheme?0:-1;});
  renderScreenshots();
}
$('#previous-theme').addEventListener('click',()=>chooseTheme(galleryTheme-1));
$('#next-theme').addEventListener('click',()=>chooseTheme(galleryTheme+1));
$('#theme-dots').addEventListener('keydown',e=>{if(!['ArrowLeft','ArrowRight','Home','End'].includes(e.key))return;e.preventDefault();chooseTheme(e.key==='Home'?0:e.key==='End'?palettes.length-1:galleryTheme+(e.key==='ArrowRight'?1:-1));$('#theme-dots').querySelectorAll('button')[galleryTheme].focus();});
$('#theme-stage').addEventListener('keydown',e=>{if(e.target!==e.currentTarget||!['ArrowLeft','ArrowRight','Home','End'].includes(e.key))return;e.preventDefault();chooseTheme(e.key==='Home'?0:e.key==='End'?palettes.length-1:galleryTheme+(e.key==='ArrowRight'?1:-1));});
let touchStart=null;
$('#theme-stage').addEventListener('pointerdown',e=>{if(e.pointerType==='touch')touchStart={x:e.clientX,y:e.clientY};});
$('#theme-stage').addEventListener('pointerup',e=>{if(!touchStart)return;const dx=e.clientX-touchStart.x,dy=e.clientY-touchStart.y;touchStart=null;if(Math.abs(dx)>45&&Math.abs(dx)>Math.abs(dy))chooseTheme(galleryTheme+(dx<0?1:-1));});
$('#theme-stage').addEventListener('pointercancel',()=>{touchStart=null;});
$('#gallery-image').addEventListener('load',e=>{if(!window.matchMedia('(prefers-reduced-motion: reduce)').matches)e.target.animate([{opacity:.3,transform:'translateY(8px)'},{opacity:1,transform:'translateY(0)'}],{duration:320,easing:'cubic-bezier(.22,.61,.21,1)'});});
chooseTheme(0);

document.querySelectorAll('[data-i18n]').forEach(el => copy.fa[el.dataset.i18n] = el.textContent);
const saved = (key) => { try {return localStorage.getItem(key);} catch {return null;} };
const save = (key,value) => { try {localStorage.setItem(key,value);} catch {} };
const platforms = {
  windows: {name:'Windows', descriptions:{fa:'Windows 10 / 11 · پردازندهٔ ۶۴ بیتی',en:'Windows 10 / 11 · 64-bit processor'}, notes:{fa:'برای TUN دسترسی ادمین درخواست می‌شود. Microsoft Edge WebView2 Runtime لازم است. این نسخه هنوز گواهی ناشر تجاری ندارد.',en:'TUN requests administrator permission. Microsoft Edge WebView2 Runtime is required. This build does not yet have a commercial publisher certificate.'},guide:'windows', choices:[['x64','Windows x64 · Setup EXE',v=>`VyraxSetup-${v}.exe`]]},
  android: {name:'Android',descriptions:{fa:'Android 10 یا جدیدتر · APK امضاشده',en:'Android 10 or later · signed APK'},notes:{fa:'برای بیشتر گوشی‌های جدید، arm64-v8a مناسب است. اگر معماری را نمی‌دانی Universal را بگیر. اجازهٔ VPN در اولین اتصال درخواست می‌شود.',en:'arm64-v8a fits most recent phones. Choose Universal if you are unsure. The app requests VPN permission on the first connection.'},guide:'android',choices:[['arm64','arm64-v8a · ARM 64-bit',v=>`Vyrax-${v}-arm64-v8a-release.apk`],['armv7','armeabi-v7a · ARM 32-bit',v=>`Vyrax-${v}-armeabi-v7a-release.apk`],['universal','Universal · All architectures',v=>`Vyrax-${v}-universal-release.apk`],['x86_64','x86_64 · Emulator / Intel',v=>`Vyrax-${v}-x86_64-release.apk`],['x86','x86 · 32-bit Intel',v=>`Vyrax-${v}-x86-release.apk`]]},
  macos: {name:'macOS',descriptions:{fa:'macOS 13 یا جدیدتر · Apple Silicon و Intel',en:'macOS 13 or later · Apple Silicon & Intel'},notes:{fa:'نسخهٔ مک فعلاً با امضای محلی عرضه می‌شود و notarized نیست؛ ممکن است برای اولین اجرا تأیید امنیتی لازم باشد. راهنمای نصب را پیش از اجرا بخوان.',en:'macOS packages currently use ad-hoc signing and are not notarized. First launch may require a security approval. Read the installation guide before opening.'},guide:'macos',choices:[['arm64','Apple Silicon · M1 / M2 / M3 / M4 / M5 · DMG',v=>`Vyrax-${v}-macos-arm64.dmg`],['x64','Intel · x64 · DMG',v=>`Vyrax-${v}-macos-x64.dmg`],['arm64zip','Apple Silicon · ZIP',v=>`Vyrax-${v}-macos-arm64.zip`],['x64zip','Intel · ZIP',v=>`Vyrax-${v}-macos-x64.zip`]]},
  linux: {name:'Linux',descriptions:{fa:'دسکتاپ لینوکس · بستهٔ DEB و آرشیو قابل حمل',en:'Linux desktop · DEB package & portable archive'},notes:{fa:'بستهٔ DEB برای Debian / Ubuntu و توزیع‌های سازگار است. حالت TUN از Polkit استفاده می‌کند. پیش‌نیازهای نسخهٔ قابل حمل در راهنما آمده‌اند.',en:'The DEB package targets Debian / Ubuntu and compatible distributions. TUN uses Polkit. See the guide for portable archive dependencies.'},guide:'linux',choices:[['x64','x64 · Debian / Ubuntu · DEB',v=>`Vyrax-${v}-linux-x64.deb`],['arm64','ARM64 · Debian / Ubuntu · DEB',v=>`Vyrax-${v}-linux-arm64.deb`],['x64tar','x64 · Portable TAR.GZ',v=>`Vyrax-${v}-linux-x64.tar.gz`],['arm64tar','ARM64 · Portable TAR.GZ',v=>`Vyrax-${v}-linux-arm64.tar.gz`]]}
};
function renderDownload(keepChoice=false) {
  const p = platforms[os], select = $('#architecture'), previous = keepChoice ? select.value : '';
  $('#platform-name').textContent = `Vyrax for ${p.name}`;
  $('#platform-description').textContent = p.descriptions[lang];
  select.replaceChildren(...p.choices.map(([value,label]) => new Option(label,value)));
  if (p.choices.some(c=>c[0]===previous)) select.value=previous;
  $('#install-note').replaceChildren(document.createTextNode(p.notes[lang]+' '));
  const guide=document.createElement('a'); guide.className='text-link';guide.style.marginTop='0';guide.href=repo+'/blob/main/'+(os==='windows'?'README.md':`docs/${p.guide}.md`);guide.textContent=lang==='fa'?'راهنمای نصب ↗':'Installation guide ↗';$('#install-note').append(guide);
  $('#download-panel').setAttribute('aria-labelledby','tab-'+os);
  document.querySelectorAll('[data-os]').forEach(b=>{const active=b.dataset.os===os;b.setAttribute('aria-selected',String(active));b.tabIndex=active?0:-1;});
  updateFile();
}
function updateFile() {
  const v = release?.tag_name?.replace(/^v/,'');
  const choice=platforms[os].choices.find(c=>c[0]===$('#architecture').value);
  const name=v?choice[2](v):null;
  const asset=release?.assets?.find(a=>a.name===name && /^https:\/\/github\.com\/AmyraxVPN-Main\/Vyrax\/releases\/download\//.test(a.browser_download_url));
  $('#download-file').href=asset?.browser_download_url||repo+'/releases/latest';
  $('#download-file [data-i18n]').textContent=asset?copy[lang].downloadFile:(lang==='fa'?'رفتن به صفحهٔ ریلیز':'Open release page');
  $('#file-description').textContent=asset?`${(asset.size/1048576).toFixed(1)} MB · ${asset.name.split('.').pop().toUpperCase()}`:(lang==='fa'?'فایل‌ها از GitHub Releases دریافت می‌شوند':'Files are served by GitHub Releases');
}
function setLanguage(value){
  lang=value==='en'?'en':'fa';document.documentElement.lang=lang;document.documentElement.dir=lang==='fa'?'rtl':'ltr';
  document.querySelectorAll('[data-i18n]').forEach(el=>el.textContent=copy[lang][el.dataset.i18n]||copy.fa[el.dataset.i18n]);
  $('#language').textContent=lang==='fa'?'EN':'فا';$('#language').setAttribute('aria-label',lang==='fa'?'Switch to English':'تغییر زبان به فارسی');
  document.title=lang==='fa'?'Vyrax | اتصال، به سبک تو.':'Vyrax | Your connection. Your choice.';
  renderDownload(true);renderScreenshots();save('vyrax-site-language',lang);
}
$('#language').addEventListener('click',()=>setLanguage(lang==='fa'?'en':'fa'));
document.querySelectorAll('[data-os]').forEach(button=>{
  button.addEventListener('click',()=>{os=button.dataset.os;renderDownload();});
  button.addEventListener('keydown',e=>{if(!['ArrowLeft','ArrowRight','Home','End'].includes(e.key))return;e.preventDefault();const keys=Object.keys(platforms);let i=keys.indexOf(os);i=e.key==='Home'?0:e.key==='End'?keys.length-1:(i+(e.key==='ArrowRight'?1:-1)+keys.length)%keys.length;os=keys[i];renderDownload();$('#tab-'+os).focus();});
});
$('#architecture').addEventListener('change',updateFile);
const ua=navigator.userAgent;if(/Android/i.test(ua))os='android';else if(/Macintosh/i.test(ua))os='macos';else if(/Linux/i.test(ua))os='linux';
setLanguage(saved('vyrax-site-language')||'fa');
function acceptRelease(data){if(data.draft||data.prerelease||!/^v?\d+\.\d+\.\d+$/.test(data.tag_name)||!Array.isArray(data.assets))return;release=data;document.querySelectorAll('.version').forEach(el=>el.textContent=data.tag_name.replace(/^v/,''));updateFile();}
async function getRelease(){
  // Bundled release metadata keeps downloads working when GitHub API is unavailable.
  try{const r=await fetch('release.json');if(r.ok)acceptRelease(await r.json());}catch{}
  try{const r=await fetch('https://api.github.com/repos/AmyraxVPN-Main/Vyrax/releases/latest',{signal:AbortSignal.timeout(7000),headers:{Accept:'application/vnd.github+json'}});if(r.ok)acceptRelease(await r.json());}catch{}
}
getRelease();

// The reference's load reveals, glass header, eased parallax and shooting stars.
const page=document.documentElement;
const motion=window.matchMedia('(prefers-reduced-motion: reduce)');
page.classList.add('js');
requestAnimationFrame(()=>requestAnimationFrame(()=>page.classList.add('loaded')));
let scrollPosition=0,scrollFrame=null;
function updateParallax(){
  const target=Math.min(window.scrollY,window.innerHeight*1.6);
  scrollPosition+=(target-scrollPosition)*.14;
  if(Math.abs(target-scrollPosition)<.1){scrollPosition=target;scrollFrame=null;}
  else scrollFrame=requestAnimationFrame(updateParallax);
  page.style.setProperty('--sy',scrollPosition.toFixed(2));
}
function updateScroll(){
  $('#hd').classList.toggle('scrolled',window.scrollY>8);
  if(!motion.matches&&scrollFrame===null)scrollFrame=requestAnimationFrame(updateParallax);
}
window.addEventListener('scroll',updateScroll,{passive:true});
updateScroll();
motion.addEventListener('change',()=>{
  if(motion.matches){cancelAnimationFrame(scrollFrame);scrollFrame=null;page.style.setProperty('--sy','0');}
  else updateScroll();
});
const revealElements=document.querySelectorAll('.reveal');
if('IntersectionObserver' in window){
  const observer=new IntersectionObserver(entries=>entries.forEach(entry=>{
    if(entry.isIntersecting){entry.target.classList.add('in');observer.unobserve(entry.target);}
  }),{rootMargin:'0px 0px -8% 0px',threshold:.08});
  revealElements.forEach(el=>observer.observe(el));
}else revealElements.forEach(el=>el.classList.add('in'));
function spawnComet(){
  if(document.hidden||motion.matches||window.scrollY>window.innerHeight)return;
  const layer=$('.hero__comets'),right=Math.random()<.5;
  const angle=24+Math.random()*16;
  const comet=document.createElement('span');comet.className='comet';
  comet.style.setProperty('--x0',((right ? .02+Math.random()*.55 : .43+Math.random()*.55)*layer.clientWidth).toFixed(0)+'px');
  comet.style.setProperty('--y0',(Math.random()*layer.clientHeight*.28).toFixed(0)+'px');
  comet.style.setProperty('--ang',(right?angle:180-angle).toFixed(1)+'deg');
  comet.style.setProperty('--dist',(320+Math.random()*460).toFixed(0)+'px');
  comet.style.setProperty('--dur',(550+Math.random()*400).toFixed(0)+'ms');
  layer.append(comet);comet.addEventListener('animationend',()=>comet.remove(),{once:true});
}
(function scheduleComet(){setTimeout(()=>{spawnComet();scheduleComet();},3000+Math.random()*8000);})();
