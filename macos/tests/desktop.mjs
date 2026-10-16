// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import net from 'node:net';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
const exec=promisify(execFile);
const { _electron }=await import(path.resolve('macos/build/test-tools/node_modules/playwright-core/index.mjs'));
assert.equal(process.platform,'darwin');assert.equal(process.env.GITHUB_ACTIONS,'true');
const arch=process.argv[2],version=JSON.parse(await fs.readFile('package.json','utf8')).version;
const appdir=path.resolve(`macos/build/${arch}/Vyrax.app`),temporary=await fs.mkdtemp(path.join(os.tmpdir(),'vyrax-mac-ui-'));
const output=path.resolve(`release/macos-${version}`),sockets=new Set();
// A fresh synthetic Keychain avoids interactive ACL prompts on hosted runners.
// Production Keychains and the user's real VPN store are never used by this test.
const keychain=path.join(temporary,'test.keychain-db');
const previousDefault=(await exec('security',['default-keychain','-d','user'])).stdout.trim().replace(/^"|"$/g,'');
const previousList=[...(await exec('security',['list-keychains','-d','user'])).stdout.matchAll(/"([^"]+)"/g)].map(v=>v[1]);
await exec('security',['create-keychain','-p','Vyrax-CI-synthetic-only',keychain]);
await exec('security',['unlock-keychain','-p','Vyrax-CI-synthetic-only',keychain]);
await exec('security',['list-keychains','-d','user','-s',keychain,...previousList]);
await exec('security',['default-keychain','-d','user','-s',keychain]);
await exec('security',['add-generic-password','-a','Vyrax','-s','Vyrax Safe Storage','-w','Synthetic Keychain fixture; no user secret','-A',keychain]);
const stalled=net.createServer(socket=>{sockets.add(socket);socket.on('error',()=>{});socket.on('close',()=>sockets.delete(socket));});
await new Promise(resolve=>stalled.listen(0,'127.0.0.1',resolve));
const app=await _electron.launch({ executablePath:path.join(appdir,'Contents/MacOS/Vyrax'),chromiumSandbox:true,
  env:{...process.env,VYRAX_TEST_USER_DATA:temporary,ELECTRON_ENABLE_LOGGING:'1'} });
let report;
try{
  const page=await app.firstWindow(),errors=[];page.on('pageerror',e=>errors.push(e.message));
  console.log('macOS first window created');
  await page.waitForSelector('.shell');await page.waitForTimeout(500);
  assert.equal(await page.evaluate(()=>document.documentElement.dataset.platform),'macos');
  assert.equal(await page.evaluate(()=>typeof window.require),'undefined');assert.equal(await page.evaluate(()=>typeof window.process),'undefined');
  assert.equal(await page.locator('.bar').evaluate(el=>getComputedStyle(el).webkitAppRegion),'drag');
  const security=await app.evaluate(({BrowserWindow,safeStorage})=>({preferences:BrowserWindow.getAllWindows()[0].webContents.getLastWebPreferences(),keychain:safeStorage.isEncryptionAvailable()}));
  assert.equal(security.preferences.sandbox,true);assert.equal(security.preferences.contextIsolation,true);assert.equal(security.preferences.nodeIntegration,false);assert.equal(security.keychain,true);
  console.log('Renderer security and synthetic Keychain available');
  await page.evaluate(()=>window.VyraxMac.call('copy',{text:'macOS synthetic clipboard'}));
  assert.equal(await page.evaluate(()=>window.VyraxMac.call('clipboard')),'macOS synthetic clipboard');
  await page.screenshot({path:path.join(output,`desktop-en-${arch}.png`)});
  const profile={id:'fixture',sourceId:'group',name:'Mac fixture',protocol:'vless',transport:'tcp',host:'127.0.0.1',port:stalled.address().port,uuid:'00000000-0000-4000-8000-000000000001',cc:'de'};
  const saved={profiles:[profile],subscriptions:[{id:'group',kind:'local',name:'Mac test group'}],selectedId:'fixture',activeSourceId:'group',selectionMode:'manual',settings:{preferencesVersion:1,mode:'proxy',theme:'dark',mtu:1280}};
  await page.evaluate(data=>window.VyraxMac.call('save',data),saved);await page.reload();await page.waitForTimeout(600);
  const store=await fs.readFile(path.join(temporary,'data/store.enc'));assert.equal(store[0],1);assert.ok(!store.includes(Buffer.from(profile.uuid)));
  console.log('Keychain-encrypted store saved and reloaded');
  await page.getByRole('button',{name:'locations',exact:true}).click();await page.waitForSelector('.locations');
  await page.locator('.check-row').click();await page.locator('.source-picker').click();await page.waitForSelector('.subscriptions-sheet');
  await page.locator('.sub-actions button').first().click();await page.waitForSelector('.toast');
  assert.ok(await page.locator('.toast').evaluate(el=>+getComputedStyle(el).zIndex>+getComputedStyle(document.querySelector('.sheet-backdrop')).zIndex));
  await page.locator('.sub-actions button').nth(1).click();await page.waitForSelector('.qr-share img');
  await page.locator('.subscriptions-sheet .sheet-close').click({timeout:1500});assert.equal(await page.locator('.subscriptions-sheet').count(),0);
  await page.getByRole('button',{name:/^(settings|tools)$/i}).first().click();await page.getByRole('button',{name:'فارسی',exact:true}).click();
  assert.equal(await page.evaluate(()=>document.documentElement.dir),'rtl');await page.waitForTimeout(600);
  await page.screenshot({path:path.join(output,`desktop-fa-${arch}.png`)});assert.deepEqual(errors,[]);
  report={architecture:arch,launch:true,platform:'macos',sandbox:true,contextIsolation:true,nodeIntegration:false,keychainEncryption:true,clipboard:true,draggableTitlebar:true,nonblockingDialogClose:true,QR:true,toastAboveDialog:true,persianRTL:true,rendererErrors:errors};
  console.log('macOS sandbox, Keychain store, clipboard, QR, nonblocking dialog, English/Persian and titlebar verified');
}finally{
  for(const socket of sockets)socket.destroy();stalled.close();
  // Closing a window intentionally hides to the menu bar. Verify native Quit.
  console.log('Requesting native macOS Quit');
  await app.evaluate(({app})=>{setImmediate(()=>app.quit());return true;});
  const child=app.process();let timeout;
  try{
    if(child.exitCode===null&&!child.signalCode)await Promise.race([new Promise(resolve=>child.once('exit',resolve)),new Promise((_,reject)=>{timeout=setTimeout(()=>{child.kill('SIGKILL');reject(Error('macOS host did not quit cleanly'));},15000);})]);
    if(report){report.gracefulQuit=true;await fs.writeFile(path.join(output,`desktop-verification-${arch}.json`),JSON.stringify(report,null,2));}
    console.log('Native Quit completed and cores stopped');
  }finally{clearTimeout(timeout);}
  await exec('security',['default-keychain','-d','user','-s',previousDefault]);
  await exec('security',['list-keychains','-d','user','-s',...previousList]);
  await exec('security',['delete-keychain',keychain]);await fs.rm(temporary,{recursive:true,force:true});
}
