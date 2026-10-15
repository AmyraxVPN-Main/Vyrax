import React from 'react';
import { Check } from './Glyph.jsx';
import { useI18n } from '../i18n.jsx';
import { THEMES } from '../lib/themes.js';

export function Swatch({ theme, size = 26 }) {
  return (
    <span
      className="swatch"
      style={{
        '--sw-bg': theme.bg,
        '--sw-a': theme.a,
        '--sw-b': theme.b,
        width: size,
        height: size
      }}
      aria-hidden="true"
    />
  );
}

export default function ThemeSheet({ current, onPick, onClose }) {
  const { t } = useI18n();

  return (
    <div className="sheet-backdrop" onClick={onClose} role="presentation">
      <div
        className="sheet"
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-label={t('theme.title')}
      >
        <span className="sheet-grip" aria-hidden="true" />
        <b className="sheet-title">{t('theme.title')}</b>

        <div className="sheet-list">
          {THEMES.map((th) => (
            <button
              key={th.id}
              type="button"
              className={`sheet-opt ${current === th.id ? 'on' : ''}`}
              onClick={() => onPick(th.id)}
            >
              <Swatch theme={th} />
              <span className="sheet-label">{t(`theme.${th.id}`)}</span>
              {current === th.id && <Check size={15} className="sheet-tick" />}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
