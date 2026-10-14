// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import React from 'react';
import Glyph from './Glyph.jsx';
import { useI18n } from '../i18n.jsx';
const tabs=[['home','dashboard','dash.title'],['locations','globe','nav.locations'],['profiles','profiles','sub.title'],['connection','connections','dash.connection'],['settings','tools','dash.tools']];
export default function Tabs({ page,onPick,onSubscriptions,subscriptionsOpen,expanded,onExpand }) {
  const { t }=useI18n();
  return <nav className="material-nav" aria-label={t('nav.label')}>
    <button className="nav-expand" type="button" onClick={onExpand} aria-label={t('dash.expandNav')} aria-expanded={expanded} title={t('dash.expandNav')}><span><Glyph name="panel" size={22}/></span></button>
    {tabs.map(([id,icon,key])=><button key={id} type="button" className={`${id==='profiles'?'nav-profile':''} ${page===id?'selected':''}`} onClick={()=>id==='profiles'?onSubscriptions():onPick(id)} aria-label={t(key)} title={t(key)} aria-current={page===id?'page':undefined} aria-expanded={id==='profiles'?subscriptionsOpen:undefined}><span><Glyph name={icon} size={24} filled={page===id}/></span><b>{t(key)}</b></button>)}
    <button type="button" className={`nav-account ${page==='account'?'selected':''}`} onClick={()=>onPick('account')} aria-label={t('nav.account')} title={t('nav.account')}><span><Glyph name="user" size={23} filled={page==='account'}/></span><b>{t('nav.account')}</b></button>
  </nav>;
}
