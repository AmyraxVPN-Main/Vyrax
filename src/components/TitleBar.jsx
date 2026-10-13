import React from 'react';
import { Minus, X } from 'lucide-react';
import { call, native } from '../bridge.js';
import { useI18n } from '../i18n.jsx';

export default function TitleBar() {
  const { t } = useI18n();

  const send = (action) => {
    if (native) call(action).catch(() => {});
  };

  return (
    <header
      className="titlebar"
      onPointerDown={(e) => {
        /* پنجره قاب ندارد؛ کشیدن را به میزبان می‌سپاریم */
        if (!native || e.button !== 0 || e.target.closest('button')) return;
        call('drag').catch(() => {});
      }}
    >
      <div className="brand">
        <span className="ico" aria-hidden="true" />
        vyrax
      </div>
      <div className="bar-btns">
        <button
          type="button"
          className="bar-btn"
          aria-label={t('win.minimize')}
          onClick={() => send('minimize')}
        >
          <Minus size={14} strokeWidth={2.2} />
        </button>
        <button
          type="button"
          className="bar-btn close"
          aria-label={t('win.close')}
          onClick={() => send('close')}
        >
          <X size={14} strokeWidth={2.2} />
        </button>
      </div>
    </header>
  );
}
