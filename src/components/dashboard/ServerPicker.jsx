// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import React, { useLayoutEffect, useRef, useState } from 'react';
import { Check, Globe, Search, Shuffle, X, Zap } from '../Glyph.jsx';
import { useI18n } from '../../i18n.jsx';
import { cleanName,countryOf,protoLabel } from '../../lib/geo.js';
import { MsTag } from '../../ui.jsx';
import Flag from '../Flag.jsx';
import { mobile } from '../../bridge.js';
export default function ServerPicker({ profiles,selectedId,selectionMode,busy,closing,onPick,onAuto,onAll,onClose }) {
  const { t } = useI18n();const [query,setQuery] = useState('');const dialog = useRef(null);
  useLayoutEffect(() => {
    const previous = document.activeElement, element = dialog.current;
    if (mobile) element?.focus();else element?.querySelector('input')?.focus();
    return () => { if (element?.contains(document.activeElement) && previous?.isConnected) previous.focus(); };
  }, []);
  function keys(event) {
    if (event.key === 'Escape') { event.preventDefault();onClose(); }
    if (event.key !== 'Tab') return;
    const elements = [...dialog.current.querySelectorAll('button:not(:disabled),input')];
    if (event.shiftKey && [elements[0],dialog.current].includes(document.activeElement)) { event.preventDefault();elements[elements.length-1]?.focus(); }
    if (!event.shiftKey && [elements[elements.length-1],dialog.current].includes(document.activeElement)) { event.preventDefault();elements[0]?.focus(); }
  }
  const list = profiles.filter(p => `${p.name} ${p.host} ${p.protocol} ${protoLabel(p)}`.toLowerCase().includes(query.trim().toLowerCase())).slice(0,100);
  return <div className={`sheet-backdrop material-backdrop ${closing ? 'closing' : ''}`} onClick={onClose}><section className="material-server-sheet" tabIndex={-1} ref={dialog} role="dialog" aria-modal="true" aria-label={t('dash.server')} onClick={e => e.stopPropagation()} onKeyDown={keys}>
    <span className="material-sheet-handle" aria-hidden="true"/><header><h2>{t('dash.server')}</h2><button className="dash-icon-button" aria-label={t('win.close')} onClick={onClose}><X size={18}/></button></header>
    <label className="material-search"><Search size={17}/><input value={query} onChange={e => setQuery(e.target.value)} placeholder={t('loc.search')} aria-label={t('loc.search')}/></label>
    <div className="material-auto-options">{[['fastest',Zap],['balance',Shuffle]].map(([mode,Icon]) => <button key={mode} type="button" disabled={busy || !profiles.length} aria-pressed={selectionMode === mode} className={selectionMode === mode ? 'selected' : ''} onClick={() => onAuto(mode)}><Icon size={16}/>{t(`auto.${mode}`)}</button>)}</div>
    <div className="material-server-list">{list.map(p => <button key={p.id} type="button" className={`material-server-row ${selectedId === p.id && selectionMode === 'manual' ? 'selected' : ''}`} disabled={busy} onClick={() => onPick(p)}>
      <Flag cc={countryOf(p)} label={protoLabel(p)}/><span><b>{cleanName(p.name)}</b><small><bdi>{p.host}</bdi></small></span><MsTag value={p.latency} failed={p.tested && p.latency == null}/>{selectedId === p.id && selectionMode === 'manual' && <Check size={16}/>}</button>)}
      {!list.length && <p className="material-empty">{t('loc.noneSub')}</p>}</div>
    <button className="material-sheet-all" onClick={onAll}><Globe size={16}/>{t('dash.allServers')}</button>
  </section></div>;
}
