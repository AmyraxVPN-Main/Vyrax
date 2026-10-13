// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import net from 'node:net';
import dgram from 'node:dgram';
import dns from 'node:dns/promises';
import { spawn, execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { performance } from 'node:perf_hooks';
import { fileURLToPath } from 'node:url';
import { catalog, preferences, routing, nodeTag, xray, PROBE_URL } from './config.mjs';
import { DesktopProxy } from './desktop-proxy.mjs';
import { subscriptionThroughCore } from './subscriptions.mjs';
const exec = promisify(execFile);
const pause = ms => new Promise(resolve => setTimeout(resolve,ms));
const issuedPorts=new Map();
export function privateHosts(interfaces=os.networkInterfaces()) {
  return [...new Set(Object.entries(interfaces).filter(([name]) => name!=='Vyrax').flatMap(([,values]) => values || []).filter(v => v.family==='IPv4'&&!v.internal&&/^(?:10\.|192\.168\.|172\.(?:1[6-9]|2\d|3[01])\.)/.test(v.address)).map(v => v.address))];
}
export async function freePort() {
  for (const [port,until] of issuedPorts) if (until<Date.now()) issuedPorts.delete(port);
  for (let attempt=0;attempt<64;attempt++) {
    const server=net.createServer(),udp=dgram.createSocket('udp4');
    await new Promise((resolve,reject) => { server.once('error',reject);server.listen(0,'127.0.0.1',resolve); });
    const port=server.address().port;
    try {
      if (issuedPorts.has(port)) continue;
      await new Promise((resolve,reject) => { udp.once('error',reject);udp.bind(port,'127.0.0.1',resolve); });
      issuedPorts.set(port,Date.now()+60000);return port;
    } catch { /* TCP availability alone does not prove the UDP port is free. */ }
    finally { await new Promise(resolve => server.close(resolve));try { udp.close(); } catch { /* Not bound. */ } }
  }
  throw Error('err.portBusy');
}
async function waitPort(child,port,signal) {
  for (let i=0;i<70;i++) {
    signal?.throwIfAborted();if (child.exitCode !== null) throw Error('err.coreFailed');
    if (await new Promise(resolve => { const socket = net.connect(port,'127.0.0.1');socket.setTimeout(100);socket.once('connect',() => { socket.destroy();resolve(true); });socket.once('error',() => resolve(false));socket.once('timeout',() => { socket.destroy();resolve(false); }); })) return;
    await pause(70);
  }
  throw Error('err.portBusy');
}
export async function probe(port,{ signal, url = PROBE_URL, localAddress } = {}) {
  const base = ['--silent','--show-error','--fail','--head','--connect-timeout','4','--max-time','8'];
  if (localAddress) base.push('--interface',localAddress,'--noproxy','*');
  else base.push('--proxy',`http://127.0.0.1:${port}`,'--noproxy','');
  // libcurl reuses the live tunnel for the warm measurement. The outer budget
  // covers core startup and both requests; unreachable nodes never show "0 ms".
  const { stdout } = await exec('curl',[...base,'--output','/dev/null','--write-out','%{time_starttransfer}\n',url,'--output','/dev/null',url],{ signal, timeout:8000,maxBuffer:8192 });
  const times = stdout.trim().split('\n').map(Number);const measured = times[times.length-1];
  if (!Number.isFinite(measured) || measured <= 0) throw Error('err.noInternet');
  return Math.max(1,Math.round(measured*1000));
}
export async function verify(port,{ signal,localAddress } = {}) {
  const controller=new AbortController(),abort=() => controller.abort();signal?.addEventListener('abort',abort,{ once:true });
  if (signal?.aborted) controller.abort();
  const requests=[PROBE_URL,'https://cp.cloudflare.com/generate_204','https://www.google.com/generate_204'].map(url => probe(port,{ signal:controller.signal,localAddress,url }));
  try { await Promise.any(requests); }
  catch { throw Error(signal?.aborted ? 'err.timeout' : 'err.noInternet'); }
  finally { controller.abort();await Promise.allSettled(requests);signal?.removeEventListener('abort',abort); }
}
export async function fetchText(transport,url,{ timeout=20000,limit=4*1024*1024,headers={} } = {}) {
  const parsed = new URL(url);if (!['http:','https:'].includes(parsed.protocol) || parsed.username || parsed.password) throw Error('err.subFailed');
  const controller = new AbortController(), timer = setTimeout(() => controller.abort(),timeout);
  try {
    const response = await transport(parsed.href,{ signal:controller.signal,headers,credentials:'omit' });
    if (response.status === 404 && limit === 262144) return { response,text:'' };
    if (!response.ok || +(response.headers.get('content-length') || 0) > limit) throw Error('err.subFailed');
    let size=0;const chunks=[];
    for await (const chunk of response.body) { size+=chunk.length;if (size>limit) { controller.abort();throw Error('err.tooBig'); }chunks.push(Buffer.from(chunk)); }
    return { response,text:Buffer.concat(chunks).toString() };
  } finally { clearTimeout(timer); }
}
export class Backend {
  constructor({ nativeRoot, store, emit, transport=fetch, tunLauncher }) {
    Object.assign(this,{ nativeRoot,store,emit,transport,tunLauncher });this.proxy=new DesktopProxy(store.root);
    this.queue=Promise.resolve();this.generation=0;this.status='disconnected';this.probes=new Set();this.delayQueue=[];this.delayActive=0;
    this.settings=preferences({ preferencesVersion:1 });this.profileId='';this.activeTargets=[];this.selectionMode='manual';this.logs=[];
  }
  snapshot() { return { status:this.status,profileId:this.profileId,selectionMode:this.selectionMode,since:this.since || null,elevated:true,exit:this.exit || null,activeTargets:this.activeTargets,share:this.share || null }; }
  state(stage='',message='',switched=false) { this.emit({ event:'state',...this.snapshot(),stage,message,switched }); }
  serial(fn) { const job=this.queue.then(fn);this.queue=job.catch(() => {});return job; }
  log(text) { this.logs.push(text);if (this.logs.length>150) this.logs.splice(0,this.logs.length-150); }
  async init() {
    await this.proxy.recover();this.saved=await this.store.load();this.settings=preferences(this.saved.settings);
    const dir=path.join(this.store.root,'runtime');await fs.mkdir(dir,{ recursive:true,mode:0o700 });this.runtimeRoot=dir;
    // Remove private configs left by an interrupted previous instance.
    for (const item of await fs.readdir(dir)) if (item.startsWith('session-') || item.startsWith('delay-')) await fs.rm(path.join(dir,item),{ recursive:true,force:true });
  }
  async save(data) { await this.store.save(data);this.saved=structuredClone(data);this.settings=preferences(data.settings);return true; }
  async ready() {
    if (this.settings.autoConnect) { const saved=this.saved, p=saved.profiles?.find(p => p.id===saved.selectedId) || saved.profiles?.[0];if (p) return this.connect(p,{ ...this.settings,_catalog:saved.profiles,_source:saved.activeSourceId || '',_selection:saved.selectionMode || 'manual' }); }
    return this.snapshot();
  }
  spawnCore(args) {
    const child=spawn('/usr/bin/python3',[path.join(this.nativeRoot,'core-runner.py'),String(process.pid),path.join(this.nativeRoot,'cores','xray'),...args],{ stdio:['ignore','pipe','pipe'] });
    child.on('error',() => this.log('Core could not start'));
    for (const stream of [child.stdout,child.stderr]) stream.on('data',b => this.log(b.toString().slice(0,4096)));
    return child;
  }
  async stopChild(child,isTun=false) {
    if (!child || child.exitCode!==null) return;
    child.stdin?.write('stop\n');child.stdin?.end();
    if (isTun) { await Promise.race([new Promise(resolve => child.once('exit',resolve)),pause(9500)]);return; }
    child.kill('SIGTERM');await Promise.race([new Promise(resolve => child.once('exit',resolve)),pause(1500)]);
    if (child.exitCode===null) child.kill('SIGKILL');
  }
  async stop() {
    clearInterval(this.heartbeat);clearInterval(this.sampleTimer);clearInterval(this.healthTimer);clearTimeout(this.reconnectTimer);
    const tun=this.tun, core=this.core;this.tun=null;this.core=null;
    await this.stopChild(tun,true);
    let restoreError;
    try { await this.proxy.recover();this.proxyLease?.kill();this.proxyLease=null; } catch (e) { restoreError=e; }
    finally { await this.stopChild(core); }
    if (this.folder) await fs.rm(this.folder,{ recursive:true,force:true });this.folder=null;
    this.share=null;this.since=null;this.status='disconnected';this.activeTargets=[];
    if (restoreError) throw Error('err.proxyRestore');
  }
  disconnect() { this.generation++;this.abort?.abort();return this.serial(async () => { await this.stop();this.state();return this.snapshot(); }); }
  connect(profile,raw) {
    const settings=preferences(raw), profiles=catalog(raw._catalog || [profile]);
    const generation=++this.generation;this.abort?.abort();const controller=new AbortController();this.abort=controller;
    return this.serial(async () => {
      await this.stop();controller.signal.throwIfAborted();this.status='connecting';this.logs=[];this.profileId=profile.id;this.state('stage.start');
      const deadline=setTimeout(() => controller.abort(),180000);
      try {
        this.folder=await fs.mkdtemp(path.join(this.runtimeRoot,'session-'));await fs.chmod(this.folder,0o700);
        const used=new Set(),ports={};for (const key of ['socks','http','probe','subscription','api','metrics',...(settings.proxyShare ? ['share'] : [])]) { let port;do { port=await freePort(); } while (used.has(port));used.add(port);ports[key]=port; }
        if (ports.share) { ports.shareHosts=privateHosts();if (!ports.shareHosts.length) throw Error('err.shareNetwork'); }
        const built=xray(profiles,profile.id,raw._selection || 'manual',raw._source || profile.sourceId || '',settings,ports);
        this.ports=ports;this.routeSettings=settings;this.profiles=profiles;this.installed=new Set(profiles.map(nodeTag));this.revision=0;this.selection=built.selection;
        this.profileId=built.selection.selected.id;this.selectionMode=raw._selection || 'manual';this.source=raw._source || profile.sourceId || '';
        this.lastConnection={ profile:built.selection.selected,raw:{ ...settings,_catalog:profiles,_selection:this.selectionMode,_source:this.source } };
        const file=path.join(this.folder,'xray.json');await fs.writeFile(file,JSON.stringify(built.config),{ mode:0o600 });
        await exec(path.join(this.nativeRoot,'cores','xray'),['run','-test','-config',file],{ timeout:8000,signal:controller.signal,maxBuffer:32768 });
        this.state('stage.core');const core=this.spawnCore(['run','-config',file]);this.core=core;
        await waitPort(core,ports.probe,controller.signal);this.state('stage.verify');await verify(ports.probe,{ signal:controller.signal });
        if (settings.mode==='tun') { this.state('stage.admin');await this.startTun(ports.socks,settings.mtu,controller.signal);this.state('stage.tunnel');await verify(0,{ signal:controller.signal,localAddress:'172.28.0.1' }); }
        else {
          this.state('stage.proxy');await this.proxy.enable(ports.http,ports.socks);
          this.proxyLease=this.startProxyLease();
          this.proxyLease?.on('error',() => {});
        }
        controller.signal.throwIfAborted();this.status='connected';this.since=new Date().toISOString();this.activeTargets=[this.profileId];this.exit=net.isIP(built.selection.selected.host) ? built.selection.selected.host : '';
        if (ports.share) this.share={ port:ports.share,hosts:ports.shareHosts };
        this.lastUp=0;this.lastDown=0;this.lastSample=performance.now();this.state();
        void dns.lookup(built.selection.selected.host).then(({ address }) => { if (this.core===core && this.status==='connected') { this.exit=address;this.state('','',true); } }).catch(() => {});
        const failed=() => { if (this.core===core && this.status==='connected') void this.failure(generation,profile,raw); };
        core.once('exit',failed);this.tun?.once('exit',failed);
        this.sampleTimer=setInterval(() => { void this.sample(); },1000);
        let unhealthy=0,checking=false;
        this.healthTimer=setInterval(() => {
          if (checking || this.core!==core || this.status!=='connected') return;checking=true;
          void verify(ports.probe).then(() => { unhealthy=0; },() => { if (++unhealthy>=3) failed(); }).finally(() => { checking=false; });
        },30000);
        return this.snapshot();
      } catch (error) {
        await fs.writeFile(path.join(this.store.root,'last-tunnel.log'),this.logs.join('\n').slice(-32768),{ mode:0o600 }).catch(() => {});
        await this.stop();this.state();
        if (generation!==this.generation) return this.snapshot();
        if (error.message?.startsWith('err.')) throw error;
        throw Error(controller.signal.aborted ? 'err.timeout' : 'err.coreFailed');
      } finally { clearTimeout(deadline); }
    });
  }
  async failure(generation,profile,raw) {
    const desired=this.lastConnection || { profile,raw };
    await this.serial(async () => { if (generation===this.generation) { await this.stop();this.state('','err.coreFailed'); } });
    if (generation===this.generation && this.settings.autoReconnect) this.reconnectTimer=setTimeout(() => { if (generation===this.generation && this.settings.autoReconnect) void this.connect(desired.profile,{ ...desired.raw,...this.settings }).catch(e => this.state('',e.message)); },3000);
  }
  async startTun(port,mtu,signal) {
    const file=path.join(this.nativeRoot,'tun-helper.py'), args=[file,'--parent',String(process.pid),'--port',String(port),'--mtu',String(mtu)];
    const child=this.tunLauncher ? this.tunLauncher(args) : spawn('pkexec',[path.join(this.nativeRoot,'vyrax-tun'),...args.slice(1)],{ stdio:['pipe','pipe','pipe'] });this.tun=child;
    child.stdin.on('error',() => {});
    const beat=() => { if (!child.stdin.destroyed) child.stdin.write('alive\n'); };beat();this.heartbeat=setInterval(beat,1000);
    await new Promise((resolve,reject) => {
      let text='';const abort=() => reject(Error('err.timeout'));signal.addEventListener('abort',abort,{ once:true });
      const done=fn => value => { signal.removeEventListener('abort',abort);fn(value); };
      child.stdout.on('data',b => { text=(text+b.toString()).slice(-8192);if (text.includes('VYRAX_TUN_READY')) done(resolve)(); });
      child.stderr.on('data',b => this.log(b.toString().slice(0,4096)));
      child.once('exit',code => done(reject)(Error(code===126||code===127 ? 'err.adminDeclined' : 'err.tunnelFailed')));
      child.once('error',() => done(reject)(Error('err.adminDeclined')));
    });
  }
  startProxyLease() {
    return spawn(process.execPath,[path.join(path.dirname(fileURLToPath(import.meta.url)),'proxy-lease.mjs'),String(process.pid),this.store.root],{ env:{ ...process.env,ELECTRON_RUN_AS_NODE:'1' },stdio:'ignore' });
  }
  async command(verb,args=[]) { const { stdout }=await exec(path.join(this.nativeRoot,'cores','xray'),['api',verb,`--server=127.0.0.1:${this.ports.api}`,'--timeout=3',...args],{ timeout:5000,maxBuffer:262144 });return stdout; }
  select(profiles,selectedId,mode,source) {
    catalog(profiles);
    return this.serial(async () => {
      if (this.status!=='connected') return this.snapshot();
      const next=routing(profiles,selectedId,mode,source,this.routeSettings,++this.revision);
      const additions=profiles.filter(p => !this.installed.has(nodeTag(p)));if (this.installed.size+additions.length>2048) throw Error('err.poolFull');
      if (additions.length) { const file=path.join(this.folder,'outbounds.json');await fs.writeFile(file,JSON.stringify({ outbounds:additions.map(p => ({ ...xray([p],p.id,'manual',p.sourceId || '',this.routeSettings,this.ports).config.outbounds[0],tag:nodeTag(p) })) }),{ mode:0o600 });await this.command('ado',[file]);additions.forEach(p => this.installed.add(nodeTag(p))); }
      const file=path.join(this.folder,'routes.json');await fs.writeFile(file,JSON.stringify({ routing:next.config }),{ mode:0o600 });await this.command('adrules',[file]);
      this.profiles=profiles;this.selection=next;this.profileId=next.selected.id;this.source=source;this.selectionMode=mode;this.activeTargets=[this.profileId];this.exit=net.isIP(next.selected.host) ? next.selected.host : '';
      this.lastConnection={ profile:next.selected,raw:{ ...this.routeSettings,_catalog:profiles,_selection:mode,_source:source } };
      this.state('','',true);return this.snapshot();
    });
  }
  async sample() {
    if (this.sampling || this.status!=='connected') return;this.sampling=true;const core=this.core;
    try {
      const data=await (await fetch(`http://127.0.0.1:${this.ports.metrics}/debug/vars`,{ signal:AbortSignal.timeout(2000) })).json();
      if (this.core!==core || this.status!=='connected') return;
      let up=0,down=0;for (const [tag,v] of Object.entries(data.stats?.outbound || {})) if (tag.startsWith('node-')) { up+=Number(v.uplink || 0);down+=Number(v.downlink || 0); }
      const seconds=(performance.now()-this.lastSample)/1000;this.emit({ event:'stats',up,down,upRate:Math.max(0,(up-this.lastUp)/seconds),downRate:Math.max(0,(down-this.lastDown)/seconds) });this.lastUp=up;this.lastDown=down;this.lastSample=performance.now();
      if (this.selectionMode!=='manual' && this.revision===this.sampledRevision && Date.now()-(this.targetAt || 0)>4000) {
        this.targetAt=Date.now();const revision=this.revision;const data=JSON.parse(await this.command('bi',['--json',this.selection.balancer]));
        if (this.core!==core || this.revision!==revision) return;
        const tags=data.balancer?.principleTarget?.tag || [];const targets=this.profiles.filter(p => tags.includes(nodeTag(p))).map(p => p.id);
        if (targets.length && JSON.stringify(targets)!==JSON.stringify(this.activeTargets)) { this.activeTargets=targets;this.profileId=targets[0];this.state('','',true); }
      }
      this.sampledRevision=this.revision;
    } catch { /* Transient metrics failures must not disconnect healthy flows. */ } finally { this.sampling=false; }
  }
  delay(profile) {
    catalog([profile]);return new Promise((resolve,reject) => { this.delayQueue.push({ profile,resolve,reject });this.drainDelays(); });
  }
  drainDelays() {
    while (this.delayActive<4 && this.delayQueue.length) { const job=this.delayQueue.shift();this.delayActive++;void this.realDelay(job.profile).then(job.resolve,job.reject).finally(() => { this.delayActive--;this.drainDelays(); }); }
  }
  async realDelay(profile) {
    const controller=new AbortController();this.probes.add(controller);const timer=setTimeout(() => controller.abort(),8000);let folder,child;
    try {
      folder=await fs.mkdtemp(path.join(this.runtimeRoot,'delay-'));const ports={};for (const key of ['socks','http','probe','api','metrics']) ports[key]=await freePort();
      const built=xray([profile],profile.id,'manual',profile.sourceId || '',{ preferencesVersion:1,mode:'proxy' },ports);
      delete built.config.observatory;delete built.config.routing.balancers;delete built.config.api;
      const file=path.join(folder,'xray.json');await fs.writeFile(file,JSON.stringify(built.config),{ mode:0o600 });
      child=this.spawnCore(['run','-config',file]);await waitPort(child,ports.probe,controller.signal);
      return { latency:await probe(ports.probe,{ signal:controller.signal }),method:'urltest' };
    } catch { return { latency:null,method:'urltest' }; }
    finally { clearTimeout(timer);this.probes.delete(controller);await this.stopChild(child);if (folder) await fs.rm(folder,{ recursive:true,force:true }); }
  }
  async subscription(url) {
    try {
      if (this.status==='connected') {
        try { return await subscriptionThroughCore(url,this.ports.subscription,4); }
        catch (e) { if (['err.tooBig','err.subUrl'].includes(e.message)) throw e;return await subscriptionThroughCore(url,this.ports.probe,12); }
      }
      const { response,text }=await fetchText(this.transport,url,{ headers:{ 'User-Agent':`Vyrax (${process.platform==='darwin'?'macOS':'Linux'}; v2ray)`,'Accept':'*/*' } });
      return { text,title:response.headers.get('profile-title'),userInfo:response.headers.get('subscription-userinfo'),disposition:response.headers.get('content-disposition') };
    } catch (e) { throw Error(['err.tooBig','err.subUrl'].includes(e.message) ? e.message : 'err.subFailed'); }
  }
  async geo(hosts) {
    if (!Array.isArray(hosts) || hosts.length>512) throw Error('err.tooBig');
    if (!this.geoTable) { const b=await fs.readFile(path.join(this.nativeRoot,'geo.bin'));const countries=b.readUInt16LE(0);this.geoTable={ b,countries,offset:2+countries*2+4,count:b.readUInt32LE(2+countries*2) }; }
    const result={},queue=[...hosts];await Promise.all(Array.from({ length:Math.min(8,queue.length) },async () => {
      while (queue.length) { const host=queue.shift();if (typeof host!=='string' || host.length>253) continue;
        try { const address=net.isIP(host) ? host : await Promise.race([dns.lookup(host,{ family:4 }).then(v => v.address),pause(3000).then(() => '')]);
          if (net.isIP(address)!==4) { result[host]=null;continue; }
          const ip=address.split('.').reduce((v,n) => v*256+Number(n),0),{ b,offset,count }=this.geoTable;let lo=0,hi=count-1;
          while (lo<hi) { const mid=(lo+hi)>>>1;if (b.readUInt32LE(offset+mid*6)<ip) lo=mid+1;else hi=mid; }
          const cc=b.readUInt16LE(offset+lo*6+4);result[host]=b.toString('ascii',2+cc*2,4+cc*2).toLowerCase();
        } catch { result[host]=null; }
      }
    }));return result;
  }
  async dispose() { this.generation++;this.abort?.abort();for (const item of this.probes) item.abort();for (const job of this.delayQueue.splice(0)) job.resolve({ latency:null });await this.serial(() => this.stop());while (this.delayActive) await pause(50); }
}
