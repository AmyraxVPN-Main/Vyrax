import test from 'node:test';
import assert from 'node:assert/strict';
import { activateFreeAccess } from '../src/lib/free-account-actions.mjs';

const state = activated => ({ signedIn:true, email:'fixture@example.test', activated, quota:{remaining:21474836480} });

test('confirmed activation updates the account without another activation request',async()=>{
  const calls=[],published=[];
  const account=await activateFreeAccess(async(action,args)=>{calls.push(args.operation);return state(true);},value=>published.push(value));
  assert.equal(account.activated,true);assert.deepEqual(calls,['activate']);assert.deepEqual(published,[account]);
});

test('older hosts confirm an activation acknowledgement with status before enabling servers',async()=>{
  const calls=[],published=[];
  await activateFreeAccess(async(action,args)=>{calls.push(args.operation);return state(args.operation==='status');},value=>published.push(value));
  assert.deepEqual(calls,['activate','status']);assert.deepEqual(published.map(value=>value.activated),[false,true]);
});

test('unconfirmed access produces an explicit error rather than an unchanged silent button',async()=>{
  const calls=[];
  await assert.rejects(activateFreeAccess(async(action,args)=>{calls.push(args.operation);return state(false);},()=>{}),/err.freeNotActivated/);
  assert.deepEqual(calls,['activate','status','local']);
});

test('service rejection is preserved and never causes another network activation or status request',async()=>{
  for(const error of ['err.freeChallenge','err.freeEligibility','err.freeNetwork']){
    const calls=[],published=[];
    await assert.rejects(activateFreeAccess(async(action,args)=>{calls.push(args.operation);if(args.operation==='local')return state(false);throw Error(error);},value=>published.push(value)),new RegExp(error));
    assert.deepEqual(calls,['activate','local']);assert.equal(published.at(-1).activated,false);
  }
});

test('a quota request error restores the confirmed local entitlement without hiding that error',async()=>{
  const published=[];
  await assert.rejects(activateFreeAccess(async(action,args)=>{if(args.operation==='local')return state(true);throw Error('err.freeService');},value=>published.push(value)),/err.freeService/);
  assert.equal(published.at(-1).activated,true);
});

test('older hosts receive a quota refresh after activation before the action completes',async()=>{
  const calls=[],published=[];
  await activateFreeAccess(async(action,args)=>{calls.push(args.operation);return args.operation==='activate'?{...state(true),quota:null}:state(true);},value=>published.push(value));
  assert.deepEqual(calls,['activate','status']);assert.equal(published.at(-1).quota.remaining,21474836480);
});

test('an older host with an empty acknowledgement recovers only through confirmed read-only status',async()=>{
  const calls=[];
  const account=await activateFreeAccess(async(action,args)=>{calls.push(args.operation);if(args.operation==='activate')throw Error('err.freeService');return state(true);},()=>{});
  assert.equal(account.activated,true);assert.deepEqual(calls,['activate','status']);
});

test('an invalid native result does not publish null or enable access',async()=>{
  const published=[];
  await assert.rejects(activateFreeAccess(async(action,args)=>args.operation==='local'?state(false):null,value=>published.push(value)),/err.freeService/);
  assert.equal(published.length,1);assert.equal(published[0].activated,false);
});
