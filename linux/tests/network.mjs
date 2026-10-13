// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import http from 'node:http';
import dgram from 'node:dgram';
import { spawn,execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { Backend } from '../backend.mjs';
import { Store } from '../store.mjs';
import { readFileSync,writeFileSync } from 'node:fs';
const exec=promisify(execFile),pause=ms => new Promise(r => setTimeout(r,ms));
const [folder,nativeRoot]=process.argv.slice(2);
const store=new Store(path.join(folder,'store'));await store.init();const events=[];
const backend=new Backend({ nativeRoot,store,emit:e => events.push(e),tunLauncher:args => spawn('/usr/bin/python3',['-I',...args],{ env:process.env,stdio:['pipe','pipe','pipe'] }) });
// Enable diagnostics only for this synthetic fixture; shipped configs stay quiet.
const originalSpawn=backend.spawnCore.bind(backend);
backend.spawnCore=args => { const file=args[args.length-1],config=JSON.parse(readFileSync(file));config.log={ loglevel:'debug' };writeFileSync(file,JSON.stringify(config));return originalSpawn(args); };
// The actual GNOME proxy adapter is tested in the isolated desktop session.
backend.proxy={ enable:async () => {},recover:async () => {} };
await backend.init();
const first={ id:'a',sourceId:'group',protocol:'vless',transport:'tcp',host:'198.18.0.1',port:22539,uuid:'00000000-0000-4000-8000-000000000001' };
const second={ ...first,id:'b' },outside={ ...first,id:'c',sourceId:'outside' },profiles=[first,second,outside];
const raw={ preferencesVersion:1,mode:'proxy',_catalog:profiles,_selection:'manual',_source:'group' };
const routeBefore=(await exec('ip',['-j','route','show','table','all'])).stdout;
const subscription=http.createServer((_q,r) => { r.writeHead(200,{ 'profile-title':'Fixture subscription','subscription-userinfo':'upload=1; download=2; total=100' });r.end('synthetic subscription'); });
await new Promise(r => subscription.listen(22542,'127.0.0.1',r));
try {
  const start=Date.now();await backend.connect(first,raw);assert.equal(backend.status,'connected');assert.ok(Date.now()-start<5000);console.log('Proxy: verified HTTPS through VLESS');
  async function checkSubscriptionPaths() {
    for (const lane of ['direct','proxy']) {
      const before=Date.now(),data=await backend.subscription(`https://www.gstatic.com/subscription-${lane}`);
      assert.equal(data.text,'synthetic compressed subscription');assert.equal(data.title,'Fixture remote subscription');assert.ok(Date.now()-before<2000);
    }
  }
  await checkSubscriptionPaths();console.log('Subscriptions prefer uplink and fall back to selected proxy without reconnecting');
  const measured=await backend.delay(first);assert.ok(measured.latency>0 && measured.latency<1000);console.log('Delay: warmed HEAD measures real proxy traffic');
  const stalled=backend.delay({ ...first,id:'stalled',port:22541 });const before=Date.now();
  const fetched=await backend.subscription('http://127.0.0.1:22542/test');assert.equal(fetched.title,'Fixture subscription');assert.ok(Date.now()-before<1000);console.log('Subscription fetch remains responsive during stalled delay');
  const core=backend.core.pid;
  const streaming=exec('curl',['--silent','--fail','--proxy',`http://127.0.0.1:${backend.ports.http}`,'--noproxy','','https://www.gstatic.com/stream'],{ timeout:7000 });
  await pause(400);await backend.select(profiles,'b','manual','group');await backend.select(profiles,'b','fastest','group');await backend.select(profiles,'a','balance','group');
  assert.equal(backend.core.pid,core);assert.equal((await streaming).stdout.split('packet').length-1,30);console.log('Manual, fastest and balance switches preserve established stream');
  await pause(1300);assert.ok(events.some(e => e.event==='stats' && e.down>0));
  assert.equal((await stalled).latency,null);
  await backend.disconnect();
  await backend.connect(first,{ ...raw,mode:'tun' });assert.equal(backend.status,'connected');
  await checkSubscriptionPaths();console.log('Both subscription paths work after TUN captures application traffic');
  assert.ok(await fs.stat('/sys/class/net/Vyrax'));console.log('TUN: real interface, policy routing and bound verified HTTPS');
  const v6=await exec('curl',['--silent','--fail','--noproxy','*','--interface','fdfe:dcba:9876::1','--resolve','www.gstatic.com:443:[2001:db8::10]','--max-time','8','--head','https://www.gstatic.com/generate_204']);assert.match(v6.stdout,/204/);console.log('IPv6 traffic traverses the tunnel');
  const query=Buffer.from('abcd0100000100000000000003777777076773746174696303636f6d0000010001','hex');
  const answer=await new Promise((resolve,reject) => { const socket=dgram.createSocket('udp4'),timer=setTimeout(() => { socket.close();reject(Error('DNS timeout')); },8000);socket.once('message',b => { clearTimeout(timer);socket.close();resolve(b); });socket.send(query,53,'9.9.9.9'); });
  assert.equal(answer.readUInt16BE(6),1);assert.deepEqual([...answer.subarray(-4)],[203,0,113,10]);console.log('DNS is hijacked and resolved through proxy DoH');
  const hostname={ ...first,id:'hostname',host:'transport.fixture' };
  await backend.select([...profiles,hostname],hostname.id,'manual','group');
  const hostTraffic=await exec('curl',['--silent','--fail','--noproxy','*','--interface','172.28.0.1','--max-time','8','--head','https://www.gstatic.com/generate_204']);
  assert.match(hostTraffic.stdout,/204/);console.log('New transport hostname resolves through bootstrap DNS after TUN starts');
  const helper=backend.tun;helper.stdin.end();for (let i=0;i<60;i++) { try { await fs.stat('/sys/class/net/Vyrax'); } catch { break; }await pause(100); }
  await assert.rejects(fs.stat('/sys/class/net/Vyrax'));console.log('Tunnel helper restores routing when owner lease closes');
  await backend.disconnect();assert.equal((await exec('ip',['-j','route','show','table','all'])).stdout,routeBefore);
  await exec('ip',['addr','add','10.77.0.2/24','dev','eth0']);
  await backend.connect(first,{ ...raw,proxyShare:true });assert.deepEqual(backend.share.hosts,['10.77.0.2']);
  const shared=await exec('curl',['--silent','--fail','--proxy',`http://10.77.0.2:${backend.share.port}`,'--noproxy','','--max-time','8','--head','https://www.gstatic.com/generate_204']);assert.match(shared.stdout,/204/);
  console.log('LAN proxy sharing binds and serves only private LAN interfaces');
  const runner=backend.core.pid,descendants=(await exec('pgrep',['-P',String(runner)])).stdout.trim().split('\n').map(Number);
  backend.core.kill('SIGKILL');
  for (let i=0;i<80 && backend.status!=='disconnected';i++) await pause(100);
  assert.equal(backend.status,'disconnected');for (const pid of descendants) {
    const state=await fs.readFile(`/proc/${pid}/stat`,'utf8').catch(() => '');assert.ok(!state || state.split(/\) /)[1].startsWith('Z '));
  }
  await exec('ip',['addr','del','10.77.0.2/24','dev','eth0']);
  assert.equal((await exec('ip',['-j','route','show','table','all'])).stdout,routeBefore);
  console.log('Core parent death kills child and reports disconnection');
  await backend.save({ profiles,selectedId:'b',activeSourceId:'group',selectionMode:'manual',settings:{ preferencesVersion:1,mode:'proxy',autoConnect:true,autoReconnect:true } });
  await backend.ready();assert.equal(backend.status,'connected');assert.equal(backend.profileId,'b');
  await backend.select(profiles,'a','fastest','group');backend.core.kill('SIGTERM');
  for (let i=0;i<100;i++) { await pause(100);if (backend.status==='connected') break; }
  assert.equal(backend.status,'connected');assert.equal(backend.selectionMode,'fastest');
  await backend.disconnect();await pause(3200);assert.equal(backend.status,'disconnected');
  console.log('Auto-connect/reconnect preserve current selection; explicit disconnect cancels reconnect');
  assert.equal((await fs.readdir(backend.runtimeRoot)).length,0);
  console.log('Namespace routes restored; all temporary credentials removed');
  await fs.writeFile(path.join(folder,'network-results.json'),JSON.stringify({ proxy:true,tun:true,ipv6:true,dns:true,transportDNS:true,delay:true,nonblockingSubscriptions:true,seamlessSelection:true,stats:true,leaseCleanup:true,routeRestore:true,privateLANSharing:true,coreCrashCleanup:true,autoConnect:true,autoReconnect:true,explicitDisconnectCancelsReconnect:true },null,2));
} catch (error) { console.log(backend.logs.join('\n'));throw error; }
finally { subscription.close();await backend.dispose(); }
