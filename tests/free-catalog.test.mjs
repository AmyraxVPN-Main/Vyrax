import test from 'node:test';
import assert from 'node:assert/strict';
import { FREE_CATALOG_VERSION, upgradeSavedFreeCatalog } from '../src/lib/free-catalog.mjs';
import { FREE_SOURCE, parseFreeServers } from '../src/lib/free-servers.mjs';
import snapshot from './fixtures/mozilla-locations-2026-10-15.json' with { type:'json' };

const personal = { id:'personal',sourceId:'personal-sub',protocol:'vless',name:'My server' };
function oldStore() {
  const retained = parseFreeServers(snapshot).filter(profile => !profile.providerLocked);
  retained[1] = { ...retained[1],favorite:true,latency:73,tested:true };
  return { profiles:[personal,...retained],subscriptions:[{id:'personal-sub',kind:'local',name:'Personal'},{id:FREE_SOURCE,kind:'firefox',name:'Saved free account'}],selectedId:retained[1].id,activeSourceId:FREE_SOURCE,selectionMode:'manual',settings:{theme:'dark',autoConnect:true} };
}

test('first launch replaces seven saved locations with the full catalog before auto-connect',()=>{
  const saved=oldStore(),before=JSON.stringify(saved),upgraded=upgradeSavedFreeCatalog(saved);
  assert.equal(saved.profiles.length,8);assert.equal(JSON.stringify(saved),before);
  assert.equal(upgraded.profiles.filter(p=>p.sourceId===FREE_SOURCE).length,34);
  assert.equal(upgraded.profiles[0],personal);assert.equal(upgraded.subscriptions[0],saved.subscriptions[0]);
  assert.equal(upgraded.selectedId,saved.selectedId);assert.equal(upgraded.activeSourceId,FREE_SOURCE);assert.equal(upgraded.selectionMode,'manual');assert.equal(upgraded.settings,saved.settings);
  const chosen=upgraded.profiles.find(p=>p.id===saved.selectedId);assert.equal(chosen.favorite,true);assert.equal(chosen.latency,73);assert.equal(chosen.tested,true);
  assert.equal(upgraded.subscriptions[1].name,'Saved free account');assert.equal(upgraded.subscriptions[1].catalogVersion,FREE_CATALOG_VERSION);
  assert.equal(upgradeSavedFreeCatalog(upgraded),upgraded,'reopening must not overwrite a later live refresh');
});

test('catalog migration does not create a free subscription or touch a personal selection',()=>{
  const empty={profiles:[personal],subscriptions:[{id:'personal-sub',kind:'local'}],selectedId:personal.id};
  assert.equal(upgradeSavedFreeCatalog(empty),empty);
  const saved={...oldStore(),selectedId:personal.id,activeSourceId:'personal-sub'};
  const upgraded=upgradeSavedFreeCatalog(saved);assert.equal(upgraded.selectedId,personal.id);assert.equal(upgraded.activeSourceId,'personal-sub');
});

test('an obsolete saved free endpoint gets a valid replacement instead of a dangling selection',()=>{
  const retired={id:'firefox:retired.m1.fastly-masque.net:2499',sourceId:FREE_SOURCE,protocol:'firefox'};
  const saved={...oldStore(),profiles:[personal,retired],selectedId:retired.id};
  const upgraded=upgradeSavedFreeCatalog(saved);assert.ok(upgraded.profiles.some(p=>p.id===upgraded.selectedId));
  assert.ok(!upgraded.profiles.some(p=>p.id===retired.id));
});
