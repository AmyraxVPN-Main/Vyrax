// SPDX-License-Identifier: MIT
// Guardian protocol adapted from FoxyVPN, © 2026 Vauth (MIT).
import { Store } from './store.mjs';
import { ENDPOINTS, CLIENT_ID, SCOPE, responseJson, tokenExpiry, validateFreeProfile } from '../src/lib/free-servers.mjs';

export class FreeProvider {
  constructor(store, transport = fetch) {
    this.store = new Store(store.root+'/firefox',store.secretStorage);this.store.requireEncryption = store.requireEncryption;
    this.transport=transport;this.queue=Promise.resolve();this.generation=0;this.pass='';this.expiry=0;this.state={signedIn:false};
  }
  serial(fn) { const task=this.queue.then(fn);this.queue=task.catch(()=>{});return task; }
  async init() { await this.store.init();let saved;try{saved=await this.store.load();}catch{saved={};this.readError=true;}this.accounts=saved.accounts || (saved.refreshToken?[saved]:[]);this.session=this.accounts.find(a=>a.email===saved.activeEmail)||this.accounts[0]||{};this.restoreState(); }
  restoreState(){this.pass='';this.expiry=0;this.state={signedIn:!!this.session.refreshToken,email:this.session.email||'',activated:this.session.activated,quota:this.session.quota};}
  summary(){return {...this.state,activeEmail:this.session.email||'',accounts:this.accounts.map(a=>({email:a.email,...(a.email===this.session.email?{activated:this.state.activated,quota:this.state.quota}:{activated:a.activated,quota:a.quota})}))};}
  async persist(){if(this.session.email){this.session={...this.session,activated:this.state.activated,quota:this.state.quota};this.accounts=this.accounts.filter(a=>a.email!==this.session.email).concat(this.session);}await this.store.save({accounts:this.accounts,activeEmail:this.session.email||''});}
  async request({endpoint,body='',authorization=''}, internal=false) {
    if (!Object.hasOwn(ENDPOINTS,endpoint) || (!internal && !['login','verify','oauth','servers'].includes(endpoint)) || typeof body!=='string' || body.length>32768 || typeof authorization!=='string' || authorization.length>32768 || /[\r\n]/.test(authorization)) throw Error('err.action');
    const [method,url]=ENDPOINTS[endpoint],controller=new AbortController(),timer=setTimeout(()=>controller.abort(),15000);
    try {
      const response=await this.transport(url,{method,redirect:'error',credentials:'omit',signal:controller.signal,headers:{'Content-Type':'application/json','Accept':'application/json','User-Agent':'Vyrax Firefox-compatible client',...(authorization?{Authorization:authorization}:{})},...(method==='POST'?{body}: {})});
      let size=0,text='';const decoder=new TextDecoder();for await(const part of response.body){size+=part.length;if(size>1048576)throw Error('err.tooBig');text+=decoder.decode(part,{stream:true});}text+=decoder.decode();
      const headers={};for(const name of ['x-quota-limit','x-quota-remaining','x-quota-reset'])headers[name]=response.headers.get(name);
      return {status:response.status,body:text,headers};
    } catch(e) { if(e.message?.startsWith('err.'))throw e;throw Error('err.freeNetwork'); }
    finally {clearTimeout(timer);}
  }
  save(session) { return this.serial(async()=>{
    for(const key of ['accessToken','refreshToken'])if(typeof session[key]!=='string'||!session[key]||session[key].length>16384||/[\s\x00-\x1f]/.test(session[key]))throw Error('err.freeAuth');
    if(typeof session.email!=='string'||!session.email||session.email.length>254||(!this.accounts.some(a=>a.email===session.email)&&this.accounts.length>=10))throw Error('err.freeAccounts');
    this.generation++;this.session={accessToken:session.accessToken,refreshToken:session.refreshToken,expiresAt:Number(session.expiresAt)||0,email:String(session.email||'').slice(0,254)};
    this.restoreState();await this.persist();this.readError=false;return this.summary();
  }); }
  async access() {
    if(!this.session.refreshToken)throw Error('err.freeAuth');
    if(this.session.accessToken && this.session.expiresAt>Date.now()/1000+60)return this.session.accessToken;
    const response=await this.request({endpoint:'oauth',body:JSON.stringify({client_id:CLIENT_ID,grant_type:'refresh_token',refresh_token:this.session.refreshToken,scope:SCOPE})},true);
    if([400,401,403].includes(response.status))throw Error('err.freeAuth');
    const data=responseJson(response);if(!data.access_token)throw Error('err.freeAuth');
    this.session={...this.session,accessToken:data.access_token,refreshToken:data.refresh_token||this.session.refreshToken,expiresAt:Math.floor(Date.now()/1000)+(Number(data.expires_in)||86400)};
    await this.persist();return this.session.accessToken;
  }
  async authorized(endpoint) {
    let response=await this.request({endpoint,authorization:'Bearer '+await this.access()},true);
    if([401,403].includes(response.status)){this.session.expiresAt=0;response=await this.request({endpoint,authorization:'Bearer '+await this.access()},true);}
    return response;
  }
  quota(response,data={}) {
    const n=name=>{const value=response.headers?.[name];return value!=null&&/^\d+$/.test(value)?Number(value):null;};
    const limit=n('x-quota-limit') ?? (Number.isSafeInteger(data.maxBytes)&&data.maxBytes>=0?data.maxBytes:null) ?? this.state.quota?.limit ?? null;
    this.state={...this.state,...(typeof data.subscribed==='boolean'?{activated:data.subscribed}:{}),quota:{limit,remaining:n('x-quota-remaining'),reset:n('x-quota-reset')}};
  }
  account(operation='status') { return this.serial(async()=>{
    if(operation==='local'){if(this.readError)throw Error('err.freeStorage');return this.summary();}
    if(!['status','activate'].includes(operation))throw Error('err.action');
    const response=await this.authorized(operation),data=responseJson(response);this.quota(response,data);
    if(data.subscribed && operation==='status') { const r=await this.authorized('token');if(r.status===200){const d=responseJson(r);this.cache(r,d);}else if(r.status===429){this.quota(r);this.state.quota.remaining=0;} }
    await this.persist();return this.summary();
  }); }
  cache(response,data) {
    if(typeof data.token!=='string'||!data.token||data.token.length>16384||/[\s\x00-\x1f]/.test(data.token))throw Error('err.freeAuth');
    this.pass=data.token;this.expiry=Number(data.expires_at)||tokenExpiry(data.token);this.quota(response);this.state.activated=true;
  }
  resolve(profiles,source) { return this.serial(async()=>{
    const list=profiles.filter(p=>p.protocol!=='firefox'||(p.sourceId||'')===source),free=list.filter(p=>p.protocol==='firefox');
    if(free.length){free.forEach(validateFreeProfile);if(!this.pass||this.expiry<=Date.now()/1000+60){const r=await this.authorized('token');this.cache(r,responseJson(r));}}
    return list.map(p=>p.protocol==='firefox'?{...p,proxyPass:this.pass}:{...p});
  }); }
  switchAccount(email){return this.serial(async()=>{await this.persist();const selected=this.accounts.find(a=>a.email===email);if(!selected)throw Error('err.freeAuth');this.session=selected;this.restoreState();await this.persist();return this.summary();});}
  logout() { this.generation++;return this.serial(async()=>{this.accounts=this.accounts.filter(a=>a.email!==this.session.email);this.session=this.accounts[0]||{};this.restoreState();await this.persist();return this.summary();}); }
  remove(email){return this.serial(async()=>{this.accounts=this.accounts.filter(a=>a.email!==email);if(this.session.email===email){this.session=this.accounts[0]||{};this.restoreState();}await this.persist();return this.summary();});}
}
