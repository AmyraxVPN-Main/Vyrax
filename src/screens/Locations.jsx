import React, { useMemo, useState } from 'react';
import { Search, RotateCw, Plus, Check, ChevronRight, Star, Trash2, Zap, Shuffle, Folder, Gift } from '../components/Glyph.jsx';
import { MsTag } from '../ui.jsx';
import Flag from '../components/Flag.jsx';
import Segment from '../components/Segment.jsx';
import { useI18n } from '../i18n.jsx';
import { countryOf, protoLabel, cleanName } from '../lib/geo.js';

const TABS = [['country', 'loc.country'], ['fastest', 'loc.fastest'], ['favourites', 'loc.favourites']];
const byLatency = (a, b) => (a.latency ?? Infinity) - (b.latency ?? Infinity);

export default function Locations({ profiles, selectedId, connectedId, checking, testingIds, selectionMode, selectionBusy, onAuto, sourceName, onSubscriptions, onFree, onPick, onAdd, onRemove, onFavorite, onCheck, onPing }) {
  const { t, lang } = useI18n();
  const [tab, setTab] = useState('country');
  const [query, setQuery] = useState('');
  const [busyId, setBusyId] = useState('');
  const [expanded, setExpanded] = useState(new Set());
  const regions = useMemo(() => new Intl.DisplayNames([lang], { type: 'region' }), [lang]);
  const countryName = (cc) => cc === 'REC' ? t('free.recommended') : cc ? regions.of(cc.toUpperCase()) || cc.toUpperCase() : t('loc.unknownCountry');
  const groupCode = (profile) => profile.protocol === 'firefox' && profile.recommended ? 'REC' : countryOf(profile) || '';
  const profileName = (profile) => profile.protocol === 'firefox' && profile.recommended ? t('free.recommended') : cleanName(profile.name);
  const list = useMemo(() => {
    const q = query.trim().toLowerCase();
    return profiles.filter((p) => {
      if (tab === 'favourites' && !p.favorite) return false;
      return !q || `${profileName(p)} ${p.name} ${p.host} ${p.protocol} ${countryName(groupCode(p))}`.toLowerCase().includes(q);
    }).sort(tab === 'fastest' ? byLatency : (a, b) => Number(!!b.recommended) - Number(!!a.recommended) || a.name.localeCompare(b.name, lang));
  }, [profiles, query, tab, lang]);
  const groups = useMemo(() => {
    const map = new Map();
    for (const profile of list) {
      const cc = groupCode(profile);
      if (!map.has(cc)) map.set(cc, []);
      map.get(cc).push(profile);
    }
    return [...map].map(([cc, items]) => ({ cc, name: countryName(cc), items }))
      .sort((a, b) => Number(b.cc === 'REC') - Number(a.cc === 'REC') || a.name.localeCompare(b.name, lang));
  }, [list, lang]);

  async function pingRow(profile) {
    if (busyId || checking) return;
    setBusyId(profile.id);
    try { await onPing(profile); } finally { setBusyId(''); }
  }
  const row = (p) => (
    <div key={p.id} className={`row ${selectionMode === 'manual' && selectedId === p.id ? 'on' : ''} ${connectedId === p.id ? 'live' : ''}`}>
      <button type="button" className="row-main" disabled={selectionBusy} onClick={() => onPick(p)}>
        <Flag cc={countryOf(p)} label={p.recommended ? 'REC' : protoLabel(p)} />
        <span className="row-name"><b>{profileName(p)}</b><em>{p.host}</em></span>
      </button>
      <span className="row-tail">
        <button type="button" className={`row-act fav ${p.favorite ? 'on' : ''}`} onClick={() => onFavorite(p)}
          aria-label={t(p.favorite ? 'home.starRemove' : 'home.starAdd')}><Star size={15} /></button>
        <button type="button" className={`row-ping ${testingIds?.has(p.id) || busyId === p.id ? 'busy' : ''}`} title={t('loc.ping')}
          disabled={checking} aria-label={`${t('loc.ping')} · ${cleanName(p.name)}`} onClick={() => pingRow(p)}>
          {testingIds?.has(p.id) ? <span className="ms-tag" role="status">{t('loc.pinging')}</span> :
            <MsTag value={p.latency} failed={Boolean(p.tested) && p.latency == null} />}
        </button>
        <button type="button" className="row-act danger" onClick={() => onRemove(p)} aria-label={t('loc.remove')}><Trash2 size={14} /></button>
      </span>
    </div>
  );

  return (
    <section className="locations">
      <button className="source-picker" onClick={onSubscriptions}><Folder size={15} /><span><bdi>{sourceName}</bdi></span><ChevronRight size={15} /></button>
      <button type="button" className="free-entry" onClick={onFree}><Gift size={16}/><span>{t('free.title')}</span><ChevronRight size={14}/></button>
      <div className="loc-head">
          <label className="search"><Search /><input value={query} onChange={(e) => setQuery(e.target.value)}
            placeholder={t('loc.search')} aria-label={t('loc.search')} spellCheck={false} /></label>
          <button type="button" className={`icon-btn ${checking ? 'spin' : ''}`} aria-label={t('loc.refresh')}
            disabled={checking || !profiles.length} onClick={onCheck}><RotateCw size={16} /></button>
          <button type="button" className="icon-btn" aria-label={t('loc.add')} onClick={onAdd}><Plus size={16} /></button>
      </div>
      <Segment value={tab} onChange={setTab} options={TABS.map(([id, key]) => ({ id, label: t(key) }))} />
      <div className="auto-options" role="group" aria-label={t('auto.title')}>
        {[['fastest', Zap], ['balance', Shuffle]].map(([mode, Icon]) => <button key={mode} className={`auto-option ${selectionMode === mode ? 'on' : ''}`} aria-pressed={selectionMode === mode} disabled={selectionBusy || !profiles.length} onClick={() => onAuto(mode)}><Icon size={17} /><span><b>{t(`auto.${mode}`)}</b><small>{t(`auto.${mode}Sub`)}</small></span>{selectionMode === mode && <Check size={14} />}</button>)}
      </div>
      <button type="button" className={`check-row ${checking ? 'on' : ''}`} disabled={checking || !profiles.length} onClick={onCheck}>
        <span className="tick">{checking ? <RotateCw className="spin" /> : <Check />}</span>
        <span>{t(checking ? 'loc.checking' : 'loc.check')}</span><span className="spacer" /><ChevronRight size={15} className="more" />
      </button>
      <div className="list">
        {tab === 'country' ? groups.map((group) => {
          const open = expanded.has(group.cc) || Boolean(query.trim());
          const best = [...group.items].sort(byLatency).find((p) => typeof p.latency === 'number')?.latency;
          return <div key={group.cc || 'unknown'} className={`group ${open ? 'open' : ''}`}>
            <button type="button" className="group-head" aria-expanded={open} onClick={() => setExpanded((old) => {
              const next = new Set(old); next.has(group.cc) ? next.delete(group.cc) : next.add(group.cc); return next;
            })}>
              {group.cc === 'REC' ? <span className="flag flag-md flag-ph" aria-hidden="true"><Zap size={17}/></span> : <Flag cc={group.cc} label="VPN" />}<span className="group-name">{group.name}</span>
              <span className="group-n">{group.items.length}</span><MsTag value={best} /><ChevronRight className="caret" />
            </button>
            {open && <div className="kids">{group.items.map(row)}</div>}
          </div>;
        }) : list.map(row)}
        {!list.length && <div className="empty">
          <b>{profiles.length ? t('loc.empty') : t('loc.none')}</b><span>{profiles.length ? '' : t('loc.noneSub')}</span>
          {!profiles.length && <button type="button" className="empty-add" onClick={onAdd}><Plus size={14} />{t('loc.add')}</button>}
        </div>}
      </div>
    </section>
  );
}
