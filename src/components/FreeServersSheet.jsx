import React, { useEffect, useRef, useState } from 'react';
import { X, Gift, BookOpen, ArrowLeft, RefreshCw, Plus, Check, Trash2, ExternalLink, Mail, ShieldCheck, Globe, ChevronRight } from 'lucide-react';
import { useI18n } from '../i18n.jsx';
import { call, native, platform } from '../bridge.js';
import { openProjectLink } from '../lib/project.js';
import { loginFirefox, verifyFirefox, oauthFirefox, responseJson, parseFreeServers } from '../lib/free-servers.mjs';
import './free-servers.css';

const amount = (n,lang) => new Intl.NumberFormat(lang,{maximumFractionDigits:2}).format(n / 1073741824)+' GB';
export default function FreeServersSheet({ onClose, onUse, onAccount, profiles }) {
  const { t, lang } = useI18n();
  const [view,setView] = useState('account'), [account,setAccount] = useState({signedIn:false,accounts:[]});
  const [email,setEmail] = useState(''), [password,setPassword] = useState(''), [code,setCode] = useState('');
  const [busy,setBusy] = useState(false), [error,setError] = useState(''), [arming,setArming] = useState('');
  const dialog = useRef(), feedback = useRef(), pending = useRef(null), alive = useRef(false);
  const authGeneration = useRef(0);
  const supported = native && ['webview2','android','linux','macos','ios'].includes(platform);
  useEffect(()=>{
    alive.current=true;const previous=document.activeElement;
    if(supported){setBusy(true);call('freeAccount',{operation:'local'}).then(async result=>{if(!alive.current)return;setAccount(result);if(result.signedIn){try{const updated=await call('freeAccount',{operation:'status'});if(alive.current){setAccount(updated);onAccount(updated);}}catch(e){if(alive.current)setError(e.message?.startsWith('err.')?e.message:'err.freeService');}}}).catch(e=>{if(alive.current)setError(e.message?.startsWith('err.')?e.message:'err.freeService');}).finally(()=>{if(alive.current)setBusy(false);});}
    return ()=>{alive.current=false;authGeneration.current++;pending.current=null;previous?.focus();};
  },[]);
  useEffect(()=>{dialog.current?.querySelector('button:not(:disabled)')?.focus();},[view,account.email,account.accounts?.length]);
  useEffect(()=>{if(!arming)return;const timer=setTimeout(()=>setArming(''),5000);return()=>clearTimeout(timer);},[arming]);
  useEffect(()=>{if(error==='err.freeChallenge')feedback.current?.scrollIntoView({block:'nearest'});},[error]);
  const request=args=>call('freeRequest',args,{timeout:20000});
  const derive=platform==='ios'?(email,password)=>call('freeCrypto',{operation:'authPassword',email,password}):undefined;
  const sign=platform==='ios'?(sessionToken,endpoint,body)=>call('freeCrypto',{operation:'hawk',sessionToken,endpoint,body}):undefined;
  async function run(action){if(busy)return;setBusy(true);setError('');try{await action();}catch(e){if(alive.current)setError(e.message?.startsWith('err.')?e.message:'err.freeService');}finally{if(alive.current)setBusy(false);}}
  async function finish(session,generation){
    const tokens=await oauthFirefox(request,session,sign);if(!alive.current||generation!==authGeneration.current)return;
    const result=await call('freeSave',tokens);pending.current=null;onAccount(result);if(!alive.current||generation!==authGeneration.current)return;
    setAccount(result);setView('account');
    const updated=await call('freeAccount',{operation:'status'});if(alive.current){setAccount(updated);onAccount(updated);}
  }
  function signIn(e){e.preventDefault();const entered=password,generation=authGeneration.current;setPassword('');run(async()=>{const session=await loginFirefox(request,email,entered,derive);if(!alive.current||generation!==authGeneration.current)return;if(session.verified)await finish(session,generation);else{pending.current=session;setCode('');setView('code');}});}
  function verify(e){e.preventDefault();const generation=authGeneration.current;run(async()=>{const session=await verifyFirefox(request,pending.current,code,sign);if(alive.current&&generation===authGeneration.current)await finish(session,generation);});}
  function refresh(){run(async()=>{const result=await call('freeAccount',{operation:'status'});if(alive.current){setAccount(result);onAccount(result);}});}
  function activate(){run(async()=>{const result=await call('freeAccount',{operation:'activate'});if(alive.current){setAccount(result);onAccount(result);}});}
  function useServers(){run(async()=>{const list=parseFreeServers(responseJson(await request({endpoint:'servers'})),profiles);if(alive.current)await onUse(list,account);});}
  function switchAccount(email){run(async()=>{const result=await call('freeSwitch',{email});onAccount(result);if(!alive.current)return;setAccount(result);const updated=await call('freeAccount',{operation:'status'});if(alive.current){setAccount(updated);onAccount(updated);}});}
  function removeAccount(email){if(arming!==email){setArming(email);return;}setArming('');run(async()=>{const result=await call('freeRemove',{email});onAccount(result);if(alive.current)setAccount(result);});}
  function back(){authGeneration.current++;pending.current=null;setPassword('');setCode('');setError('');setView('account');}
  function keyboard(e){if(e.key==='Escape'){e.preventDefault();if(view==='account')onClose();else back();}if(e.key!=='Tab')return;const items=[...dialog.current.querySelectorAll('button:not(:disabled),input:not(:disabled)')].filter(el=>el.offsetParent!==null);if(e.shiftKey&&document.activeElement===items[0]){e.preventDefault();items.at(-1)?.focus();}else if(!e.shiftKey&&document.activeElement===items.at(-1)){e.preventDefault();items[0]?.focus();}}
  const q=account.quota||{},limit=Number(q.limit),remaining=q.remaining==null?null:Math.max(0,Number(q.remaining));
  const hasQuota=q.limit!=null&&Number.isFinite(limit)&&limit>0,used=remaining==null?null:Math.max(0,limit-remaining);
  return <div className="sheet-backdrop" onClick={onClose} role="presentation">
    <section className="sheet free-sheet" ref={dialog} onClick={e=>e.stopPropagation()} onKeyDown={keyboard} role="dialog" aria-modal="true" aria-label={t(view==='guide'?'free.guide':'free.title')}>
      <header className="free-header"><Gift size={19}/><b>{t(view==='guide'?'free.guide':'free.title')}</b></header>
      <button className="sheet-close" type="button" aria-label={t('win.close')} onClick={onClose}><X size={16}/></button>
      <nav className="free-nav">{view!=='account'?<button type="button" onClick={back}><ArrowLeft size={14}/>{t('sub.back')}</button>:<button type="button" onClick={()=>{setError('');setView('guide');}}><BookOpen size={15}/>{t('free.guide')}<ChevronRight size={14}/></button>}</nav>
      <div className="free-content">
      {view==='guide'?<>
        <p className="free-intro">{t('free.guideIntro')}</p>
        <ol className="free-guide">{[['Mail','free.step1','free.step1Sub'],['ShieldCheck','free.step2','free.step2Sub'],['Gift','free.step3','free.step3Sub'],['Globe','free.step4','free.step4Sub']].map(([icon,title,detail],i)=>{const Icon={Mail,ShieldCheck,Gift,Globe}[icon];return <li key={title}><span className="free-step-icon"><Icon size={18}/><small>{i+1}</small></span><div><b>{t(title)}</b><p>{t(detail)}</p></div></li>;})}</ol>
        <div className="free-note"><b>{t('free.allowance')}</b><p>{t('free.allowanceSub')}</p><p>{t('free.tcpHint')}</p></div>
        <div className="free-links"><button onClick={()=>openProjectLink('firefoxAccount').catch(()=>setError('err.freeNetwork'))}>{t('free.createAccount')}<ExternalLink size={13}/></button><button onClick={()=>openProjectLink('firefoxHelp').catch(()=>setError('err.freeNetwork'))}>{t('free.officialHelp')}<ExternalLink size={13}/></button></div>
        <p className="free-credit">{t('free.credit')}</p>
      </>:view==='login'?<form onSubmit={signIn} className="free-form">
        <p>{t('free.loginHint')}</p><label><span>{t('free.email')}</span><input dir="ltr" type="email" value={email} onChange={e=>setEmail(e.target.value)} maxLength={254} autoComplete="username" required disabled={busy}/></label>
        <label><span>{t('free.password')}</span><input dir="ltr" type="password" value={password} onChange={e=>setPassword(e.target.value)} maxLength={4096} autoComplete="off" required disabled={busy}/></label>
        <p className="free-private">{t('free.private')}</p><button className="sheet-btn primary" disabled={busy||!supported}>{busy?<RefreshCw size={15} className="spin"/>:null}{t('free.signIn')}</button>
      </form>:view==='code'?<form onSubmit={verify} className="free-form"><p>{t('free.codeHint')} <bdi>{pending.current?.email}</bdi></p><label><span>{t('free.code')}</span><input dir="ltr" value={code} onChange={e=>setCode(e.target.value)} maxLength={16} autoComplete="one-time-code" required disabled={busy}/></label><button className="sheet-btn primary" disabled={busy}>{t('free.verify')}</button></form>:<>
        <p className="free-intro">{t('free.intro')}</p>
        {!supported&&<p className="free-note">{t('free.nativeOnly')}</p>}
        {account.signedIn&&<>
          <div className="free-quota"><div className="free-quota-title"><span>{t('free.monthly')}</span><button type="button" disabled={busy} onClick={refresh} aria-label={t('free.refresh')}><RefreshCw size={15} className={busy?'spin':''}/></button></div>
            <bdi className="free-email">{account.email}</bdi>
            {hasQuota&&remaining!=null?<><div className="free-quota-number"><b><bdi>{amount(remaining,lang)}</bdi></b><span>{t('free.remaining')}</span></div><div className="free-quota-track" role="progressbar" aria-label={t('free.remaining')} aria-valuemin={0} aria-valuemax={limit} aria-valuenow={Math.min(limit,remaining)}><i style={{width:Math.min(100,remaining/limit*100)+'%'}}/></div><div className="free-quota-details"><span>{t('free.used')} <bdi>{amount(used,lang)}</bdi></span><span>{t('free.total')} <bdi>{amount(limit,lang)}</bdi></span></div></>:<p>{t('free.quotaUnknown')}</p>}
            {Number(q.reset)>0&&<small>{t('free.reset',{date:new Date(Number(q.reset)*1000).toLocaleString(lang)})}</small>}
            <small>{t('free.quotaSnapshot')}</small>
          </div>
          <div className="free-accounts" role="group" aria-label={t('free.accounts')}><b>{t('free.accounts')}</b>{account.accounts?.map(a=><div className={`free-account-row ${a.email===account.email?'on':''}`} key={a.email}><button className="free-account-pick" disabled={busy||a.email===account.email} onClick={()=>switchAccount(a.email)}><bdi>{a.email}</bdi>{a.email===account.email&&<Check size={15}/>}</button><button type="button" className={arming===a.email?'armed':''} disabled={busy} onClick={()=>removeAccount(a.email)} aria-label={t('free.removeAccount')}><Trash2 size={14}/>{arming===a.email&&<span>{t('sub.confirmDelete')}</span>}</button></div>)}</div>
          {account.activated?<button type="button" className="sheet-btn primary" disabled={busy||remaining===0} onClick={useServers}><Globe size={16}/>{t('free.useServers')}</button>:<button type="button" className="sheet-btn primary" disabled={busy} onClick={activate}><Gift size={16}/>{t('free.activate')}</button>}
        </>}
        <button type="button" className={`sheet-btn ${account.signedIn?'':'primary'}`} disabled={busy||!supported} onClick={()=>{setError('');setEmail('');setView('login');}}><Plus size={15}/>{t(account.signedIn?'free.addAccount':'free.signIn')}</button>
        <p className="free-private">{t('free.switchHint')}</p>
      </>}
      {busy&&view==='account'&&<p className="free-working" role="status">{t('free.working')}</p>}
      {error==='err.freeChallenge'?<aside className="free-challenge" ref={feedback} role="alert">
        <b><ShieldCheck size={16}/>{t('free.challengeTitle')}</b>
        <p>{t(error)}</p><p>{t('free.challengeHelp')}</p>
        <button type="button" className="sheet-btn" disabled={busy} onClick={()=>openProjectLink('firefoxAccount').catch(()=>setError('err.freeNetwork'))}>{t('free.openAccount')}<ExternalLink size={14}/></button>
      </aside>:error&&<p className="sheet-error" role="alert">{t(error)}</p>}
      </div>
    </section>
  </div>;
}
