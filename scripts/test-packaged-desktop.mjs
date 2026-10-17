// Native host + new UI integration, using a disposable store and loopback only.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import net from 'node:net';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {pathToFileURL} from 'node:url';
const {_electron}=await import(pathToFileURL(process.env.VYRAX_PLAYWRIGHT_MODULE).href);
const exec=promisify(execFile),platform=process.platform==='darwin'?'macos':'linux';
const executable=process.argv[2],output=process.argv[3];await fs.mkdir(output,{recursive:true});
const temporary=await fs.mkdtemp(path.join(os.tmpdir(),'vyrax-ui-0135-'));
let keychain,previousDefault,previousList,app;
const sockets=new Set(),stalled=net.createServer(socket=>{sockets.add(socket);socket.on('error',()=>{});socket.on('close',()=>sockets.delete(socket));});
await new Promise(resolve=>stalled.listen(0,'127.0.0.1',resolve));
try{
 if(platform==='macos'){
  assert.equal(process.env.GITHUB_ACTIONS,'true');keychain=path.join(temporary,'test.keychain-db');
  previousDefault=(await exec('security',['default-keychain','-d','user'])).stdout.trim().replace(/^"|"$/g,'');
  previousList=[...(await exec('security',['list-keychains','-d','user'])).stdout.matchAll(/"([^"]+)"/g)].map(v=>v[1]);
  await exec('security',['create-keychain','-p','Vyrax-CI-synthetic-only',keychain]);await exec('security',['unlock-keychain','-p','Vyrax-CI-synthetic-only',keychain]);
  await exec('security',['list-keychains','-d','user','-s',keychain,...previousList]);await exec('security',['default-keychain','-d','user','-s',keychain]);
  await exec('security',['add-generic-password','-a','Vyrax','-s','Vyrax Safe Storage','-w','Synthetic UI fixture','-A',keychain]);
 }
 app=await _electron.launch({executablePath:executable,chromiumSandbox:true,env:{...process.env,VYRAX_TEST_USER_DATA:temporary,XDG_CONFIG_HOME:temporary,XDG_CURRENT_DESKTOP:'GNOME',ELECTRON_ENABLE_LOGGING:'1'}});
 let nativeLog='';for(const stream of [app.process().stdout,app.process().stderr])stream?.on('data',chunk=>{nativeLog+=chunk.toString();});
 let page;
 try{page=await app.firstWindow({timeout:90000});}
 catch(error){
  await fs.writeFile(path.join(output,'native-startup.log'),nativeLog);
  const state=await app.evaluate(({app,BrowserWindow})=>({ready:app.isReady(),windows:BrowserWindow.getAllWindows().map(w=>({id:w.id,visible:w.isVisible(),url:w.webContents.getURL()}))})).catch(e=>({error:String(e)}));
  await fs.writeFile(path.join(output,'native-startup.json'),JSON.stringify(state,null,2));throw error;
 }
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.waitForSelector('.shell');
 assert.equal(await page.evaluate(()=>document.documentElement.dataset.platform),platform);
 const security=await app.evaluate(({BrowserWindow})=>BrowserWindow.getAllWindows()[0].webContents.getLastWebPreferences());
 assert.equal(security.sandbox,true);assert.equal(security.contextIsolation,true);assert.equal(security.nodeIntegration,false);
 const profile={id:'fixture',sourceId:'group',name:'Loopback UI fixture',protocol:'vless',transport:'tcp',host:'127.0.0.1',port:stalled.address().port,uuid:'00000000-0000-4000-8000-000000000001',cc:'de'};
 const store={profiles:[profile],subscriptions:[{id:'group',kind:'local',name:'Local UI fixture'}],selectedId:'fixture',activeSourceId:'group',selectionMode:'manual',settings:{preferencesVersion:1,mode:'proxy',theme:'dark',mtu:1280}};
 await page.evaluate(async({platform,store})=>{await window[platform==='macos'?'VyraxMac':'VyraxLinux'].call('save',store);localStorage.setItem('vyrax-lang','en');},{platform,store});
 await page.reload();await page.waitForSelector('.dashboard-grid');await page.waitForTimeout(650);
 await page.screenshot({path:path.join(output,'desktop-en.png')});
 await page.locator('.dock-slot').nth(1).click();await page.locator('.loc-head .icon-btn').first().click();
 await page.locator('.source-picker').click();await page.waitForSelector('.sheet.subscriptions-sheet');
 await page.locator('.sheet .sub-actions button').nth(0).click();await page.waitForSelector('.toast');
 assert.ok(await page.locator('.toast').evaluate(e=>+getComputedStyle(e).zIndex>80));
 await page.locator('.sheet .sub-actions button').nth(1).click();await page.waitForSelector('.qr-share img');
 await page.locator('.sheet-close').click({timeout:1500});await page.waitForSelector('.sheet.subscriptions-sheet',{state:'detached'});
 await page.locator('.dock-slot').nth(4).click();await page.locator('.tool-card').nth(0).click();await page.getByRole('button',{name:'فارسی',exact:true}).click();
 assert.equal(await page.evaluate(()=>document.documentElement.dir),'rtl');
 await page.locator('.dock-slot').nth(0).click();await page.waitForTimeout(650);await page.screenshot({path:path.join(output,'desktop-fa.png')});
 await page.locator('.dock-slot').nth(4).click();await page.locator('.tool-card').nth(5).click();await page.waitForTimeout(500);
 assert.ok((await page.locator('.about-brand').innerText()).includes('0.1.35'));await page.screenshot({path:path.join(output,'about-fa.png')});
 assert.deepEqual(errors,[]);
 await fs.writeFile(path.join(output,'native-ui.json'),JSON.stringify({platform,version:'0.1.35',nativeLaunch:true,sandbox:true,contextIsolation:true,nonblockingPingModal:true,subscriptionCopy:true,subscriptionQr:true,rtl:true,versionVerified:true,errors,realAccountLoginTested:false},null,2));
 console.log('Native UI checks passed:',platform);
}finally{
 for(const socket of sockets)socket.destroy();stalled.close();if(app)await app.close();
 if(keychain){await exec('security',['default-keychain','-d','user','-s',previousDefault]).catch(()=>{});await exec('security',['list-keychains','-d','user','-s',...previousList]).catch(()=>{});await exec('security',['delete-keychain',keychain]).catch(()=>{});}
 // Leave the disposable fixture for diagnostics; it contains no account secrets.
}
