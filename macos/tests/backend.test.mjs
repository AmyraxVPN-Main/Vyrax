// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import test from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { PassThrough } from 'node:stream';
import { Backend } from '../backend.mjs';
// The child is simulated; a synthetic UID permits lifecycle tests on Windows.
if(!process.getuid)process.getuid=()=>501;
function fixture(){
  const child=new EventEmitter();child.stdin=new PassThrough();child.stdout=new PassThrough();child.stderr=new PassThrough();child.exitCode=null;
  const backend=new Backend({ nativeRoot:'/fixed',store:{ root:'/private' },emit:()=>{},tunLauncher:()=>child });
  backend.stopChild=async()=>{child.stdin.destroy();child.exitCode=0;};return { backend,child };
}
test('permission cancellation is translated and heartbeat stops',async()=>{
  const { backend,child }=fixture();const waiting=backend.startNetwork('tun',1,0,1280);
  child.exitCode=126;child.emit('exit',126);await assert.rejects(waiting,/err.adminDeclined/);
  assert.equal(backend.heartbeat._destroyed,true);
});
test('disconnect during authorization sends stop and rejects readiness',async()=>{
  const { backend,child }=fixture();const controller=new AbortController();let input='';child.stdin.on('data',b=>{input+=b;});
  const waiting=backend.startNetwork('tun',1,0,1280,controller.signal);controller.abort();
  await assert.rejects(waiting,/err.timeout/);assert.match(input,/stop\n/);assert.equal(backend.heartbeat._destroyed,true);
});
test('native readiness is distinct from successful network restoration',async()=>{
  const { backend,child }=fixture();const waiting=backend.startNetwork('proxy',1,2,1280);
  child.stdout.write('VYRAX_NETWORK_READY\n');await waiting;
  child.stderr.write('err.proxyRestore\n');assert.equal(child.networkRestoreFailed,true);
  clearInterval(backend.proxyHeartbeat);child.stdin.destroy();
});
