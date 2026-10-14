import React, { useEffect, useState } from 'react';
import { Languages, Info } from '../components/Glyph.jsx';
import { useI18n, LANGS } from '../i18n.jsx';
import { Swatch } from '../components/ThemeSheet.jsx';
import { THEMES } from '../lib/themes.js';
import { version } from '../../package.json';

export default function Account({ theme, servers, favourites, onTheme, onClear, onAbout }) {
  const { t, lang, setLang } = useI18n();
  const [arming, setArming] = useState(false);

  const current = LANGS.find((l) => l.id === lang) || LANGS[0];
  const next = LANGS[(LANGS.indexOf(current) + 1) % LANGS.length];

  /* تأیید دو مرحله‌ای، تا حذف همه تصادفی نشود */
  useEffect(() => {
    if (!arming) return;
    const timer = setTimeout(() => setArming(false), 4000);
    return () => clearTimeout(timer);
  }, [arming]);

  return (
    <div className="account">
      <div className="avatar brand-avatar" aria-hidden="true"><span /></div>
      <h1 className="acct-name">Vyrax</h1>

      <div className="acct-stats">
        <div>
          <b>{servers}</b>
          <span>{t('acc.servers')}</span>
        </div>
        <div>
          <b>{favourites}</b>
          <span>{t('acc.favourites')}</span>
        </div>
      </div>

      <div className="setting">
        <span className="meta">
          <b>{t('acc.appearance')}</b>
          <span>{`${t('acc.themes')} · ${t(`theme.${theme}`)}`}</span>
        </span>
        <div className="themes" role="radiogroup" aria-label={t('acc.appearance')}>
          {THEMES.map((th) => <button key={th.id} type="button" className={`theme-pick ${theme === th.id ? 'on' : ''}`}
            role="radio" aria-checked={theme === th.id} aria-label={t(`theme.${th.id}`)} title={t(`theme.${th.id}`)}
            onClick={() => onTheme(th.id)}><Swatch theme={th} /></button>)}
        </div>
      </div>

      <button
        type="button"
        className="setting"
        onClick={() => setLang(next.id)}
        aria-label={t('acc.language')}
      >
        <span className="meta">
          <b>{t('acc.language')}</b>
          <span>{current.label}</span>
        </span>
        <Languages size={17} color="var(--muted)" />
      </button>

      <button type="button" className="setting" onClick={onAbout}>
        <span className="meta">
          <b>{t('acc.about')}</b>
          <span>{t('acc.aboutSub')}</span>
        </span>
        <Info size={17} color="var(--muted)" />
      </button>

      {servers > 0 && (
        <button
          type="button"
          className={`pill-danger ${arming ? 'arming' : ''}`}
          onClick={() => {
            if (arming) {
              setArming(false);
              onClear();
            } else {
              setArming(true);
            }
          }}
        >
          {arming ? t('acc.clearSub') : t('acc.clear')}
        </button>
      )}
      <p className="version">vyrax {version}</p>
    </div>
  );
}
