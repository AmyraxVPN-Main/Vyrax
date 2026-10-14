import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { authPassword,hawk,loginFirefox,oauthFirefox,responseJson,parseFreeServers,FREE_SOURCE,freeOutbound } from '../src/lib/free-servers.mjs';
import { FreeProvider } from '../linux/free-provider.mjs';
import { migrateSubscriptions,subscriptionContent } from '../src/lib/subscriptions.mjs';
import { exportProfiles } from '../src/lib/profiles.mjs';
import { outbound as linuxOutbound,xray } from '../linux/config.mjs';

const p={id:'firefox:test.m1.fastly-masque.net:2499',protocol:'firefox',sourceId:FREE_SOURCE,host:'test.m1.fastly-masque.net',port:2499};
const response=(body,status=200,headers={})=>({body:JSON.stringify(body),status,headers});
test('Firefox quickStretch/authPW Unicode vector matches PBKDF2/HKDF reference',async()=>{
  assert.equal(await authPassword(' TEST@Example.com\u200b ','päss-آزمایش'),'852a0f233a2a338e0a26a3a61480e8b9ddb6f0ebde2f0c8155767bd7979aca03');
});
test('Hawk authenticates exact payload and path using reference vector',async()=>{
  assert.equal(await hawk('00'.repeat(32),'verify','{"code":"123456"}',{ts:1700000000,nonce:'nonce123'}),'Hawk id="cb339b3ae38e8ca7ce73414765fcf866ec6fd00faa48932575b407d1836c6e01", ts="1700000000", nonce="nonce123", mac="uGwkJbaK0OVoYPoUHhWHAWqXaLGWHx/G4pgC7CYVYEQ=", hash="Ep9IOeekIfor0O8wOtlEW2ta9aXArsz34Sju2Ketz/I="');
});
test('login fallback is limited to errno 107, and password is never sent',async()=>{
  const seen=[];const request=async args=>{seen.push(args);return seen.length===1?response({errno:107},400):response({sessionToken:'01'.repeat(32),verified:false});};
  const login=await loginFirefox(request,'Example@domain.test','test-password');assert.equal(login.verified,false);assert.equal(seen.length,2);assert.ok(!seen[1].body.includes('test-password'));assert.equal(JSON.parse(seen[1].body).email,'example@domain.test');assert.ok(!JSON.parse(seen[1].body).verificationMethod);
  const tokens=await oauthFirefox(async()=>response({access_token:'synthetic-access',refresh_token:'synthetic-refresh',expires_in:3600}),login);assert.ok(tokens.expiresAt>Date.now()/1000+3500);
});
test('official server list keeps CONNECT candidates, deduplicates and rejects unsafe or locked nodes',()=>{
  const raw={data:[{country:{name:'Germany',code:'DE',cities:[{name:'Berlin',servers:[{hostname:p.host,port:2499},{hostname:p.host,port:2499},{hostname:'bad.example',port:443},{hostname:'quarantine.m1.fastly-masque.net',port:443,quarantined:true},{hostname:'http.m1.fastly-masque.net',port:443,protocols:[{name:'connect',scheme:'http'}]}]}]}},{name:'Locked',locked:true,cities:[{servers:[{hostname:'locked.m1.fastly-masque.net',port:443}]}]}]};
  const list=parseFreeServers(raw,[{...p,favorite:true,latency:52,tested:true}]);assert.equal(list.length,1);assert.equal(list[0].cc,'de');assert.equal(list[0].favorite,true);assert.equal(list[0].latency,52);assert.ok(!JSON.stringify(list).includes('proxyPass'));
});
test('HTTP2 outbound verifies TLS and cannot send a pass to another provider',()=>{
  const profile={...p,proxyPass:'synthetic-pass'};const result=freeOutbound(profile);
  assert.deepEqual(result,linuxOutbound(profile));assert.deepEqual(result.streamSettings.tlsSettings.alpn,['h2']);assert.equal(result.streamSettings.tlsSettings.allowInsecure,false);assert.equal(result.settings.headers['Proxy-Authorization'],'Bearer synthetic-pass');
  assert.throws(()=>freeOutbound({...profile,host:'fastly-masque.net.evil.test'}),/err.freeServer/);assert.throws(()=>freeOutbound(p),/err.freeAuth/);
  const built=xray([profile],p.id,'manual',FREE_SOURCE,{preferencesVersion:1},{socks:1080,http:1081,probe:1082,api:1083,metrics:1084});assert.equal(built.config.outbounds[0].protocol,'http');
});
test('provider subscriptions survive migration and cannot export account credentials',()=>{
  const sub={id:FREE_SOURCE,kind:'firefox',name:'Free servers'};const saved=migrateSubscriptions({profiles:[p],subscriptions:[sub],activeSourceId:FREE_SOURCE});assert.equal(saved.subscriptions[0].kind,'firefox');assert.equal(saved.activeSourceId,FREE_SOURCE);
  assert.throws(()=>subscriptionContent(sub,[p]),/err.freeShare/);assert.throws(()=>exportProfiles([{...p,proxyPass:'secret'}]),/err.freeShare/);
});
test('web protection responses are distinct from account eligibility',()=>{
  for(const body of ['', '<html>challenge</html>', '{"message":"blocked"}'])assert.throws(()=>responseJson({status:406,body}),/err.freeChallenge/);
  assert.throws(()=>responseJson({status:403,body:''}),/err.freeEligibility/);
});

test('login preserves empty or HTML service denials without retrying credentials',async()=>{
  for(const [status,body,error] of [[406,'','err.freeChallenge'],[403,'<html>challenge</html>','err.freeEligibility'],[429,'','err.freeQuota'],[503,'','err.freeService'],[200,'','err.freeService']]){
    let calls=0;
    await assert.rejects(loginFirefox(async()=>{calls++;return {status,body};},'test@example.test','synthetic-password'),new RegExp(error));
    assert.equal(calls,1);
  }
});

test('login never retries an invalid-parameter-shaped denial from web protection',async()=>{
  for(const [status,error] of [[403,'err.freeEligibility'],[406,'err.freeChallenge']]){
    let calls=0;
    await assert.rejects(loginFirefox(async()=>{calls++;return response({errno:107},status);},'test@example.test','synthetic-password'),new RegExp(error));
    assert.equal(calls,1);
  }
});

test('malformed successful responses produce service errors rather than runtime errors',async()=>{
  for(const body of ['', 'null', '[]', 'true', '"text"', '<html>invalid</html>']){
    assert.throws(()=>responseJson({status:200,body}),/err.freeService/);
    await assert.rejects(loginFirefox(async()=>({status:200,body}),'test@example.test','synthetic-password'),/err.freeService/);
  }
});

async function provider(t,handler){const root=await fs.mkdtemp(path.join(os.tmpdir(),'vyrax-free-test-'));t.after(()=>fs.rm(root,{recursive:true,force:true}));const seen=[];const transport=async(url,options)=>{seen.push({url,options});return handler(url,options);};const provider=new FreeProvider({root},transport);await provider.init();return {provider,root,seen};}
const session=(email='a@example.test')=>({email,accessToken:'synthetic-access-'+email,refreshToken:'synthetic-refresh-'+email,expiresAt:Math.floor(Date.now()/1000)+3600});
function service(url){if(url.endsWith('/token'))return new Response(JSON.stringify({token:'synthetic-pass',expires_at:Math.floor(Date.now()/1000)+3600}),{headers:{'x-quota-limit':'53687091200','x-quota-remaining':'21474836480','x-quota-reset':'1800000000'}});return new Response(JSON.stringify({subscribed:true,maxBytes:53687091200}));}
test('concurrent probes share one pass request and encrypted storage excludes plaintext',async t=>{
  const {provider:a,root,seen}=await provider(t,service);await a.save(session());const resolved=await Promise.all([a.resolve([p],FREE_SOURCE),a.resolve([p],FREE_SOURCE),a.resolve([p],FREE_SOURCE)]);assert.equal(seen.length,1);assert.equal(resolved[0][0].proxyPass,'synthetic-pass');assert.ok(!Object.hasOwn(p,'proxyPass'));
  const state=await a.account('local');assert.equal(state.quota.remaining,21474836480);assert.equal(state.quota.limit,53687091200);assert.ok(!JSON.stringify(state).includes('synthetic'));
  assert.ok(!(await fs.readFile(path.join(root,'firefox','store.enc'))).includes(Buffer.from('synthetic-access')));
});
test('switching and deleting accounts resets passes without deleting other accounts',async t=>{
  const {provider:a}=await provider(t,service);await a.save(session());await a.resolve([p],FREE_SOURCE);await a.save(session('b@example.test'));let state=await a.switchAccount('a@example.test');assert.equal(state.accounts.length,2);assert.equal(a.pass,'');await a.resolve([p],FREE_SOURCE);const pass=a.pass;
  state=await a.remove('b@example.test');assert.equal(a.pass,pass);assert.equal(state.activeEmail,'a@example.test');assert.equal(state.accounts.length,1);
  state=await a.remove('a@example.test');assert.equal(state.signedIn,false);assert.equal(state.accounts.length,0);await assert.rejects(a.resolve([p],FREE_SOURCE),/err.freeAuth/);
});
test('refresh credentials rotate and a transient error does not erase an account',async t=>{
  let unavailable=false;const {provider:a}=await provider(t,(url)=>url.endsWith('/oauth/token')?new Response(unavailable?'{}':JSON.stringify({access_token:'rotated-access',refresh_token:'rotated-refresh',expires_in:3600}),{status:unavailable?503:200}):service(url));
  await a.save({...session(),expiresAt:0});await a.resolve([p],FREE_SOURCE);assert.equal(a.session.refreshToken,'rotated-refresh');a.session.expiresAt=0;a.expiry=0;unavailable=true;await assert.rejects(a.resolve([p],FREE_SOURCE),/err.freeService/);assert.equal(a.session.refreshToken,'rotated-refresh');assert.equal((await a.account('local')).signedIn,true);
});

test('Guardian web protection preserves the saved account and does not retry tokens',async t=>{
  const {provider:a,seen}=await provider(t,()=>new Response('',{status:406}));
  await a.save(session());
  await assert.rejects(a.account('status'),/err.freeChallenge/);
  assert.equal(seen.length,1);
  assert.equal((await a.account('local')).signedIn,true);
  assert.equal(a.session.accessToken,session().accessToken);
});
test('fixed HTTP request rejects an arbitrary endpoint and never follows credential redirects',async t=>{
  const {provider:a,seen}=await provider(t,service);await assert.rejects(a.request({endpoint:'https://evil.test/'}),/err.action/);assert.equal(seen.length,0);await a.request({endpoint:'servers'});assert.equal(seen[0].options.redirect,'error');assert.equal(seen[0].options.credentials,'omit');
});
test('queued account removal cannot resurrect a pending pass refresh',async t=>{
  let release;const gate=new Promise(r=>{release=r;});const {provider:a}=await provider(t,async url=>{await gate;return service(url);});await a.save(session());const pending=a.resolve([p],FREE_SOURCE);const removed=a.remove('a@example.test');release();await pending;await removed;assert.equal(a.pass,'');assert.equal((await a.account('local')).signedIn,false);
});
test('a missing quota-limit header retains the account status limit',async t=>{
  const {provider:a}=await provider(t,url=>url.endsWith('/token')?new Response(JSON.stringify({token:'synthetic-pass',expires_at:2000000000}),{headers:{'x-quota-remaining':'21474836480'}}):new Response(JSON.stringify({subscribed:true,maxBytes:53687091200})));
  await a.save(session());const state=await a.account('status');assert.equal(state.quota.limit,53687091200);assert.equal(state.quota.remaining,21474836480);
});
test('a corrupt free-account vault does not block personal subscriptions',async t=>{
  const {provider:a,root}=await provider(t,service);await a.save(session());await fs.writeFile(path.join(root,'firefox','store.enc'),Buffer.from('corrupt'));
  const restored=new FreeProvider({root},service);await restored.init();await assert.rejects(restored.account('local'),/err.freeStorage/);
  const personal={id:'personal',protocol:'vless',sourceId:'personal'};assert.deepEqual(await restored.resolve([personal],'personal'),[personal]);
  await restored.save(session());assert.equal((await restored.account('local')).signedIn,true);
});
