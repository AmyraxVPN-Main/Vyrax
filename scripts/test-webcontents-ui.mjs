// Native Electron smoke checks when Playwright cannot discover a macOS page target.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {setTimeout as delay} from 'node:timers/promises';
export async function testWebContentsUI(app, output, platform, port) {
 const evaluate=code=>app.evaluate(async({BrowserWindow},code)=>BrowserWindow.getAllWindows()[0].webContents.executeJavaScript(code),code);
 const wait=async code=>{for(let i=0;i<100;i++){if(await evaluate(code))return;await delay(100);}throw Error('Native DOM timeout: '+code);};
 const click=async selector=>{await wait(`!!document.querySelector(${JSON.stringify(selector)})`);await evaluate(`document.querySelector(${JSON.stringify(selector)}).click()`);};
 const screenshot=async name=>{const png=await app.evaluate(async({BrowserWindow})=>(await BrowserWindow.getAllWindows()[0].capturePage()).toPNG().toString('base64'));await fs.writeFile(path.join(output,name),Buffer.from(png,'base64'));};
 await wait("!!document.querySelector('.shell')");
 assert.equal(await evaluate('document.documentElement.dataset.platform'),platform);
 const security=await app.evaluate(({BrowserWindow})=>BrowserWindow.getAllWindows()[0].webContents.getLastWebPreferences());
 assert.equal(security.sandbox,true);assert.equal(security.contextIsolation,true);assert.equal(security.nodeIntegration,false);
 const store={profiles:[{id:'fixture',sourceId:'group',name:'Loopback UI fixture',protocol:'vless',transport:'tcp',host:'127.0.0.1',port,uuid:'00000000-0000-4000-8000-000000000001',cc:'de'}],subscriptions:[{id:'group',kind:'local',name:'Local UI fixture'}],selectedId:'fixture',activeSourceId:'group',selectionMode:'manual',settings:{preferencesVersion:1,mode:'proxy',theme:'dark',mtu:1280}};
 await evaluate(`(async()=>{await window.VyraxMac.call('save',${JSON.stringify(store)});localStorage.setItem('vyrax-lang','en');location.reload();})()`);
 await wait("!!document.querySelector('.dashboard-grid')");await delay(700);await screenshot('desktop-en.png');
 await click('.dock-slot:nth-of-type(2)');await click('.loc-head .icon-btn');await click('.source-picker');
 await click('.sheet .sub-actions button');await wait("!!document.querySelector('.toast')");
 assert.ok(await evaluate("+getComputedStyle(document.querySelector('.toast')).zIndex>80"));
 await click('.sheet .sub-actions button:nth-child(2)');await wait("!!document.querySelector('.qr-share img')");
 await click('.sheet-close');await wait("!document.querySelector('.sheet.subscriptions-sheet')");
 await click('.dock-slot:nth-of-type(5)');await click('.tool-card');
 await evaluate("[...document.querySelectorAll('button')].find(e=>e.textContent.trim()==='فارسی').click()");await wait("document.documentElement.dir==='rtl'");
 await click('.dock-slot');await delay(600);await screenshot('desktop-fa.png');
 await click('.dock-slot:nth-of-type(5)');await click('.tool-card:nth-child(6)');await delay(500);
 assert.ok(await evaluate("document.querySelector('.about-brand').textContent.includes('0.1.35')"));await screenshot('about-fa.png');
 await fs.writeFile(path.join(output,'native-ui.json'),JSON.stringify({platform,version:'0.1.35',nativeLaunch:true,automationAdapter:'Electron webContents; Playwright page discovery timed out',sandbox:true,contextIsolation:true,subscriptionCopy:true,subscriptionQr:true,nonblockingPingModal:true,rtl:true,versionVerified:true,realAccountLoginTested:false},null,2));
 console.log('Native webContents UI checks passed:',platform);
}
