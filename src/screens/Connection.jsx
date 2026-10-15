// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import React from 'react';
import { useI18n } from '../i18n.jsx';
import { formatBytes,formatUptime } from '../lib/dashboard-format.mjs';
import { cleanName,protoLabel } from '../lib/geo.js';
import Glyph from '../components/Glyph.jsx';
export default function Connection({ state,server,onPower,onPick,onStar }) {
  const { t }=useI18n(),active=state.connected||state.connecting;
  return <section className="connection-page"><article className="session-card"><div className="session-status"><Glyph name="connections" size={28}/><div><h2>{t('dash.session')}</h2><p role="status">{t(state.connecting?'home.connecting':state.connected?'home.protected':'dash.noSession')}</p></div><i className={state.connected?'on':''}/></div>
    {active?<><button className="session-server" type="button" onClick={onPick}><span><b>{cleanName(server?.name||'')}</b><small><bdi>{server?.host}</bdi></small></span><Glyph name="chevron" size={18}/></button><dl><div><dt>{t('set.mode')}</dt><dd>{state.settings.mode==='tun'?'TUN':'Proxy'}</dd></div><div><dt>{t('dash.protocol')}</dt><dd>{server?protoLabel(server):'—'}</dd></div><div><dt>{t('home.used')}</dt><dd><bdi>{formatBytes(state.up+state.down)}</bdi></dd></div><div><dt>{t('dash.duration')}</dt><dd><bdi>{formatUptime(state.uptime)}</bdi></dd></div></dl>{state.exit&&<div className="session-address"><span><small>{t('dash.serverAddress')}</small><bdi>{state.exit}</bdi></span><button type="button" className="dash-icon-button" aria-pressed={state.starIp} aria-label={t(state.starIp?'home.starRemove':'home.starAdd')} onClick={onStar}><Glyph name="star" size={18} fill={state.starIp?'currentColor':'none'}/></button></div>}<button className="session-action" type="button" disabled={state.disconnecting} onClick={onPower}>{t(state.disconnecting?'dash.stopping':state.connecting?'dash.cancel':'home.disconnect')}</button></>:<p className="session-empty">{t('dash.sessionHint')}</p>}
  </article></section>;
}
