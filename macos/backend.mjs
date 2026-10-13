// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import path from 'node:path';
import { spawn } from 'node:child_process';
import { Backend as DesktopBackend } from '../linux/backend.mjs';
export { fetchText } from '../linux/backend.mjs';

// Xray/config/import/delay/pool logic is shared. Only macOS process leases,
// authorization and system network preferences differ from the Linux host.
export class Backend extends DesktopBackend {
  constructor(options) {
    super(options);
    this.proxy={recover:()=>this.stopProxy(),enable:(http,socks)=>this.startNetwork('proxy',socks,http,1280)};
  }
  spawnCore(args) {
    const child=spawn(path.join(this.nativeRoot,'vyrax-core-lease'),[String(process.pid),...args],{stdio:['ignore','pipe','pipe']});
    child.on('error',()=>this.log('Core could not start'));
    for(const stream of [child.stdout,child.stderr])stream.on('data',data=>this.log(data.toString().slice(0,4096)));
    return child;
  }
  startProxyLease(){return null;} // The authorized native lease owns restoration.
  async stopChild(child,isNetwork=false){
    if(!isNetwork)return super.stopChild(child);
    if(!child)return;
    if(child.exitCode===null){
      if(!child.stdin.destroyed)child.stdin.end('stop\n');
      let timer;await Promise.race([new Promise(resolve=>child.once('exit',resolve)),new Promise(resolve=>{timer=setTimeout(resolve,15000);})]);clearTimeout(timer);
      if(child.exitCode===null)throw Error('err.proxyRestore');
    }
    if(child.networkRestoreFailed)throw Error('err.proxyRestore');
  }
  async stopProxy(){
    clearInterval(this.proxyHeartbeat);
    const child=this.macProxy;this.macProxy=null;
    await this.stopChild(child,true);
  }
  startTun(port,mtu,signal){return this.startNetwork('tun',port,0,mtu,signal);}
  async startNetwork(mode,socks,http,mtu,signal) {
    signal?.throwIfAborted();
    const args=[mode,String(process.pid),String(process.getuid()),String(socks),String(http),String(mtu)];
    const child=this.tunLauncher ? this.tunLauncher(args) : spawn(path.join(this.nativeRoot,'vyrax-authorize'),args,{stdio:['pipe','pipe','pipe']});
    if(mode==='tun')this.tun=child;else this.macProxy=child;
    child.stdin.on('error',()=>{});
    const beat=()=>{if(!child.stdin.destroyed)child.stdin.write('alive\n');};beat();
    const heartbeat=setInterval(beat,1000);
    child.once('exit',()=>{
      clearInterval(heartbeat);
      if(mode==='proxy'&&this.macProxy===child&&this.status==='connected'){
        const desired=this.lastConnection;
        if(desired)void this.failure(this.generation,desired.profile,desired.raw);
      }
    });
    if(mode==='tun')this.heartbeat=heartbeat;else this.proxyHeartbeat=heartbeat;
    try {
      await new Promise((resolve,reject)=>{
        let text='',done=false;
        const finish=error=>{if(done)return;done=true;clearTimeout(timer);signal?.removeEventListener('abort',abort);error?reject(error):resolve();};
        const abort=()=>{child.stdin.end('stop\n');finish(Error('err.timeout'));};
        const timer=setTimeout(abort,170000);signal?.addEventListener('abort',abort,{once:true});
        child.stdout.on('data',data=>{text=(text+data.toString()).slice(-8192);if(text.includes('VYRAX_NETWORK_RESTORE_FAILED'))child.networkRestoreFailed=true;if(text.includes('VYRAX_NETWORK_READY'))finish();});
        child.stderr.on('data',data=>{const message=data.toString().slice(0,4096);if(message.includes('err.proxyRestore'))child.networkRestoreFailed=true;this.log(message);});
        child.once('exit',code=>finish(Error(code===126 ? 'err.adminDeclined' : 'err.tunnelFailed')));
        child.once('error',()=>finish(Error('err.adminDeclined')));
        if(signal?.aborted)abort();
      });
    } catch(error) {
      clearInterval(heartbeat);await this.stopChild(child,true);
      if(mode==='tun'&&this.tun===child)this.tun=null;
      if(mode==='proxy'&&this.macProxy===child)this.macProxy=null;
      throw error;
    }
  }
}
