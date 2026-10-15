import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { FreeProvider } from '../linux/free-provider.mjs';

for(const mode of ['confirmed','acknowledged','inactive','challenge','quotaFailure','exhausted']) {
  test(`Electron provider matches Windows activation: ${mode}`,async t=>{
    const root=await fs.mkdtemp(path.join(os.tmpdir(),'vyrax-provider-parity-'));
    t.after(()=>fs.rm(root,{recursive:true,force:true}));const calls=[];
    const provider=new FreeProvider({root},async url=>{
      const name=url.split('/').at(-1);calls.push(name);
      const response=(body,status=200)=>new Response(body,{status,headers:{'x-quota-remaining':'4096'}});
      if(name==='activate'){
        if(mode==='challenge')return response('',406);
        if(mode==='acknowledged')return response(null,204);
        return response(mode==='confirmed'?' {"subscribed":true,"maxBytes":53687091200}':'{}');
      }
      if(name==='status')return response(JSON.stringify({subscribed:mode!=='inactive',maxBytes:53687091200}));
      if(mode==='quotaFailure')return response('',406);
      if(mode==='exhausted')return response('',429);
      return response('{"token":"synthetic-pass","expires_at":9999999999}');
    });
    await provider.init();await provider.save({email:'fixture@example.test',accessToken:'synthetic-access',refreshToken:'synthetic-refresh',expiresAt:9999999999});
    const error=mode==='inactive'?'err.freeNotActivated':['challenge','quotaFailure'].includes(mode)?'err.freeChallenge':null;
    if(error)await assert.rejects(provider.account('activate'),new RegExp(error));
    else{const result=await provider.account('activate');assert.equal(result.activated,true);assert.equal(result.quota.remaining,mode==='exhausted'?0:4096);}
    const local=await provider.account('local');assert.equal(local.signedIn,true);assert.equal(local.activated,!['inactive','challenge'].includes(mode));
    assert.equal(calls.filter(x=>x==='activate').length,1);assert.equal(calls.filter(x=>x==='status').length,['confirmed','challenge'].includes(mode)?0:1);
    assert.equal(calls.filter(x=>x==='token').length,['inactive','challenge'].includes(mode)?0:1);
    assert.ok(!JSON.stringify(await provider.store.load()).includes('synthetic-pass'));
  });
}
