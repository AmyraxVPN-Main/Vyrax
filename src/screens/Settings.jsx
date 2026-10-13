import React, { useState } from 'react';
import { Star, ChevronRight } from 'lucide-react';
import { Toggle } from '../ui.jsx';
import Segment from '../components/Segment.jsx';
import { useI18n } from '../i18n.jsx';
import LanguagePicker from '../components/LanguagePicker.jsx';

const TOP = [
  ['autoConnect', 'set.autoConnect', 'set.autoConnectSub'],
  ['autoReconnect', 'set.autoReconnect', 'set.autoReconnectSub']
];

function Pref({ title, desc, children }) {
  return (
    <div className="pref">
      <span className="pref-text">
        <b>{title}</b>
        <span>{desc}</span>
      </span>
      {children}
    </div>
  );
}

function RoutePref({ settings, settingKey, listKey, opposite, title, desc, onChange }) {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState((settings[listKey] || []).join('\n'));
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const enabled = !!settings[settingKey];
  async function save(patch) {
    setError(''); setBusy(true);
    try { await onChange(patch); setOpen(false); }
    catch (e) { setError(t(e.message)); }
    finally { setBusy(false); }
  }
  function edit() { setDraft((settings[listKey] || []).join('\n')); setError(''); setOpen(!open); }
  return (
    <div className={`pref-group ${open ? 'open' : ''}`}>
      <Pref title={t(title)} desc={t(desc)}>
        <Toggle on={enabled} disabled={busy} label={t(title)} onClick={() => {
          if (enabled) save({ [settingKey]: false });
          else if ((settings[listKey] || []).length) save({ [settingKey]: true, [opposite]: false });
          else { setDraft(''); setOpen(true); }
        }} />
      </Pref>
      <button type="button" className="route-edit" aria-expanded={open} onClick={edit} disabled={busy}>
        <span>{t('set.addressCount', { n: (settings[listKey] || []).length })}</span>
        <span>{t('set.editAddresses')} <ChevronRight size={13} /></span>
      </button>
      {open && <form className="pref-body route-form" onSubmit={(e) => { e.preventDefault(); save({ [listKey]: draft, [settingKey]: true, [opposite]: false }); }}>
        <label htmlFor={listKey}>{t('set.addressHint')}</label>
        <textarea id={listKey} dir="ltr" value={draft} onChange={(e) => setDraft(e.target.value)} rows={4} maxLength={16000} spellCheck={false} placeholder={'example.com\n203.0.113.0/24'} disabled={busy} />
        {error && <p className="pref-error" role="alert">{error}</p>}
        <p className="pref-foot">{t('set.routeExclusive')}</p>
        <button type="submit" className="pref-save" disabled={busy}>{t(busy ? 'set.saving' : 'set.saveEnable')}</button>
      </form>}
    </div>
  );
}

export default function Settings({ settings, favoriteIps, saved, elevated, onToggle, onMode, onUnsave, onChange, share, connected, saving }) {
  const { t } = useI18n();
  const [openFav, setOpenFav] = useState(favoriteIps > 0);
  const hasFav = favoriteIps > 0;

  const mode = settings.mode || 'proxy';
  /* فقط وقتی هشدار می‌دهیم که میزبان قطعاً گفته باشد مدیر نیستیم؛ تا وقتی پاسخ
     نرسیده (null) ساکت می‌مانیم تا بی‌دلیل نترسانیم. */
  const blocked = mode === 'tun' && elevated === false;

  return (
    <fieldset className="prefs" disabled={saving} aria-busy={saving}>
      <h1 className="prefs-title">{t('set.title')}</h1>
      {connected && <p className="pref-foot settings-notice">{t('set.nextConnection')}</p>}

      <div className="pref-group">
        <Pref title={t('acc.language')}><LanguagePicker /></Pref>
      </div>

      <div className="pref-group">
        <div className="pref pref-stack">
          <span className="pref-text">
            <b>{t('set.mode')}</b>
            <span>{t(blocked ? 'set.modeNeedsAdmin' : 'set.modeSub')}</span>
          </span>
          <Segment
            gooId="vyrax-seg-mode"
            value={mode}
            onChange={onMode}
            options={[
              { id: 'proxy', label: t('set.modeProxy') },
              { id: 'tun', label: t('set.modeTun') }
            ]}
          />
        </div>
      </div>

      <div className="pref-group">
        {TOP.map(([key, title, desc]) => (
          <Pref key={key} title={t(title)} desc={t(desc)}>
            <Toggle on={!!settings[key]} label={t(title)} onClick={() => onToggle(key)} />
          </Pref>
        ))}
      </div>

      <div className={`pref-group ${openFav ? 'open' : ''}`}>
        <button
          type="button"
          className="pref"
          onClick={() => setOpenFav((v) => !v)}
          aria-expanded={openFav}
        >
          <span className="pref-text">
            <b>{t('set.favouriteIps')}</b>
            <span>{t(hasFav ? 'set.favouriteIpsSet' : 'set.favouriteIpsSub')}</span>
          </span>
          <span className="pref-count">{favoriteIps}</span>
          <ChevronRight className="caret" />
        </button>

        {openFav && saved && (
          <div className="pref-body">
            <div className="fav-ip">
              <span className="meta">
                <b>{saved.name}</b>
                <span>server {saved.ip}</span>
              </span>
              <code>{saved.exit}</code>
              <button
                type="button"
                className="star on"
                onClick={onUnsave}
                aria-label={t('home.starRemove')}
              >
                <Star size={16} />
              </button>
            </div>
            <p className="pref-foot">{t('set.favHint')}</p>
          </div>
        )}
      </div>

      <RoutePref settings={settings} settingKey="splitTunneling" listKey="splitAddresses" opposite="bypassSites" title="set.split" desc="set.splitSub" onChange={onChange} />
      <RoutePref settings={settings} settingKey="bypassSites" listKey="bypassAddresses" opposite="splitTunneling" title="set.bypass" desc="set.bypassSub" onChange={onChange} />
      <div className="pref-group">
        <Pref title={t('set.proxyShare')} desc={t('set.proxyShareSub')}>
          <Toggle on={!!settings.proxyShare} label={t('set.proxyShare')} onClick={() => onToggle('proxyShare')} />
        </Pref>
        {(settings.proxyShare || share) && <div className="pref-body">
          {share ? <>
            <p className="pref-foot">{t('set.shareInstructions')}</p>
            {(share.hosts || []).map(host => <code className="share-address" key={host}>{host}:{share.port}</code>)}
          </> : <p className="pref-foot">{t('set.shareConnect')}</p>}
          <p className="pref-foot">{t('set.sharePrivate')}</p>
        </div>}
      </div>
    </fieldset>
  );
}
