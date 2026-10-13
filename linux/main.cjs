// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
const { app,BrowserWindow,ipcMain,protocol,net,clipboard,dialog,shell,Tray,Menu,safeStorage } = require('electron');
const path = require('node:path');
const fs = require('node:fs/promises');
const { pathToFileURL } = require('node:url');
const root = path.resolve(__dirname,'..');
protocol.registerSchemesAsPrivileged([{ scheme:'vyrax',privileges:{ standard:true,secure:true,supportFetchAPI:true } }]);
app.setName('Vyrax');app.setAppUserModelId('com.amyrax.vyrax');
// Each desktop test gets a separate store; production always uses the OS path.
if(process.env.GITHUB_ACTIONS==='true'&&process.env.VYRAX_TEST_USER_DATA)app.setPath('userData',path.resolve(process.env.VYRAX_TEST_USER_DATA));
if (process.getuid?.()===0) { console.error('Run the desktop as your regular user. TUN requests its own permission.');app.exit(1); }
if (!app.requestSingleInstanceLock()) app.exit(0);
let window,tray,backend,quitting=false,shutdown=false;
const show = () => { window.show();if (window.isMinimized()) window.restore();window.focus(); };
app.on('second-instance',show);
app.on('activate',() => window && show());
app.on('before-quit',event => {
  if (shutdown) return;event.preventDefault();quitting=true;
  void (async () => { try { await backend?.dispose(); } finally { shutdown=true;app.quit(); } })();
});
for (const signal of ['SIGTERM','SIGINT']) process.on(signal,() => app.quit());
app.whenReady().then(async () => {
  const [{ Backend,fetchText },{ Store },{ projectLinks }] = await Promise.all([import(process.platform==='darwin' ? '../macos/backend.mjs' : './backend.mjs'),import('./store.mjs'),import('../src/lib/releases.mjs')]);
  const project=JSON.parse(await fs.readFile(path.join(root,'project.json'),'utf8'));
  const version=JSON.parse(await fs.readFile(path.join(root,'package.json'),'utf8')).version;
  const links=projectLinks(project);
  if(process.platform==='darwin')Menu.setApplicationMenu(Menu.buildFromTemplate([{role:'appMenu'},{role:'editMenu'},{role:'windowMenu'}]));
  protocol.handle('vyrax',async request => {
    const url=new URL(request.url);
    if (url.hostname!=='app' || !['GET','HEAD'].includes(request.method)) return new Response('',{ status:403 });
    let relative;try { relative=decodeURIComponent(url.pathname).replace(/^\/+/, '') || 'index.html'; } catch { return new Response('',{ status:400 }); }
    const base=path.join(root,'ui'),file=path.resolve(base,relative);
    if (!file.startsWith(base+path.sep)) return new Response('',{ status:403 });
    const response=await net.fetch(pathToFileURL(file).href);
    const headers=new Headers(response.headers);
    headers.set('Content-Security-Policy',"default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self'; worker-src 'self' blob:; object-src 'none'; base-uri 'none'; frame-ancestors 'none'");
    return new Response(response.body,{ status:response.status,headers });
  });
  const store=new Store(path.join(app.getPath('userData'),'data'),safeStorage);store.requireEncryption=process.platform==='darwin';await store.init();
  window=new BrowserWindow({ width:380,height:646,minWidth:360,minHeight:620,frame:false,resizable:true,backgroundColor:'#121311',title:'Vyrax',icon:path.join(root,'ui','vyrax-icon.png'),webPreferences:{ preload:path.join(__dirname,'preload.cjs'),sandbox:true,contextIsolation:true,nodeIntegration:false,webSecurity:true,devTools:!app.isPackaged } });
  window.webContents.setWindowOpenHandler(() => ({ action:'deny' }));
  window.webContents.on('will-navigate',(event,url) => { if (url!=='vyrax://app/index.html') event.preventDefault(); });
  window.webContents.session.setPermissionRequestHandler((_wc,_permission,callback) => callback(false));
  backend=new Backend({ nativeRoot:path.join(process.resourcesPath,'native'),store,emit:data => { if (!window.isDestroyed()) window.webContents.send('vyrax:event',data); },transport:(...args) => net.fetch(...args) });
  await backend.init();
  const actions={
    load:() => store.load(),save:args => backend.save(args),ready:() => backend.ready(),status:() => backend.snapshot(),
    connect:args => backend.connect(args.profile,args.settings || { preferencesVersion:1,mode:args.mode,mtu:args.mtu }),
    disconnect:() => backend.disconnect(),select:args => backend.select(args.profiles,args.selectedId,args.selectionMode,args.activeSourceId || ''),
    delay:args => backend.delay(args.profile),ping:args => backend.delay(args.profile),subscription:args => backend.subscription(args.url),geo:args => backend.geo(args.hosts),
    validateSettings:async args => { const { preferences }=await import('./config.mjs');const settings=preferences(args);return { splitAddresses:settings.splitAddresses,bypassAddresses:settings.bypassAddresses }; },
    clipboard:() => clipboard.readText(),copy:args => { if (typeof args.text!=='string' || Buffer.byteLength(args.text)>4*1024*1024) throw Error('err.tooBig');clipboard.writeText(args.text);return true; },
    file:async () => { const result=await dialog.showOpenDialog(window,{ properties:['openFile'],filters:[{ name:'VPN configurations',extensions:['txt','json','yaml','yml','conf'] }] });if (result.canceled) return '';const file=result.filePaths[0];if ((await fs.stat(file)).size>4*1024*1024) throw Error('err.tooBig');return fs.readFile(file,'utf8'); },
    minimize:() => { window.minimize();return true; },close:() => { if (tray) window.hide();else app.quit();return true; },drag:() => true,language:() => true,
    openProjectLink:async args => { if (!Object.hasOwn(links,args.target)) throw Error('err.action');await shell.openExternal(links[args.target]);return true; },
    checkUpdates:async () => { try { const { text }=await fetchText((...args) => net.fetch(...args),`https://api.github.com/repos/${project.repository}/releases/latest`,{ timeout:12000,limit:262144,headers:{ Accept:'application/vnd.github+json','User-Agent':`Vyrax/${version}`,'X-GitHub-Api-Version':'2022-11-28' } });return { release:text ? JSON.parse(text) : null }; } catch { throw Error('err.updateCheck'); } }
  };
  ipcMain.handle('vyrax:call',async (event,action,args) => {
    if (event.sender!==window.webContents || event.senderFrame!==window.webContents.mainFrame || !Object.hasOwn(actions,action) || !args || typeof args!=='object' || JSON.stringify(args).length>8*1024*1024) throw Error('err.action');
    try { return await actions[action](args); } catch (e) { throw Error(e.message?.startsWith('err.') ? e.message : 'err.unknown'); }
  });
  try {
    tray=new Tray(path.join(root,'ui',process.platform==='darwin' ? 'trayTemplate.png' : 'vyrax-icon.png'));tray.setToolTip('Vyrax');
    tray.setContextMenu(Menu.buildFromTemplate([{ label:'Vyrax',click:show },{ label:'Disconnect',click:() => void backend.disconnect() },{ type:'separator' },{ label:'Quit',click:() => app.quit() }]));
    tray.on('click',() => window.isVisible() && window.isFocused() ? window.hide() : show());
  } catch { /* Desktops without a tray close cleanly instead of hiding forever. */ }
  window.on('close',event => { if (!quitting && tray) { event.preventDefault();window.hide(); } });
  await window.loadURL('vyrax://app/index.html');
}).catch(error => { console.error(error.message?.startsWith('err.') ? error.message : 'Vyrax could not start');quitting=true;app.quit(); });
