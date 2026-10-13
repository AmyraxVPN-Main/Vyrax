// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import fs from 'node:fs/promises';
import path from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
const exec = promisify(execFile);
const command = async (exe,args) => (await exec(exe,args,{ timeout:4000, maxBuffer:65536 })).stdout.trim();
export class DesktopProxy {
  constructor(root) { this.journal = path.join(root,'proxy-recovery.json'); }
  async adapter() {
    if ((process.env.XDG_CURRENT_DESKTOP || '').match(/KDE/i)) {
      for (const suffix of ['6','5']) {
        try { await command(`kreadconfig${suffix}`,['--help']);return { get:(_schema,key) => command(`kreadconfig${suffix}`,['--file','kioslaverc','--group','Proxy Settings','--key',key]), set:(_schema,key,value) => command(`kwriteconfig${suffix}`,['--file','kioslaverc','--group','Proxy Settings','--key',key,value]), kde:true }; } catch { /* Try next desktop version. */ }
      }
      throw Error('err.proxyUnavailable');
    }
    if (!(process.env.XDG_CURRENT_DESKTOP || '').match(/GNOME|Unity|Cinnamon/i)) throw Error('err.proxyUnavailable');
    try { if ((await command('gsettings',['list-schemas'])).split('\n').includes('org.gnome.system.proxy')) return { get:(schema,key) => command('gsettings',['get',schema,key]), set:(schema,key,value) => command('gsettings',['set',schema,key,value]) }; } catch { /* No supported desktop proxy service. */ }
    throw Error('err.proxyUnavailable');
  }
  async enable(http,socks) {
    await this.recover();const adapter = await this.adapter();
    const entries = adapter.kde ? [['','httpProxy',`http://127.0.0.1:${http}`],['','httpsProxy',`http://127.0.0.1:${http}`],['','socksProxy',`socks://127.0.0.1:${socks}`],['','NoProxyFor','localhost,127.0.0.0/8,::1'],['','ProxyType','1']] :
      [['org.gnome.system.proxy.http','host',"'127.0.0.1'"],['org.gnome.system.proxy.http','port',String(http)],['org.gnome.system.proxy.https','host',"'127.0.0.1'"],['org.gnome.system.proxy.https','port',String(http)],['org.gnome.system.proxy.socks','host',"'127.0.0.1'"],['org.gnome.system.proxy.socks','port',String(socks)],['org.gnome.system.proxy','ignore-hosts',"['localhost', '127.0.0.0/8', '::1']"],['org.gnome.system.proxy','mode',"'manual'"]];
    const values = [];for (const [schema,key,value] of entries) values.push({ schema,key,value,previous:await adapter.get(schema,key) });
    await fs.writeFile(this.journal,JSON.stringify({ kde:!!adapter.kde,values }),{ mode:0o600 });
    try { for (const item of values) await adapter.set(item.schema,item.key,item.value); }
    catch (e) { await this.recover();throw e; }
  }
  async recover() {
    let data;try { data = JSON.parse(await fs.readFile(this.journal,'utf8')); } catch (e) { if (e.code === 'ENOENT') return;throw e; }
    const adapter = await this.adapter();
    if (!!adapter.kde !== data.kde) throw Error('err.proxyRestore');
    // Respect desktop settings changed by the user or another VPN after us.
    for (const item of [...data.values].reverse()) if (await adapter.get(item.schema,item.key) === item.value) await adapter.set(item.schema,item.key,item.previous);
    await fs.unlink(this.journal);
  }
}
