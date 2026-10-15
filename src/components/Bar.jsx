import React, { useState } from 'react';
import { Minus, Square, X, Pin } from 'lucide-react';
import { call, native, mobile } from '../bridge.js';
import { useI18n } from '../i18n.jsx';

export default function Bar({ live }) {
  const { t } = useI18n();
  const [pinned,setPinned]=useState(false);

  const send = (action) => {
    if (native) call(action).catch(() => {});
  };

  return (
    <header className="bar" onPointerDown={(e) => {
      if (native && !mobile && e.button === 0 && !e.target.closest('button')) send('drag');
    }} onDoubleClick={e => { if (native && !mobile && !e.target.closest('button')) send('maximize'); }}>
      <span className="sr-only">Vyrax</span>
      {!mobile && <div className="bar-btns">
        <button type="button" className="bar-btn" aria-label={t('dash.pin')} aria-pressed={pinned} onClick={async()=>{try{if(native)await call('pin',{value:!pinned});setPinned(!pinned);}catch{}}}><Pin size={14} fill={pinned?'currentColor':'none'} strokeWidth={1.5}/></button>
        <button
          type="button"
          className="bar-btn"
          aria-label={t('win.minimize')}
          onClick={() => send('minimize')}
        >
          <Minus size={13} strokeWidth={2.2} />
        </button>
        <button type="button" className="bar-btn" aria-label={t('dash.maximize')} onClick={() => send('maximize')}><Square size={11} strokeWidth={1.8}/></button>
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
