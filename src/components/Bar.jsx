import React from 'react';
import { Minus, X } from 'lucide-react';
import { call, native, mobile } from '../bridge.js';
import { useI18n } from '../i18n.jsx';

export default function Bar({ live }) {
  const { t } = useI18n();

  const send = (action) => {
    if (native) call(action).catch(() => {});
  };

  return (
    <header className="bar" onPointerDown={(e) => {
      if (native && !mobile && e.button === 0 && !e.target.closest('button')) send('drag');
    }}>
      <span className="mark">
        <span className="ico" aria-hidden="true" />
        vyrax
      </span>
      {!mobile && <div className="bar-btns">
        <button
          type="button"
          className="bar-btn"
          aria-label={t('win.minimize')}
          onClick={() => send('minimize')}
        >
          <Minus size={13} strokeWidth={2.2} />
        </button>
        <button
          type="button"
          className="bar-btn close"
          aria-label={t('win.close')}
          onClick={() => send('close')}
        >
          <X size={13} strokeWidth={2.2} />
        </button>
      </div>}
    </header>
  );
}
