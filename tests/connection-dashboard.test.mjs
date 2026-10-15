// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import test from 'node:test';
import assert from 'node:assert/strict';
import { connectionReducer, normalizeConnection, TRAFFIC_CAPACITY } from '../src/lib/connection-state.mjs';
import { createConnectionActions } from '../src/lib/connection-actions.mjs';
import { testLatencyBatch,probeIdentity } from '../src/lib/latency-batch.mjs';
import { formatBytes,formatUptime,trafficPath } from '../src/lib/dashboard-format.mjs';
const initial = () => normalizeConnection({}, { connected:false,connecting:false,up:0,down:0,upRate:0,downRate:0,settings:{} },10000);
const deferred = () => { let resolve,reject;const promise = new Promise((a,b) => {resolve=a;reject=b;});return { promise,resolve,reject }; };
function actions(transport) {
  let state = initial();const errors = [],timers = new Map();let id = 0;
  const controller = createConnectionActions({ transport,dispatch:action => { state = connectionReducer(state,{...action,now:10000}); },onError:error => errors.push(error),setTimer:fn => {timers.set(++id,fn);return id;},clearTimer:key => timers.delete(key) });
  controller.start();return { controller,errors,timers,get state() {return state;} };
}
const profile = { id:'a',protocol:'vless',host:'test.example',port:443,uuid:'synthetic' };
const routing = { catalog:[profile],selectionMode:'manual',source:'test' };
test('duplicate connected events and live server switching preserve session time', () => {
  let state = connectionReducer(initial(),{type:'snapshot',data:{status:'connected'},now:10000});
  state = connectionReducer(state,{type:'tick',now:65000});assert.equal(state.uptime,55);
  state = connectionReducer(state,{type:'snapshot',data:{status:'connected',switched:true},now:66000});
  assert.equal(state.startedAt,10000);assert.equal(state.uptime,56);assert.equal(state.phase,'connected');
});
test('background time is caught up from the clock and disconnect clears rates and IP', () => {
  let state = connectionReducer(initial(),{type:'snapshot',data:{status:'connected',since:'1970-01-01T00:00:10Z',exit:'203.0.113.1'},now:10000});
  state = connectionReducer(state,{type:'tick',now:200000});assert.equal(state.uptime,190);
  state = connectionReducer(state,{type:'snapshot',data:{status:'disconnected'},now:201000});
  assert.equal(state.uptime,0);assert.equal(state.exit,null);assert.equal(state.upRate,0);
  assert.equal(connectionReducer(state,{type:'stats',data:{downRate:42}}),state);
});
test('telemetry is finite, burst-coalesced and bounded across long sessions', () => {
  let state = connectionReducer(initial(),{type:'snapshot',data:{status:'connected'},now:10000});
  for(let i=0;i<150;i++)state=connectionReducer(state,{type:'stats',data:{upRate:1,downRate:100,up:NaN,down:-1},now:10000+i*1000});
  assert.equal(state.trafficHistory.length,TRAFFIC_CAPACITY);assert.equal(state.up,0);assert.equal(state.down,0);
  const last=state.trafficHistory.at(-1).at;
  state=connectionReducer(state,{type:'stats',data:{downRate:200},now:last+100});
  assert.equal(state.trafficHistory.length,TRAFFIC_CAPACITY);assert.equal(state.trafficHistory.at(-1).down,200);
});
test('quick cancel invalidates the old response and rejects its late connected event', async () => {
  const wait=deferred(),calls=[];
  const s=actions(async action => {calls.push(action);return action==='connect'?wait.promise:{status:'disconnected'};});
  const pending=s.controller.connect(profile,{mode:'tun'},routing);
  await s.controller.toggle(profile,{},routing,s.state);assert.equal(s.state.phase,'idle');
  assert.equal(s.controller.receive({status:'connected'}),false);wait.resolve({status:'connected'});await pending;
  assert.equal(s.state.connected,false);assert.deepEqual(calls,['connect','disconnect']);assert.equal(s.timers.size,0);s.controller.dispose();
});
test('connect stages do not treat the core preparation disconnect as a user disconnect', async () => {
  const wait=deferred();const s=actions(async()=>wait.promise);
  const pending=s.controller.connect(profile,{},routing);assert.equal(s.state.phase,'connecting');
  assert.equal(s.controller.receive({status:'disconnected'}),false);
  s.controller.receive({status:'connecting',stage:'stage.retry'});assert.equal(s.state.phase,'retrying');
  wait.resolve({status:'connected'});await pending;assert.equal(s.state.phase,'connected');s.controller.dispose();
});
test('failed disconnect reconciles with the host instead of displaying a false stopped state', async () => {
  const s=actions(async action=>{if(action==='disconnect')throw Error('transport');return {status:'connected'};});
  s.controller.receive({status:'connected'});await s.controller.disconnect();
  assert.equal(s.state.phase,'connected');assert.equal(s.errors.length,1);s.controller.dispose();
});
test('a selection response belongs only to its current connection generation', async () => {
  const s=actions(async()=>({status:'disconnected'}));
  s.controller.receive({status:'connected'});const revision=s.controller.revision();
  assert.equal(s.controller.isCurrent(revision),true);await s.controller.disconnect();
  assert.equal(s.controller.isCurrent(revision),false);assert.equal(s.controller.isBusy(),false);
  assert.equal(s.controller.receive(null),false);assert.equal(s.controller.receive({profileId:'late'}),false);s.controller.dispose();
});
test('an unavailable status after a failed stop permits later host reconciliation', async () => {
  const s=actions(async()=>{throw Error('bridge');});s.controller.receive({status:'connected'});
  assert.equal(await s.controller.disconnect(),false);assert.equal(s.state.disconnecting,false);
  assert.equal(s.controller.receive({status:'connected'}),true);s.controller.dispose();
});
test('a failed cancellation reconciles an ongoing host connection and accepts its completion', async () => {
  const s=actions(async action=>{if(action==='disconnect')throw Error('bridge');return {status:'connecting',stage:'stage.handshake'};});
  s.controller.receive({status:'connecting'});await s.controller.disconnect();
  assert.equal(s.state.phase,'connecting');assert.equal(s.controller.receive({status:'connected'}),true);assert.equal(s.state.phase,'connected');s.controller.dispose();
});
test('partial live snapshots retain sharing while explicit nulls clear stale endpoint data', () => {
  let state=connectionReducer(initial(),{type:'snapshot',data:{status:'connected',share:{port:8080},exit:'203.0.113.1',activeTargets:['a']},now:10000});
  state=connectionReducer(state,{type:'snapshot',data:{status:'connected',switched:true},now:11000});
  assert.equal(state.share.port,8080);assert.equal(state.exit,'203.0.113.1');
  state=connectionReducer(state,{type:'snapshot',data:{status:'connected',share:null,exit:null},now:12000});
  assert.equal(state.share,null);assert.equal(state.exit,null);
  state=connectionReducer(state,{type:'snapshot',data:{status:'disconnected'},now:13000});assert.deepEqual(state.activeTargets,[]);
});
test('deadline cancellation stops the host and cannot be reversed by a late success', async () => {
  const wait=deferred();const s=actions(async action=>action==='connect'?wait.promise:{status:'disconnected'});
  const pending=s.controller.connect(profile,{},routing);s.timers.values().next().value();await Promise.resolve();
  wait.resolve({status:'connected'});await pending;assert.equal(s.state.connected,false);assert.equal(s.errors[0].message,'err.timeout');s.controller.dispose();
});
test('disposing a UI never stops an established native VPN or applies late state', async () => {
  const wait=deferred(),calls=[];const s=actions(action=>{calls.push(action);return wait.promise;});
  const pending=s.controller.connect(profile,{},routing);s.controller.dispose();wait.resolve({status:'connected'});await pending;
  assert.deepEqual(calls,['connect']);assert.equal(s.timers.size,0);assert.equal(s.controller.receive({status:'connected'}),false);
});
test('latency batch is bounded, progressive, deduplicated and failures cannot become 0ms', async () => {
  let inFlight=0,peak=0;const delivered=[];
  const profiles=Array.from({length:6},(_,i)=>({...profile,id:String(i)}));
  const results=await testLatencyBatch([...profiles,profiles[0]],{concurrency:2,probe:async p=>{inFlight++;peak=Math.max(peak,inFlight);await new Promise(r=>setTimeout(r,2));inFlight--;if(p.id==='3')throw Error('timeout');return {latency:p.id==='4'?NaN:30};},onResult:(p,n)=>delivered.push([p.id,n])});
  assert.equal(peak,2);assert.equal(results.length,6);assert.equal(delivered.length,6);assert.equal(results.find(([id])=>id==='3')[1],null);assert.equal(results.find(([id])=>id==='4')[1],null);
});
test('cancelled probes cannot update changed or removed profiles', async () => {
  const controller=new AbortController(),wait=deferred(),delivered=[];
  const pending=testLatencyBatch([profile,{...profile,id:'b'}],{concurrency:1,signal:controller.signal,probe:()=>wait.promise,onResult:p=>delivered.push(p)});
  controller.abort();wait.resolve({latency:35});assert.deepEqual(await pending,[]);assert.deepEqual(delivered,[]);
  assert.equal(probeIdentity(profile),probeIdentity({...profile,name:'renamed',favorite:true,latency:40}));
  assert.notEqual(probeIdentity(profile),probeIdentity({...profile,uuid:'changed'}));
});
test('formatting handles long sessions and empty chart values without invalid SVG paths', () => {
  assert.equal(formatUptime(360005),'100:00:05');assert.equal(formatBytes(1536),'1.5 KB');assert.equal(trafficPath([]),'');
  assert.ok(!trafficPath([{up:Infinity,down:NaN}]).includes('NaN'));assert.ok(!trafficPath([{up:Infinity,down:0}]).includes('Infinity'));
  const smooth=trafficPath([{up:0,down:0},{up:100,down:1000},{up:0,down:0}]);assert.ok(smooth.includes(' C'));assert.ok(smooth.endsWith('320.00,80.00'));
});
