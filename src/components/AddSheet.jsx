import React, { useEffect, useRef, useState } from 'react';
import { ClipboardPaste, FileUp, X } from './Glyph.jsx';
import { useI18n } from '../i18n.jsx';

export default function AddSheet({ onClose, onAdd, onClipboard, onFile, busy, error }) {
  const { t } = useI18n();
  const [text, setText] = useState('');
  const [name, setName] = useState('');
  const dialog = useRef(null);
  useEffect(() => {
    const previous = document.activeElement;
    dialog.current?.querySelector('textarea')?.focus();
    return () => previous?.focus();
  }, []);

  function onKeyDown(e) {
    if (e.key === 'Escape') { e.preventDefault(); if (!busy) onClose(); }
    if (e.key !== 'Tab') return;
    const items = [...dialog.current.querySelectorAll('button:not(:disabled), input:not(:disabled), textarea:not(:disabled)')];
    const first = items[0], last = items[items.length - 1];
    if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last?.focus(); }
    else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first?.focus(); }
  }

  return (
    <div className="sheet-backdrop" onClick={() => { if (!busy) onClose(); }} role="presentation">
      <div
        ref={dialog}
        className="sheet"
        onClick={(e) => e.stopPropagation()}
        onKeyDown={onKeyDown}
        role="dialog"
        aria-modal="true"
        aria-label={t('add.title')}
      >
        <span className="sheet-grip" aria-hidden="true" />
        <b className="sheet-title">{t('add.title')}</b>
        <button type="button" className="sheet-close" aria-label={t('win.close')} disabled={busy} onClick={onClose}><X size={16} /></button>

        <label className="import-name">
          <span>{t('add.groupName')}</span>
          <input value={name} onChange={e => setName(e.target.value)} maxLength={100} disabled={busy} placeholder={t('add.groupNameHint')} autoComplete="off" />
        </label>
        <textarea
          className="sheet-area"
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder={t('add.placeholder')}
          aria-label={t('add.title')}
          spellCheck={false}
          disabled={busy}
        />

        {error && <p className="sheet-error">{error}</p>}

        <div className="sheet-actions">
          <button type="button" className="sheet-btn" disabled={busy} onClick={() => onClipboard(name)}>
            <ClipboardPaste size={15} />
            {t('add.paste')}
          </button>
          <button type="button" className="sheet-btn" disabled={busy} onClick={() => onFile(name)}>
            <FileUp size={15} />
            {t('add.file')}
          </button>
          <button
            type="button"
            className="sheet-btn primary"
            disabled={busy || !text.trim()}
            onClick={() => onAdd(text, name)}
          >
            {busy ? t('add.working') : t('add.confirm')}
          </button>
        </div>

        <p className="sheet-hint">{t('add.hint')}</p>
      </div>
    </div>
  );
}
