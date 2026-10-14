// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import React,{ useLayoutEffect,useRef,useState } from 'react';
import { useI18n } from '../../i18n.jsx';
import { formatUptime } from '../../lib/dashboard-format.mjs';
import { connectionSymbol } from '../../lib/dashboard-layout.mjs';
function Morph({ running }) {
  const [value,setValue]=useState(running?1:0),current=useRef(value);
  useLayoutEffect(()=>{
    const target=running?1:0,from=current.current;if(from===target)return;
    if(window.matchMedia('(prefers-reduced-motion: reduce)').matches){current.current=target;setValue(target);return;}
    let frame,start;
    function step(now){start??=now;const t=Math.min(1,(now-start)/450),s=1.70158,e=1+(s+1)*Math.pow(t-1,3)+s*Math.pow(t-1,2);current.current=from+(target-from)*e;setValue(current.current);if(t<1)frame=requestAnimationFrame(step);}
    frame=requestAnimationFrame(step);return()=>cancelAnimationFrame(frame);
  },[running]);
  return <svg viewBox="0 0 24 24" className="connect-symbol" aria-hidden="true">{connectionSymbol(value).map((points,i)=><polygon key={i} points={points}/>)}</svg>;
}
export default function ConnectButton({ state,onPower,disabled }) {
  const { t }=useI18n(),running=state.connected||state.connecting,busy=state.connecting||state.disconnecting;
  const text=busy?t(state.disconnecting?'dash.stopping':'home.connecting'):formatUptime(state.uptime),textRef=useRef(null),[textWidth,setTextWidth]=useState(0);
  useLayoutEffect(()=>{setTextWidth(textRef.current?.getBoundingClientRect().width||0);},[text]);
  const label=state.disconnecting?t('dash.stopping'):state.connecting?t('dash.cancel'):running?t('home.disconnect'):t('home.connect');
  return <button type="button" onClick={onPower} disabled={state.disconnecting||disabled} aria-label={label} title={label} aria-busy={busy} className={`connect-fab ${running?'running':''} ${busy?'busy':''}`} style={{'--fab-width':`${running||busy?Math.min(220,76+textWidth):56}px`}}>
    <Morph running={running}/><span className="connect-fab-text"><bdi ref={textRef}>{text}</bdi></span>
  </button>;
}
