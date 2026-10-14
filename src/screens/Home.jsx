// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import React, { useEffect,useState } from 'react';
import { useI18n } from '../i18n.jsx';
import { call,native,platform } from '../bridge.js';
import { cleanName } from '../lib/geo.js';
import { formatBytes,trafficPath } from '../lib/dashboard-format.mjs';
import useDashboardMetrics from '../lib/useDashboardMetrics.js';
import Glyph from '../components/Glyph.jsx';
import ConnectButton from '../components/dashboard/ConnectButton.jsx';
import '../components/dashboard/dashboard.css';
function Header({ icon,children,extra }) {
  return <div className="dash-card-heading"><Glyph name={icon} size={18}/><span title={typeof children==='string'?children:undefined}>{children}</span>{extra}</div>;
}
function TrafficValue({ value,icon }) {
  const [number,unit]=formatBytes(value).split(' ');
  return <div className="dash-traffic-value"><Glyph name={icon} size={14}/><bdi>{number}</bdi><small>{unit}</small></div>;
}
const widgetIds=['speed','proxy','tun','strategy','network','ip','usage'];
function readWidgets() { try { const value=JSON.parse(localStorage.getItem('vyrax-dashboard-widgets'));return Array.isArray(value)&&value.every(id=>widgetIds.includes(id)) ? [...new Set(value)] : widgetIds; } catch{return widgetIds;} }
export default function Home({ state,server,selectionMode,onPower,onPickServer,onAdd,onMode,onAuto,onPing,checking,selectionBusy,onAbout }) {
  const { t }=useI18n(),[measure,metrics]=useDashboardMetrics(),[editing,setEditing]=useState(false),[widgets,setWidgets]=useState(readWidgets),[localIp,setLocalIp]=useState('');
  const live=state.connected&&!state.disconnecting,locked=state.connected||state.connecting||state.disconnecting||selectionBusy;
  const history=(live?state.trafficHistory||[]:[]).slice(-60),selection=['manual','fastest','balance'].indexOf(selectionMode);
  const path=trafficPath([...Array.from({length:60-history.length},()=>({up:0,down:0})),...history],320,97);
  const total=state.up+state.down,share=total?state.down/total:0;
  useEffect(()=>{let alive=true;const update=()=>{if(native)call('networkInfo').then(data=>{if(alive)setLocalIp(data?.addresses?.[0]||'');}).catch(()=>{});};update();window.addEventListener('focus',update);return()=>{alive=false;window.removeEventListener('focus',update);};},[]);
  const labels={speed:'dash.speed',proxy:'dash.systemProxy',tun:'dash.tun',strategy:'auto.title',network:'dash.detection',ip:'dash.intranetIp',usage:'dash.traffic'};
  function toggleWidget(id) {setWidgets(current=>{const next=current.includes(id)?current.filter(value=>value!==id):widgetIds.filter(value=>value===id||current.includes(value));try{localStorage.setItem('vyrax-dashboard-widgets',JSON.stringify(next));}catch{}return next;});}
  function control(mode) {
    const on=state.settings.mode===mode;
    return <article key={mode} className={`dash-card dash-${mode}`}><Header icon={mode==='tun'?'shield':'shuffle'}>{t(labels[mode])}</Header>
      <div className="dash-toggle-row"><span>{t(on?'dash.enabled':'dash.disabled')}</span><button type="button" role="switch" aria-checked={on} aria-label={t(labels[mode])} title={t(locked?'dash.stopToChange':'dash.transportHint')} disabled={locked||platform==='ios'} className={`material-switch ${on?'on':''}`} onClick={()=>onMode(on?(mode==='tun'?'proxy':'tun'):mode)}><span/></button></div></article>;
  }
  const cards={
    speed:<article key="speed" className="dash-card dash-speed"><Header icon="speed" extra={<div className="dash-rates" dir="ltr"><span>↑ <bdi>{formatBytes(state.upRate).replace(' ','')}/s</bdi></span><span>↓ <bdi>{formatBytes(state.downRate).replace(' ','')}/s</bdi></span></div>}>{t('dash.speed')}</Header><div className="dash-chart"><svg viewBox="0 0 320 136" preserveAspectRatio="none" role="img" aria-label={t('dash.speed')}><path className="dash-chart-area" d={`${path} L320,136 L0,136 Z`}/><path className="dash-chart-line" d={path}/></svg></div></article>,
    proxy:control('proxy'),tun:control('tun'),
    strategy:<article key="strategy" className="dash-card dash-strategy"><Header icon="route">{t('auto.title')}</Header><div className="dash-strategy-options" role="group" aria-label={t('auto.title')} style={{'--selection':Math.max(0,selection)}}><span className="dash-strategy-highlight" aria-hidden="true"/>{[['manual','manual','dash.manual'],['fastest','zap','auto.fastest'],['balance','shuffle','auto.balance']].map(([mode,icon,label])=><button type="button" key={mode} disabled={selectionBusy||!server} aria-pressed={selectionMode===mode} onClick={()=>onAuto(mode)}><Glyph name={icon} size={18}/><span>{t(label)}</span></button>)}</div></article>,
    network:<article key="network" className="dash-card dash-network"><Header icon="wifi" extra={<button className="dash-info" type="button" onClick={server?onPickServer:onAdd} aria-label={t('dash.server')}><Glyph name="info" size={16}/></button>}>{t('dash.detection')}</Header><button className={`dash-detection ${server?.tested&&server.latency==null?'failed':''}`} type="button" onClick={server?onPing:onAdd} disabled={checking} title={t('dash.probeHint')}><span role="status">{checking?t('loc.pinging'):server?.latency!=null?<bdi>{server.latency} ms</bdi>:server?.tested?'Timeout':t('dash.testNetwork')}</span></button></article>,
    ip:<article key="ip" className="dash-card dash-ip"><Header icon="devices">{t('dash.intranetIp')}</Header><bdi title={localIp}>{localIp||'—'}</bdi></article>,
    usage:<article key="usage" className="dash-card dash-usage"><Header icon="pie">{t('dash.traffic')}</Header><svg className="dash-donut" viewBox="0 0 64 64" aria-hidden="true"><circle className="dash-donut-track" cx="32" cy="32" r="25"/><circle className="dash-donut-value" cx="32" cy="32" r="25" strokeDasharray={`${share*157.08} 157.08`}/></svg><div className="dash-traffic-rows"><TrafficValue value={state.up} icon="up"/><TrafficValue value={state.down} icon="down"/></div></article>
  };
  return <section className={`dashboard ${live?'is-connected':''}`} aria-label={t('dash.title')}>
    <header className="dash-title"><h1>{t('dash.title')}</h1><div className="dash-title-actions"><button type="button" className={`dash-icon-button dash-core-status ${native?'ready':''}`} aria-label={t(native?'dash.coreReady':'dash.preview')} title={t(native?'dash.coreReady':'dash.preview')} onClick={onAbout}><Glyph name="check" size={24}/></button><button className={`dash-icon-button dash-edit ${editing?'active':''}`} type="button" aria-label={t(editing?'dash.done':'dash.edit')} aria-pressed={editing} onClick={()=>setEditing(!editing)}><Glyph name={editing?'check':'edit'} size={23} filled/></button></div></header>
    <div className="dashboard-scroll"><div ref={measure} className="dashboard-measure">
      {editing&&<div className="dashboard-editor"><p>{t('dash.customize')}</p><div>{widgetIds.map(id=><button type="button" key={id} aria-pressed={widgets.includes(id)} onClick={()=>toggleWidget(id)}><Glyph name={widgets.includes(id)?'check':'plus'} size={16}/>{t(labels[id])}</button>)}</div></div>}
      <div className={`dashboard-grid columns-${metrics.columns} ${widgets.length!==widgetIds.length?'custom-layout':''}`} style={{'--dash-unit':`${metrics.unit}px`,'--dash-inset':`${metrics.inset}px`,'--dash-vertical':`${metrics.vertical}px`,'--dash-radius':`${metrics.radius}px`,'--dash-scale':metrics.textScale}}>{widgets.map(id=>cards[id])}</div>
    </div></div>
    <div className="dash-connect-dock"><span className="sr-only" role="status">{t(state.disconnecting?'dash.stopping':state.connecting?'home.connecting':live?'home.protected':'home.notConnected')}</span>{server?<ConnectButton state={state} onPower={onPower} disabled={selectionBusy&&!state.connected&&!state.connecting}/>:<button className="connect-fab" type="button" aria-label={t('loc.add')} onClick={onAdd}><Glyph name="plus"/></button>}</div>
    {server&&<span className="sr-only">{t('dash.server')}: {cleanName(server.name)}</span>}
  </section>;
}
