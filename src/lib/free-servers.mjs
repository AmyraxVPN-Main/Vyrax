// SPDX-License-Identifier: MIT
// Firefox Accounts / Guardian protocol adapted from FoxyVPN, © 2026 Vauth.
export const FREE_SOURCE = 'vyrax-firefox-free';
export const CLIENT_ID = '5882386c6d801776';
export const SCOPE = 'profile https://identity.mozilla.com/apps/vpn';
export const ENDPOINTS = Object.freeze({
  login:['POST','https://api.accounts.firefox.com/v1/account/login'],
  verify:['POST','https://api.accounts.firefox.com/v1/session/verify_code'],
  oauth:['POST','https://api.accounts.firefox.com/v1/oauth/token'],
  servers:['GET','https://firefox.settings.services.mozilla.com/v1/buckets/main/collections/vpn-serverlist/records'],
  status:['GET','https://vpn.mozilla.org/api/v1/fpn/status'],
  activate:['POST','https://vpn.mozilla.org/api/v1/fpn/activate'],
  token:['GET','https://vpn.mozilla.org/api/v1/fpn/token']
});
const encoder = new TextEncoder();
const bytes = text => encoder.encode(text);
const hex = value => [...new Uint8Array(value)].map(b=>b.toString(16).padStart(2,'0')).join('');
const base64 = value => btoa(String.fromCharCode(...new Uint8Array(value)));
export const normalizeEmail = value => String(value || '').replace(/[\s\u200b-\u200d\ufeff]/g,'').toLowerCase();
export const validEdge = host => typeof host === 'string' && /^[a-z0-9]+(?:[.-][a-z0-9]+)*\.fastly-masque\.net$/i.test(host) && host.length <= 253;
export function validateFreeProfile(p) {
  if (p.protocol !== 'firefox' || p.sourceId !== FREE_SOURCE || !validEdge(p.host) || !Number.isInteger(p.port) || p.port < 1 || p.port > 65535) throw Error('err.freeServer');
}
export function freeOutbound(p) {
  validateFreeProfile(p);
  if (typeof p.proxyPass !== 'string' || !p.proxyPass || p.proxyPass.length > 16384 || /[\s\x00-\x1f\x7f]/.test(p.proxyPass)) throw Error('err.freeAuth');
  return { tag:'proxy',protocol:'http',settings:{ servers:[{address:p.host,port:p.port}],headers:{'Proxy-Authorization':'Bearer '+p.proxyPass}},streamSettings:{network:'tcp',security:'tls',tlsSettings:{serverName:p.host,allowInsecure:false,alpn:['h2']},sockopt:{domainStrategy:'ForceIPv4v6'}} };
}
export function parseFreeServers(raw, previous = []) {
  if (!Array.isArray(raw?.data)) throw Error('err.freeService');
  const result = new Map(), saved = new Map(previous.map(p => [p.id, p]));
  for (const record of raw.data) {
    const country = record?.country || record;
    if (!country || typeof country.code !== 'string' || !country.code.trim() || /^CatchAll Anycast$/i.test(country.name || '')) continue;
    // Foxy lists all public locations, including Remote Settings' `locked`
    // entries. That flag is metadata; the provider still authorizes every pass.
    const countryCode = country.code.trim().toUpperCase(), recommended = countryCode === 'REC';
    for (const city of Array.isArray(country.cities) ? country.cities : []) for (const server of Array.isArray(city?.servers) ? city.servers : []) {
      if (!server || server.quarantined) continue;
      const protocols = Array.isArray(server.protocols) ? server.protocols : [];
      const protocol = protocols.find(p => p?.name === 'connect' && (!p.scheme || p.scheme === 'https'));
      if (protocols.length && !protocol) continue;
      const host = String(protocol?.host || server.hostname || '').toLowerCase(), port = protocol?.port || server.port;
      if (!validEdge(host) || !Number.isInteger(port) || port < 1 || port > 65535) continue;
      const id = `firefox:${host}:${port}`, old = saved.get(id);
      const cc = /^[A-Z]{2}$/.test(countryCode) ? countryCode.toLowerCase() : null;
      const countryName = String(country.name || countryCode), cityCode = String(city.code || '');
      const cityName = city.name && city.name !== country.name ? String(city.name) : cityCode !== countryCode ? cityCode : '';
      result.set(id,{id,sourceId:FREE_SOURCE,protocol:'firefox',provider:'firefox',host,port,transport:'tcp',tls:true,
        name:(recommended ? 'Recommended' : [countryName,cityName].filter(Boolean).join(' · ')).slice(0,120),
        countryCode,cityCode,recommended,providerLocked:country.locked === true || record.locked === true,
        cc, favorite:!!old?.favorite,latency:old?.latency ?? null,tested:!!old?.tested});
      if (result.size > 256) throw Error('err.tooBig');
    }
  }
  if (!result.size) throw Error('err.freeNoServers');
  return [...result.values()].sort((a,b) => Number(b.recommended) - Number(a.recommended) || a.name.localeCompare(b.name,'en'));
}
function responseData(response) {
  try {
    const data = JSON.parse(response.body);
    return data && typeof data === 'object' && !Array.isArray(data) ? data : null;
  } catch { return null; }
}
export function responseJson(response) {
  const parsed = responseData(response), data = parsed || {};
  if (response.status >= 200 && response.status < 300) {
    if (!parsed) throw Error('err.freeService');
    return data;
  }
  if (response.status === 406) throw Error('err.freeChallenge');
  if (data.errno === 103) throw Error('err.freeCredentials');
  if (data.errno === 102) throw Error('err.freeAccountMissing');
  if (data.errno === 105 || data.errno === 104) throw Error('err.freeCode');
  if (response.status === 429) throw Error('err.freeQuota');
  if (response.status === 403) throw Error('err.freeEligibility');
  if (response.status === 401) throw Error('err.freeAuth');
  throw Error('err.freeService');
}
async function hkdf(input, info, length) {
  const key = await crypto.subtle.importKey('raw', input, 'HKDF',false,['deriveBits']);
  return crypto.subtle.deriveBits({name:'HKDF',hash:'SHA-256',salt:new Uint8Array(32),info:bytes('identity.mozilla.com/picl/v1/'+info)},key,length*8);
}
export async function authPassword(email, password) {
  const key = await crypto.subtle.importKey('raw', bytes(password),'PBKDF2',false,['deriveBits']);
  const stretched = await crypto.subtle.deriveBits({name:'PBKDF2',hash:'SHA-256',iterations:1000,salt:bytes('identity.mozilla.com/picl/v1/quickStretch:'+normalizeEmail(email))},key,256);
  return hex(await hkdf(stretched,'authPW',32));
}
export async function hawk(sessionToken, endpoint, body, {ts = Math.floor(Date.now()/1000),nonce = base64(crypto.getRandomValues(new Uint8Array(6))).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'')} = {}) {
  if (!/^[a-f0-9]{64,256}$/i.test(sessionToken) || sessionToken.length % 2) throw Error('err.freeAuth');
  const material = new Uint8Array(await hkdf(Uint8Array.from(sessionToken.match(/../g),b=>parseInt(b,16)),'sessionToken',64));
  const payload = base64(await crypto.subtle.digest('SHA-256',bytes('hawk.1.payload\napplication/json\n'+body+'\n')));
  const [method,address] = ENDPOINTS[endpoint] || [];if (!method || !['verify','oauth'].includes(endpoint)) throw Error('err.action');
  const url = new URL(address), normalized = `hawk.1.header\n${ts}\n${nonce}\n${method}\n${url.pathname}\n${url.hostname}\n443\n${payload}\n\n`;
  const key = await crypto.subtle.importKey('raw',material.slice(32),{name:'HMAC',hash:'SHA-256'},false,['sign']);
  const mac = base64(await crypto.subtle.sign('HMAC',key,bytes(normalized)));
  return `Hawk id="${hex(material.slice(0,32))}", ts="${ts}", nonce="${nonce}", mac="${mac}", hash="${payload}"`;
}
export async function loginFirefox(request, email, password, derive = authPassword) {
  email = normalizeEmail(email);
  if (!/^[^@]+@[^@]+\.[^@]+$/.test(email) || email.length > 254 || !password || password.length > 4096) throw Error('err.freeCredentials');
  const authPW = await derive(email,password);
  let response = await request({endpoint:'login',body:JSON.stringify({email,authPW,verificationMethod:'email-2fa'})});
  if (response.status === 400 && responseData(response)?.errno === 107) response = await request({endpoint:'login',body:JSON.stringify({email,authPW})});
  const data = responseJson(response);
  if (!data.sessionToken) throw Error('err.freeAuth');
  return {email,sessionToken:data.sessionToken,verified:data.verified === true};
}
export async function verifyFirefox(request, session, code, sign = hawk) {
  const body = JSON.stringify({code:String(code || '').trim()});
  responseJson(await request({endpoint:'verify',body,authorization:await sign(session.sessionToken,'verify',body)}));
  return {...session,verified:true};
}
export async function oauthFirefox(request, session, sign = hawk) {
  const body = JSON.stringify({client_id:CLIENT_ID,grant_type:'fxa-credentials',scope:SCOPE,access_type:'offline'});
  const data = responseJson(await request({endpoint:'oauth',body,authorization:await sign(session.sessionToken,'oauth',body)}));
  if (!data.access_token || !data.refresh_token) throw Error('err.freeAuth');
  return {email:session.email,accessToken:data.access_token,refreshToken:data.refresh_token,expiresAt:Math.floor(Date.now()/1000)+Math.max(60,Number(data.expires_in)||86400)};
}
export function tokenExpiry(token, now = Math.floor(Date.now()/1000)) {
  try { const part = token.split('.')[1].replace(/-/g,'+').replace(/_/g,'/');const exp = JSON.parse(atob(part)).exp;if (Number.isSafeInteger(exp) && exp > now) return exp; } catch { /* Opaque passes have a short conservative cache. */ }
  return now + 300;
}
