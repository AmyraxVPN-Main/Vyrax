// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
// Only run on disposable GitHub-hosted macOS runners: changes system networking.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import http from 'node:http';
import { spawn,execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { gzipSync } from 'node:zlib';
const exec=promisify(execFile),pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
assert.equal(process.platform,'darwin');assert.equal(process.env.GITHUB_ACTIONS,'true','Requires a disposable macOS Actions runner');
const arch=process.argv[2],version=JSON.parse(await fs.readFile('package.json','utf8')).version;
const nativeRoot=path.resolve(`macos/build/${arch}/Vyrax.app/Contents/Resources/native`);
const resources=path.dirname(nativeRoot);
const { Backend }=await import(path.join(resources,'app/macos/backend.mjs'));
const { Store }=await import(path.join(resources,'app/linux/store.mjs'));
const { freePort }=await import(path.join(resources,'app/linux/backend.mjs'));
const root=await fs.mkdtemp(path.join(os.tmpdir(),'vyrax-mac-network-'));
const output=path.resolve(`release/macos-${version}`),report={ architecture:arch };
await exec('clang',['-fobjc-arc','macos/tests/network-state.m','-framework','Foundation','-framework','SystemConfiguration','-o',path.join(root,'state')]);
const state=async()=>JSON.parse((await exec(path.join(root,'state'))).stdout);
const before=await state(),port=await freePort();let serverCore,backend;
const fixture=http.createServer((_request,response)=>{response.writeHead(200,{'Content-Encoding':'gzip','Profile-Title':'macOS synthetic subscription'});response.end(gzipSync(Buffer.from('synthetic subscription content')));});
await new Promise(resolve=>fixture.listen(0,'127.0.0.1',resolve));const url=`http://127.0.0.1:${fixture.address().port}/sub`;
const profile={id:'fixture-a',sourceId:'first',name:'macOS synthetic A',protocol:'vless',transport:'tcp',host:'127.0.0.1',port,uuid:'00000000-0000-4000-8000-000000000001',latency:20};
const profiles=[profile,{...profile,id:'fixture-b',name:'macOS synthetic B',latency:25}];
try{
  const file=path.join(root,'server.json');await fs.writeFile(file,JSON.stringify({ log:{loglevel:'warning'},inbounds:[{listen:'127.0.0.1',port,protocol:'vless',settings:{clients:[{id:profile.uuid}],decryption:'none'}}],outbounds:[{protocol:'freedom'}] }));
  serverCore=spawn(path.join(nativeRoot,'cores/xray'),['run','-config',file],{stdio:'ignore'});await pause(600);
  const store=new Store(root);await store.init();
  backend=new Backend({nativeRoot,store,emit:()=>{},tunLauncher:args=>spawn('sudo',['-n',path.join(nativeRoot,'vyrax-network'),...args],{stdio:['pipe','pipe','pipe']})});
  await backend.init();assert.equal((await backend.subscription(url)).title,'macOS synthetic subscription');report.disconnectedSubscription=true;
  const delay=await backend.delay(profile);assert.ok(delay.latency>0&&delay.latency<8000,JSON.stringify(delay));report.urlDelay=delay;
  const raw={preferencesVersion:1,mode:'proxy',mtu:1280,_catalog:profiles,_source:'first',_selection:'fastest'};
  assert.equal((await backend.connect(profile,raw)).status,'connected');report.proxyHTTPSConnection=true;
  assert.notDeepEqual(await state(),before);report.systemProxyApplied=true;
  assert.equal((await backend.subscription(url)).text,'synthetic subscription content');report.connectedSubscription=true;
  const core=backend.core;
  assert.equal((await backend.select(profiles,'fixture-b','manual','first')).profileId,'fixture-b');assert.equal(backend.core,core);
  assert.equal((await backend.select(profiles,'fixture-a','balance','first')).selectionMode,'balance');assert.equal(backend.core,core);report.liveSelectionWithoutCoreRestart=true;
  await backend.disconnect();assert.deepEqual(await state(),before);report.proxyRestored=true;
  assert.equal((await backend.connect(profile,{...raw,mode:'tun',_selection:'manual'})).status,'connected');report.tunHTTPSConnection=true;
  const interfaces=os.networkInterfaces();assert.ok(Object.entries(interfaces).some(([name,values])=>name.startsWith('utun')&&values.some(v=>v.address==='172.28.0.1')));report.nativeUtun=true;
  assert.notDeepEqual(await state(),before);report.tunDNSApplied=true;
  assert.equal((await backend.subscription(url)).text,'synthetic subscription content');report.tunSubscription=true;
  assert.ok((await backend.delay(profile)).latency>0);report.delayDuringTun=true;
  await backend.disconnect();assert.deepEqual(await state(),before);report.tunDNSRestored=true;
  assert.ok(!Object.values(os.networkInterfaces()).flat().some(v=>v.address==='172.28.0.1'));report.utunRemoved=true;
  // Parent death independently restores settings while stdin is still open.
  const owner=spawn(process.execPath,['-e','setInterval(()=>{},1000)'],{stdio:'ignore'});
  const lease=spawn('sudo',['-n',path.join(nativeRoot,'vyrax-network'),'proxy',String(owner.pid),String(process.getuid()),'23450','23451','1280'],{stdio:['pipe','pipe','pipe']});
  lease.stdin.on('error',()=>{});const heartbeat=setInterval(()=>lease.stdin.write('alive\n'),500);
  let leaseText='';lease.stdout.on('data',b=>{leaseText+=b;});
  try{
    for(let i=0;i<100&&!leaseText.includes('VYRAX_NETWORK_READY');i++)await pause(100);
    assert.match(leaseText,/VYRAX_NETWORK_READY/);owner.kill('SIGKILL');
    for(let i=0;i<150&&lease.exitCode===null;i++)await pause(100);
    assert.equal(lease.exitCode,0);assert.deepEqual(await state(),before);report.parentCrashRestoresProxy=true;
  }finally{clearInterval(heartbeat);owner.kill();lease.stdin.end('stop\n');}
  const rejected=await exec(path.join(nativeRoot,'vyrax-authorize'),['tun','2',String(process.getuid()),'23450','0','1280']).then(()=>false,()=>true);
  assert.equal(rejected,true);report.unauthorizedCallerRejected=true;
  // Force-kill the root helper: its independent C lease must stop sing-box.
  const crashed=spawn('sudo',['-n',path.join(nativeRoot,'vyrax-network'),'tun',String(process.pid),String(process.getuid()),'23450','0','1280'],{stdio:['pipe','pipe','pipe']});
  crashed.stdin.on('error',()=>{});let crashText='';crashed.stdout.on('data',b=>{crashText+=b;});
  const crashBeat=setInterval(()=>{if(!crashed.stdin.destroyed)crashed.stdin.write('alive\n');},500);
  try{
    for(let i=0;i<100&&!/VYRAX_NETWORK_PID=\d+/.test(crashText);i++)await pause(100);
    const pid=crashText.match(/VYRAX_NETWORK_PID=(\d+)/)?.[1];assert.ok(pid,'Root helper must become ready');
    await exec('sudo',['-n','/bin/kill','-9',pid]);
    for(let i=0;i<150&&Object.values(os.networkInterfaces()).flat().some(v=>v.address==='172.28.0.1');i++)await pause(100);
    assert.ok(!Object.values(os.networkInterfaces()).flat().some(v=>v.address==='172.28.0.1'));report.rootHelperCrashStopsTunnel=true;
  }finally{clearInterval(crashBeat);crashed.stdin.end('stop\n');}
  // The next authorized lease restores the root-owned DNS rollback journal.
  await backend.startNetwork('proxy',23450,23451,1280);await backend.stopProxy();
  assert.deepEqual(await state(),before);report.crashJournalRecovered=true;
  report.passed=true;console.log(JSON.stringify(report,null,2));
}catch(error){console.error('Mac synthetic network test failed:',error.message);if(backend)console.error(backend.logs.join('\n'));throw error;}
finally{
  await backend?.dispose();serverCore?.kill('SIGTERM');await new Promise(resolve=>fixture.close(resolve));
  await fs.writeFile(path.join(output,`network-verification-${arch}.json`),JSON.stringify(report,null,2));
  assert.deepEqual(await state(),before,'Always restore disposable runner DNS/proxies');await fs.rm(root,{recursive:true,force:true});
}
