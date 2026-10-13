// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { preferences,validate,catalog,routing,xray,nodeTag } from '../config.mjs';
import { Store } from '../store.mjs';
import { privateHosts } from '../backend.mjs';
const profile={ id:'a',sourceId:'first',protocol:'vless',host:'example.test',port:443,uuid:'00000000-0000-4000-8000-000000000001',transport:'tcp',tls:true };
const profiles=[profile,{ ...profile,id:'b',latency:40 },{ ...profile,id:'c',sourceId:'second',latency:1 }];
test('sharing only binds private LAN addresses and never the tunnel or public interfaces',() => {
  assert.deepEqual(privateHosts({ eth0:[{ family:'IPv4',address:'192.168.1.2',internal:false },{ family:'IPv4',address:'1.2.3.4',internal:false }],Vyrax:[{ family:'IPv4',address:'172.28.0.1',internal:false }],lo:[{ family:'IPv4',address:'127.0.0.1',internal:true }] }),['192.168.1.2']);
  const built=xray(profiles,'a','manual','first',{ preferencesVersion:1 },{ socks:19000,http:19001,probe:19002,api:19003,metrics:19004,share:19005,shareHosts:['192.168.1.2'] });
  assert.equal(built.config.inbounds.find(v => v.tag==='share-0').listen,'192.168.1.2');
});
test('automatic routes remain scoped; manual routes contain no balancer target',() => {
  for (const mode of ['fastest','balance']) {
    const result=routing(profiles,'a',mode,'first',preferences({ preferencesVersion:1 }));
    assert.deepEqual(result.config.balancers[0].selector,profiles.slice(0,2).map(nodeTag));
    assert.equal(result.config.balancers[0].strategy.type,mode==='fastest' ? 'leastPing' : 'leastLoad');
  }
  const manual=routing(profiles,'b','manual','first',preferences({ preferencesVersion:1 }));
  assert.equal(manual.selected.id,'b');assert.ok(manual.config.rules.every(v => !v.balancerTag));
  assert.throws(() => routing(profiles,'a','fastest','missing',preferences()),/err.noSourceServers/);
});
test('credential changes receive new handler tags; display names preserve handlers',() => {
  assert.notEqual(nodeTag(profile),nodeTag({ ...profile,uuid:'00000000-0000-4000-8000-000000000002' }));
  assert.equal(nodeTag(profile),nodeTag({ ...profile,name:'renamed',latency:33 }));
});
test('invalid host/protocol/credentials/catalog never reach core or privilege helper',() => {
  for (const invalid of [{ host:'bad/host' },{ host:'bad\nflag' },{ port:0 },{ protocol:'freedom' },{ transport:'exec' },{ uuid:'invalid' },{ reality:true }]) assert.throws(() => validate({ ...profile,...invalid }),/err\./);
  assert.throws(() => catalog([profile,profile]),/err.catalog/);
});
test('preferences validate lists, conflicts and MTU; old experimental defaults migrate',() => {
  assert.equal(preferences({ autoConnect:true }).autoConnect,false);
  assert.throws(() => preferences({ preferencesVersion:1,splitTunneling:true }),/err.routeEmpty/);
  assert.throws(() => preferences({ preferencesVersion:1,splitTunneling:true,bypassSites:true }),/err.routeConflict/);
  assert.throws(() => preferences({ preferencesVersion:1,mtu:900 }),/err.config/);
  assert.throws(() => preferences({ preferencesVersion:1,mode:'unknown' }),/err.mode/);
  const result=xray(profiles,'a','manual','first',{ preferencesVersion:1,bypassSites:true,bypassAddresses:['example.org','1.2.3.0/24'] },{ socks:19000,http:19001,probe:19002,api:19003,metrics:19004 });
  assert.ok(result.config.routing.rules.some(v => v.domain?.includes('domain:example.org') && v.outboundTag==='direct'));
  assert.ok(result.config.inbounds.every(v => v.listen==='127.0.0.1'));
});
test('local store encrypts secrets, serializes writes and refuses corrupt data',async () => {
  const root=await fs.mkdtemp(path.join(os.tmpdir(),'vyrax-store-test-'));
  try {
    const store=new Store(root);await store.init();
    assert.equal((await store.load()).profiles.length,0);
    await Promise.all([store.save({ profiles:[profile],settings:{ preferencesVersion:1 } }),store.save({ profiles:[{ ...profile,id:'final' }],settings:{ preferencesVersion:1 } })]);
    assert.equal((await store.load()).profiles[0].id,'final');
    const bytes=await fs.readFile(path.join(root,'store.enc'));assert.ok(!bytes.includes(Buffer.from(profile.uuid)));
    if (process.platform!=='win32') assert.equal((await fs.stat(path.join(root,'store.enc'))).mode & 0o777,0o600);
    bytes[bytes.length-1]^=1;await fs.writeFile(path.join(root,'store.enc'),bytes);await assert.rejects(store.load(),/err.storeRead/);
  } finally { await fs.rm(root,{ recursive:true,force:true }); }
});
