// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
// Run under dbus-run-session with a temporary XDG_CONFIG_HOME.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { execFile,spawn } from 'node:child_process';
import { promisify } from 'node:util';
import { DesktopProxy } from '../desktop-proxy.mjs';
const exec=promisify(execFile),pause=ms => new Promise(resolve => setTimeout(resolve,ms));
const root=process.env.XDG_CONFIG_HOME;
if (!root?.includes('vyrax-proxy-test-')) throw Error('Use an isolated test config folder');
await fs.mkdir(root,{ recursive:true,mode:0o700 });
const proxy=new DesktopProxy(root),adapter=await proxy.adapter();
await adapter.set('org.gnome.system.proxy','mode',"'auto'");
await adapter.set('org.gnome.system.proxy.http','port','18080');
await proxy.enable(19080,19081);
assert.equal(await adapter.get('org.gnome.system.proxy','mode'),"'manual'");
assert.equal(await adapter.get('org.gnome.system.proxy.http','port'),'19080');
await proxy.recover();
assert.equal(await adapter.get('org.gnome.system.proxy','mode'),"'auto'");
assert.equal(await adapter.get('org.gnome.system.proxy.http','port'),'18080');
await proxy.enable(19080,19081);await adapter.set('org.gnome.system.proxy.http','port','20080');await proxy.recover();
assert.equal(await adapter.get('org.gnome.system.proxy.http','port'),'20080');
await proxy.enable(19080,19081);
const owner=spawn(process.execPath,['-e','setInterval(()=>{},1000)'],{ stdio:'ignore' });
const watcher=spawn(process.execPath,['linux/proxy-lease.mjs',String(owner.pid),root],{ stdio:'inherit' });
await pause(700);owner.kill('SIGKILL');
await new Promise((resolve,reject) => { watcher.once('exit',code => code===0 ? resolve() : reject(Error('Watcher failed')));setTimeout(() => { watcher.kill();reject(Error('Watcher timeout')); },5000).unref(); });
assert.equal(await adapter.get('org.gnome.system.proxy','mode'),"'auto'");
assert.equal(await adapter.get('org.gnome.system.proxy.http','port'),'20080');
await assert.rejects(fs.stat(path.join(root,'proxy-recovery.json')));
console.log('GNOME proxy enable, restore, user changes and crash recovery passed');
