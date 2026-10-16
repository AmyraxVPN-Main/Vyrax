// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
// Synthetic CONNECT credentials only, on disposable macOS Actions runners.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { readFileSync, writeFileSync } from 'node:fs';
import http2 from 'node:http2';
import https from 'node:https';
import { createHash } from 'node:crypto';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { spawn, execFile } from 'node:child_process';
import { promisify } from 'node:util';
const exec=promisify(execFile),pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
assert.equal(process.platform,'darwin');
assert.equal(process.env.GITHUB_ACTIONS,'true','Requires a disposable runner');
assert.equal(process.env.RUNNER_ENVIRONMENT,'github-hosted','Never install fixture trust on a self-hosted machine');
const arch=process.argv[2],version=JSON.parse(await fs.readFile('package.json','utf8')).version;
const resources=path.resolve(`macos/build/${arch}/Vyrax.app/Contents/Resources`);
const nativeRoot=path.join(resources,'native');
const {Backend}=await import(path.join(resources,'app/macos/backend.mjs'));
const {Store}=await import(path.join(resources,'app/linux/store.mjs'));
const folder=await fs.mkdtemp(path.join(os.tmpdir(),'vyrax-mac-firefox-'));
const originalHosts=await fs.readFile('/etc/hosts');
let backend,gateway,stall,target,targetTrusted=false;
const previousCA=process.env.CURL_CA_BUNDLE;
const sockets=new Set(),sessions=new Set();
const report={architecture:arch,syntheticCredentialsOnly:true,realAccountRequests:false};
try {
  await exec('openssl',['req','-x509','-newkey','rsa:2048','-nodes','-keyout',path.join(folder,'key.pem'),'-out',path.join(folder,'cert.pem'),'-days','2','-subj','/CN=Vyrax synthetic CONNECT fixture','-addext','subjectAltName=DNS:fixture.m1.fastly-masque.net']);
  const cert=await fs.readFile(path.join(folder,'cert.pem'),'utf8');
  const targetCert=path.join(folder,'target-cert.pem');
  await exec('openssl',['req','-x509','-newkey','rsa:2048','-nodes','-keyout',path.join(folder,'target-key.pem'),'-out',targetCert,'-days','2','-subj','/CN=Vyrax synthetic HTTPS target','-addext','subjectAltName=DNS:www.gstatic.com,DNS:cp.cloudflare.com,DNS:www.google.com,IP:203.0.113.10,IP:1.1.1.1']);
  // Trust only the separate target/DoH certificate in the disposable runner.
  // The edge certificate stays untrusted unless injected into a test config,
  // allowing a meaningful negative test of production certificate validation.
  await exec('sudo',['-n','security','add-trusted-cert','-d','-r','trustRoot','-k','/Library/Keychains/System.keychain',targetCert],{timeout:15000});targetTrusted=true;
  process.env.CURL_CA_BUNDLE=targetCert;
  target=https.createServer({key:await fs.readFile(path.join(folder,'target-key.pem')),cert:await fs.readFile(targetCert)},(request,response)=>{
    if(request.url.startsWith('/dns-query')){
      const chunks=[];request.on('data',chunk=>chunks.push(chunk));request.on('end',()=>{
        const query=request.method==='GET'?Buffer.from(new URL(request.url,'https://fixture').searchParams.get('dns'),'base64url'):Buffer.concat(chunks);
        let at=12;while(query[at]&&at<query.length)at+=query[at]+1;at++;
        const type=query.readUInt16BE(at),question=query.subarray(12,at+4),header=Buffer.from(query.subarray(0,12));
        header.writeUInt16BE(0x8180,2);header.writeUInt16BE(type===1?1:0,6);header.writeUInt16BE(0,8);header.writeUInt16BE(0,10);
        let answer=Buffer.alloc(0);
        if(type===1){answer=Buffer.alloc(16);answer.writeUInt16BE(0xc00c,0);answer.writeUInt16BE(1,2);answer.writeUInt16BE(1,4);answer.writeUInt32BE(60,6);answer.writeUInt16BE(4,10);Buffer.from([203,0,113,10]).copy(answer,12);}
        response.writeHead(200,{'Content-Type':'application/dns-message'});response.end(Buffer.concat([header,question,answer]));
      });return;
    }
    setTimeout(()=>{response.writeHead(204);response.end();},20);
  });
  target.on('connection',socket=>{sockets.add(socket);socket.on('error',()=>{});socket.on('close',()=>sockets.delete(socket));});
  await new Promise(resolve=>target.listen(0,'127.0.0.1',resolve));
  const hosts=path.join(folder,'hosts');
  await fs.writeFile(hosts,Buffer.concat([originalHosts,Buffer.from('\n127.0.0.1 fixture.m1.fastly-masque.net wrong.m2.fastly-masque.net\n')]));
  await exec('sudo',['-n','cp',hosts,'/etc/hosts']);
  const allowed=new Set(['www.gstatic.com:443','cp.cloudflare.com:443','www.google.com:443','1.1.1.1:443','203.0.113.10:443']);
  let forwarded=0;
  gateway=http2.createSecureServer({key:await fs.readFile(path.join(folder,'key.pem')),cert});
  gateway.on('connection',socket=>{sockets.add(socket);socket.on('error',()=>{});socket.on('close',()=>sockets.delete(socket));});
  gateway.on('session',session=>{sessions.add(session);session.on('error',()=>{});session.on('close',()=>sessions.delete(session));});
  gateway.on('stream',(stream,headers)=>{
    stream.on('error',()=>{});
    if(headers[':method']!=='CONNECT'||!allowed.has(headers[':authority'])||headers['proxy-authorization']!=='Bearer synthetic-firefox-only'){
      stream.respond({':status':407});stream.end();return;
    }
    const attach=socket=>{
      sockets.add(socket);socket.on('close',()=>sockets.delete(socket));
      socket.on('error',()=>stream.destroy());stream.on('close',()=>socket.destroy());
      if(stream.destroyed){socket.destroy();return;}
      forwarded++;stream.respond({':status':200});stream.pipe(socket);socket.pipe(stream);
    };
    // Only this owned HTTPS/DoH fixture is reachable, never arbitrary targets.
    // Loopback also keeps the server's upstream leg outside client TUN routing.
    const socket=net.connect(target.address().port,'127.0.0.1');
    sockets.add(socket);socket.on('close',()=>sockets.delete(socket));
    socket.on('error',()=>stream.destroy());socket.once('connect',()=>attach(socket));
  });
  await new Promise(resolve=>gateway.listen(0,'127.0.0.1',resolve));
  stall=net.createServer(socket=>{sockets.add(socket);socket.on('error',()=>{});socket.on('close',()=>sockets.delete(socket));});
  await new Promise(resolve=>stall.listen(0,'127.0.0.1',resolve));
  const store=new Store(path.join(folder,'store'));await store.init();
  backend=new Backend({nativeRoot,store,emit:()=>{},tunLauncher:args=>spawn('sudo',['-n',path.join(nativeRoot,'vyrax-network'),...args],{stdio:['pipe','pipe','pipe']})});
  await backend.init();
  backend.free.resolve=async profiles=>profiles.map(p=>({...p,proxyPass:p.proxyPass||'synthetic-firefox-only'}));
  const originalSpawn=backend.spawnCore.bind(backend);let fixtureTrust=true;
  backend.spawnCore=args=>{
    const file=args.at(-1),config=JSON.parse(readFileSync(file));
    config.log={loglevel:'warning'};
    config.dns.servers=config.dns.servers.map(server=>typeof server==='string'?server:{address:`https://127.0.0.1:${stall.address().port}/dns-query`,timeoutMs:150});
    for(const outbound of config.outbounds){
      const tls=outbound.streamSettings?.tlsSettings;
      if(tls&&fixtureTrust)tls.certificates.push({usage:'verify',certificate:cert.split(/\r?\n/)});
    }
    if(config.observatory)config.observatory.probeInterval='1s';
    writeFileSync(file,JSON.stringify(config));return originalSpawn(args);
  };
  const profile={id:'firefox:fixture-a',sourceId:'vyrax-firefox-free',protocol:'firefox',provider:'firefox',host:'fixture.m1.fastly-masque.net',port:gateway.address().port,transport:'tcp',tls:true};
  const profiles=[profile,{...profile,id:'firefox:fixture-b'}];
  const raw={preferencesVersion:1,mode:'proxy',mtu:1280,_catalog:profiles,_source:profile.sourceId,_selection:'manual'};
  const delay=await backend.delay(profile);assert.ok(delay.latency>0,JSON.stringify(delay));
  report.firefoxURLDelayWithBlockedDoH=delay;
  assert.equal((await backend.connect(profile,raw)).status,'connected');report.firefoxProxy=true;
  const core=backend.core;
  for(const mode of ['fastest','balance','manual']){
    await backend.select(profiles,'firefox:fixture-b',mode,profile.sourceId);assert.equal(backend.core,core);
  }
  await backend.select(profiles,profile.id,'balance',profile.sourceId);
  let healthy=[];
  for(let i=0;i<60;i++){
    const info=JSON.parse(await backend.command('bi',['--json',backend.selection.balancer]));
    healthy=info.balancer?.principleTarget?.tag||[];
    if(healthy.length===2)break;await pause(500);
  }
  assert.equal(healthy.length,2,'Both authenticated Firefox nodes must enter the automatic pool');
  report.firefoxObservatoryPool=healthy.length;report.liveSelectionWithoutCoreRestart=true;
  await backend.disconnect();
  assert.equal((await backend.delay({...profile,proxyPass:'invalid-synthetic-pass'})).latency,null);report.invalidPassRejected=true;
  assert.equal((await backend.delay({...profile,host:'wrong.m2.fastly-masque.net'})).latency,null);report.hostnameMismatchRejected=true;
  fixtureTrust=false;
  assert.equal((await backend.delay(profile)).latency,null);report.untrustedCertificateRejected=true;
  fixtureTrust=true;
  const before=forwarded;
  assert.equal((await backend.connect(profile,{...raw,mode:'tun'})).status,'connected');
  assert.ok(forwarded>before,'TUN verification must reach the synthetic authenticated gateway');
  assert.ok(Object.entries(os.networkInterfaces()).some(([name,values])=>name.startsWith('utun')&&values.some(v=>v.address==='172.28.0.1')));
  report.firefoxTunHTTPS=true;
  assert.ok((await backend.delay(profile)).latency>0);report.firefoxDelayDuringTun=true;
  await backend.disconnect();
  assert.equal((await fs.readdir(backend.runtimeRoot)).length,0);report.credentialsCleaned=true;
  assert.ok(!Object.values(os.networkInterfaces()).flat().some(v=>v.address==='172.28.0.1'));report.utunRemoved=true;
  report.passed=true;console.log(JSON.stringify(report,null,2));
}catch(error){console.error(backend?.logs.join('\n'));throw error;}
finally{
  await backend?.dispose();
  console.log('Firefox assertions finished; backend disposed');
  for(const session of sessions)session.destroy();for(const socket of sockets)socket.destroy();
  const close=async(server,label)=>{
    if(!server)return;let timer;
    try{await Promise.race([new Promise(resolve=>server.close(resolve)),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error(label+' fixture failed to close')),5000);})]);}
    finally{clearTimeout(timer);}
    console.log(label+' fixture closed');
  };
  await close(gateway,'CONNECT');await close(stall,'stalled DoH');await close(target,'HTTPS');
  if(previousCA===undefined)delete process.env.CURL_CA_BUNDLE;else process.env.CURL_CA_BUNDLE=previousCA;
  if(targetTrusted){
    const file=path.join(folder,'target-cert.pem');
    const pem=await fs.readFile(file,'utf8'),der=Buffer.from(pem.replace(/-----[^-]+-----/g,'').replace(/\s/g,''),'base64');
    // macOS 15's remove-trusted-cert opens an interactive authorization session
    // even under sudo. Delete the exact fixture certificate; the isolated
    // hosted VM and its remaining synthetic trust record are discarded when
    // this job ends. No trust changes are made on a user's/self-hosted Mac.
    await exec('sudo',['-n','security','delete-certificate','-Z',createHash('sha1').update(der).digest('hex'),'/Library/Keychains/System.keychain'],{timeout:15000});
    console.log('Synthetic target certificate deleted; ephemeral runner trust expires with this job');
  }
  const original=path.join(folder,'original-hosts');await fs.writeFile(original,originalHosts);await exec('sudo',['-n','cp',original,'/etc/hosts']);
  await fs.writeFile(`release/macos-${version}/firefox-network-verification-${arch}.json`,JSON.stringify(report,null,2));
  await fs.rm(folder,{recursive:true,force:true});
}
