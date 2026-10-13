// Run with the Vite server on port 5273 and Playwright installed locally:
// npm install --prefix .inspect/ui-parity --no-save playwright
// node .tools/selftest/home-parity.mjs
import assert from 'node:assert/strict';
import { mkdir, writeFile } from 'node:fs/promises';
import { chromium } from '../../.inspect/ui-parity/node_modules/playwright/index.mjs';

const output='.inspect/ui-parity';
await mkdir(output,{recursive:true});
const browser=await chromium.launch({channel:'msedge',headless:true});
const selectors=['.dial','.quick','.readout','.chips.session','.chips.traffic','.ip-line','.pill','.home-stage'];
const results=[];
async function open(platform,width,height,lang='en') {
  const page=await browser.newPage({viewport:{width,height},deviceScaleFactor:1});
  const errors=[];page.on('pageerror',error=>errors.push(error.message));
  await page.addInitScript(lang=>localStorage.setItem('vyrax-lang',lang),lang);
  await page.goto(`http://127.0.0.1:5273/.tools/selftest/home-parity.html?platform=${platform}`);
  await page.waitForSelector('.quick');await page.waitForTimeout(750);
  return {page,errors};
}
async function connected(page) {
  await page.evaluate(()=>{
    window.__testEmit({event:'state',status:'connected',profileId:'ui-0',exit:'198.51.100.42'});
    window.__testEmit({event:'stats',down:1048576,up:1024,downRate:128000,upRate:3300});
  });await page.waitForTimeout(1050);
}
async function geometry(page) {
  return page.evaluate(selectors=>Object.fromEntries(selectors.map(s=>{
    const el=document.querySelector(s);if(!el)return [s,null];
    const r=el.getBoundingClientRect();return [s,{x:r.x,y:r.y,w:r.width,h:r.height}];
  })),selectors);
}
async function trace(page,selector,action,duration=1000) {
  return page.evaluate(({selector,action,duration})=>new Promise(resolve=>{
    const frames=[],start=performance.now();
    const record=t=>{
      const r=document.querySelector(selector).getBoundingClientRect();
      frames.push({t:t-start,x:r.x,y:r.y});
      if(t-start<duration)requestAnimationFrame(record);else resolve(frames);
    };
    if(action==='orbit')document.querySelector('.quick').click();
    else window.__testEmit({event:'state',status:action,profileId:'ui-0',exit:'198.51.100.42'});
    requestAnimationFrame(record);
  }),{selector,action,duration});
}
try {
  let reference;
  for(const platform of ['webview2','android']) {
    const {page,errors}=await open(platform,380,646);
    const hero=await trace(page,'.dial','connected');
    assert(new Set(hero.map(f=>Math.round(f.y))).size>8,'hero rises continuously after connection');
    await page.waitForTimeout(200);
    const metrics=await geometry(page);
    if(!reference)reference=metrics;
    else for(const s of selectors)for(const axis of ['x','y','w','h'])assert(Math.abs(metrics[s][axis]-reference[s][axis])<1,`${s} ${axis} matches Windows`);
    const movement=await trace(page,'.drop','orbit');
    assert(new Set(movement.map(f=>Math.round(f.x))).size>12,'orbit moves through intermediate positions');
    const settled=movement.at(-1).x;
    assert(Math.min(...movement.map(f=>f.x))<settled-4,'orbit retains Windows spring overshoot');
    await page.screenshot({path:`${output}/${platform}-connected-open.png`});
    const closing=await trace(page,'.drop','orbit');
    assert(Math.abs(closing.at(-1).x+28-190)<1,'closed node returns exactly to the dial centre');
    assert(await page.evaluate(()=>document.elementFromPoint(190,document.querySelector('.dial').getBoundingClientRect().top+75)?.closest('.dial')!==null),'dial occludes returning flags');
    await page.screenshot({path:`${output}/${platform}-connected.png`});
    assert.equal(errors.length,0,errors.join('\n'));
    results.push({platform,metrics,hero,movement,closing});await page.close();
  }
  for(const [width,height] of [[320,568],[360,740],[412,868],[560,1024]])for(const lang of ['en','fa']) {
    const {page,errors}=await open('android',width,height,lang);
    const idle=await geometry(page);
    assert(Math.abs(idle['.dial'].x+idle['.dial'].w/2-width/2)<1,'idle dial is centred');
    assert.equal(await page.locator('.connection-details').evaluate(el=>getComputedStyle(el).visibility),'hidden');
    await connected(page);
    const metrics=await geometry(page);
    for(const s of ['.dial','.quick','.chips.session','.chips.traffic','.ip-line','.pill'])assert(Math.abs(metrics[s].x+metrics[s].w/2-width/2)<1,`${s} centred on ${width} ${lang}`);
    assert(metrics['.readout'].y>metrics['.quick'].y+metrics['.quick'].h,'readout does not intersect the toggle');
    assert(metrics['.chips.traffic'].y+metrics['.chips.traffic'].h<=metrics['.ip-line'].y+1,'IP follows traffic without overlap');
    assert(metrics['.ip-line'].y+metrics['.ip-line'].h<=metrics['.pill'].y+1,`IP fits above picker at ${width}x${height} ${lang}`);
    await page.locator('.quick').click();await page.waitForTimeout(1000);
    const drops=await page.locator('.drop').evaluateAll(els=>els.map(el=>{const r=el.getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2,left:r.left,right:r.right};}));
    assert(Math.abs(drops[0].x+drops[3].x-width)<1&&Math.abs(drops[1].x+drops[2].x-width)<1,'orbit mirrored horizontally');
    assert(Math.abs(drops[0].y-drops[3].y)<1&&Math.abs(drops[1].y-drops[2].y)<1,'orbit mirrored vertically');
    assert(drops.every(r=>r.left>=0&&r.right<=width),'orbit fits the viewport');
    // Retarget while moving, then verify it settles and remains clickable.
    await page.locator('.quick').click();await page.waitForTimeout(100);await page.locator('.quick').click();await page.waitForTimeout(1100);
    assert.equal(await page.locator('.quick').getAttribute('aria-expanded'),'true');
    assert(await page.evaluate(()=>Math.abs(document.querySelector('.shell').scrollLeft)<1),'rapid toggles cannot scroll the RTL shell sideways');
    const afterToggle=await geometry(page);
    assert(Math.abs(afterToggle['.dial'].x+afterToggle['.dial'].w/2-width/2)<1,'dial stays centred after rapid toggles');
    await page.screenshot({path:`${output}/android-${width}x${height}-${lang}.png`});
    assert.equal(errors.length,0,errors.join('\n'));results.push({width,height,lang,metrics});await page.close();
  }
  const {page}=await open('android',380,646);
  await connected(page);
  await page.evaluate(()=>{
    const shell=document.querySelector('.shell');shell.classList.add('has-update');
    const notice=document.createElement('div');notice.className='update-notice';notice.textContent='New version available';
    shell.querySelector('.bar').after(notice);
  });await page.waitForTimeout(800);
  const updateMetrics=await geometry(page);
  assert(updateMetrics['.ip-line'].y+updateMetrics['.ip-line'].h<=updateMetrics['.pill'].y+1,'update banner does not overlap home content');
  await page.screenshot({path:`${output}/android-update-banner.png`});
  await page.emulateMedia({reducedMotion:'reduce'});
  await connected(page);await page.locator('.quick').click();await page.waitForTimeout(80);
  assert(await page.locator('.drop').first().evaluate(el=>{const dial=document.querySelector('.dial').getBoundingClientRect();return Math.abs(el.getBoundingClientRect().left-(dial.left-75*dial.width/150))<1;}),'reduced motion orbit reaches its position immediately');
  await page.close();
  await writeFile(`${output}/home-parity-results.json`,JSON.stringify(results,null,2));
  console.log('Home parity passed: Windows geometry, spring motion, masking, rapid toggles, four phone sizes, both languages and reduced motion.');
} finally {await browser.close();}
