import { test } from 'node:test';
import assert from 'node:assert/strict';
import { iosRequest, nodeTag } from '../../src/lib/ios-config.mjs';
const profile = {id:'one',sourceId:'sub',protocol:'vless',host:'example.test',port:443,uuid:'00000000-0000-4000-8000-000000000001',tls:true};
const settings = {_catalog:[profile],_source:'sub',_selection:'manual',preferencesVersion:1};
test('iOS retains transport settings and defaults to full-device VPN',()=>{
 const r=iosRequest('connect',{profile,settings});assert.equal(r.settings.mode,'tun');assert.equal(r.config.inbounds[0].listen,'127.0.0.1');assert.equal(r.config.outbounds[0].streamSettings.tlsSettings.serverName,'example.test');
 const reality=iosRequest('ping',{profile:{...profile,reality:true,publicKey:'test-key',sni:'cover.test',transport:'xhttp',path:'/tunnel',mode:'packet-up'}});
 assert.equal(reality.outbound.streamSettings.realitySettings.password,'test-key');assert.equal(reality.outbound.streamSettings.xhttpSettings.mode,'packet-up');
});
test('automatic choice stays in selected subscription and manual removes automatic routing',()=>{
 const two={...profile,id:'two'},other={...profile,id:'other',sourceId:'other'};
 for(const mode of ['fastest','balance','manual']){
  const r=iosRequest('select',{profiles:[profile,two,other],selectedId:'two',selectionMode:mode,activeSourceId:'sub'});
  assert.deepEqual(r.config.outbounds.slice(0,-1).map(o=>o.tag),[nodeTag(profile),nodeTag(two)]);
  const last=r.config.routing.rules.at(-1);
  if(mode==='manual'){assert.equal(last.outboundTag,nodeTag(two));assert.equal(last.balancerTag,undefined)}else assert.ok(last.balancerTag);
 }
});
test('DNS bootstrap bypasses tunnel and split routes preserve user intent',()=>{
 const r=iosRequest('connect',{profile,settings:{...settings,bypassSites:true,bypassAddresses:['example.org','203.0.113.0/24']}});
 assert.ok(r.config.routing.rules.some(r=>r.inboundTag?.includes('dns-bootstrap')&&r.outboundTag==='direct'));
 assert.ok(r.config.routing.rules.some(r=>r.domain?.includes('domain:example.org')&&r.outboundTag==='direct'));
 assert.throws(()=>iosRequest('delay',{profile:{...profile,port:0}}),/err.port/);
});
