import React, { useEffect, useRef, useState } from 'react';
import { Check, Copy, QrCode, RefreshCw, Trash2, Plus, X, Gift } from './Glyph.jsx';
import QRCode from 'qrcode';
import { useI18n } from '../i18n.jsx';
import { isLocalSubscription, isFreeSubscription, subscriptionContent } from '../lib/subscriptions.mjs';

const amount = n => `${((Number(n) || 0) / 1073741824).toFixed(2)} GB`;

export default function SubscriptionSheet({ subscriptions, profiles, activeId, onSelect, onRefresh, onDelete, onCopy, onAdd, onFree, onClose, busy, refreshingId }) {
  const { t, lang } = useI18n();
  const dialog = useRef(null);
  const [qr, setQr] = useState(null);
  const [qrError, setQrError] = useState(false);
  const [arming, setArming] = useState('');
  useEffect(() => {
    const previous = document.activeElement;
    return () => previous?.focus();
  }, []);
  useEffect(() => {
    // Switching to QR replaces the clicked control; keep keyboard focus inside
    // the dialog instead of leaving it on the page underneath.
    dialog.current?.querySelector('button:not(:disabled)')?.focus();
  }, [qr]);
  useEffect(() => {
    if (!arming) return;
    const timer = setTimeout(() => setArming(''), 5000);
    return () => clearTimeout(timer);
  }, [arming]);
  async function showQr(sub) {
    setQrError(false);
    try {
      const content = subscriptionContent(sub, profiles);
      setQr({ ...sub, content, image: await QRCode.toDataURL(content, { width: 224, margin: 3, errorCorrectionLevel: 'M' }) });
    }
    catch { setQrError(true); }
  }
  function keyboard(e) {
    if (e.key === 'Escape') { e.preventDefault(); if (qr) setQr(null); else onClose(); }
    if (e.key !== 'Tab') return;
    const items = [...dialog.current.querySelectorAll('button:not(:disabled), input, textarea')].filter(el => el.offsetParent !== null);
    if (e.shiftKey && document.activeElement === items[0]) { e.preventDefault(); items[items.length - 1]?.focus(); }
    else if (!e.shiftKey && document.activeElement === items[items.length - 1]) { e.preventDefault(); items[0]?.focus(); }
  }
  return <div className="sheet-backdrop" onClick={onClose} role="presentation">
    <section className="sheet subscriptions-sheet" role="dialog" aria-modal="true" aria-label={t('sub.title')} ref={dialog} onClick={e => e.stopPropagation()} onKeyDown={keyboard}>
      <b className="sheet-title">{qr ? t('sub.qr') : t('sub.title')}</b>
      <button className="sheet-close" aria-label={t('win.close')} onClick={onClose}><X size={16} /></button>
      {qr ? <div className="qr-share">
        <b>{qr.name}</b><img src={qr.image} width="224" height="224" alt={t('sub.qr')} />
        <textarea value={qr.content} readOnly aria-label={t(isLocalSubscription(qr) ? 'sub.configs' : 'sub.link')} spellCheck={false} />
        <p>{t('sub.qrHint')}</p>
        <div className="sheet-actions"><button className="sheet-btn" onClick={() => setQr(null)}>{t('sub.back')}</button><button className="sheet-btn primary" onClick={() => onCopy(qr)}><Copy size={15} />{t(isLocalSubscription(qr) ? 'sub.copyConfigs' : 'sub.copy')}</button></div>
      </div> : <>
        <p className="sheet-hint">{t('sub.scopeHint')}</p>
        <div className="subscriptions-list">
          {profiles.some(p => !p.sourceId) && <button className={`sub-manual ${!activeId ? 'on' : ''}`} disabled={busy} onClick={() => onSelect('')}><span>{t('sub.manual')}</span>{!activeId && <Check size={16} />}</button>}
          {subscriptions.map(sub => {
            const local = isLocalSubscription(sub);
            const free = isFreeSubscription(sub);
            const count = profiles.filter(p => p.sourceId === sub.id).length;
            const used = (sub.usage?.upload || 0) + (sub.usage?.download || 0);
            const total = sub.usage?.total || 0;
            return <article className={`sub-card ${activeId === sub.id ? 'on' : ''}`} key={sub.id}>
              <button className="sub-select" disabled={busy || !count} onClick={() => onSelect(sub.id)}>
                <b><bdi>{sub.name}</bdi></b>{activeId === sub.id && <Check size={16} />}<small>{t('sub.count', { n: count })}</small>
                {total > 0 && <><span className="sub-usage"><i style={{ width: `${Math.min(100, used / total * 100)}%` }} /></span><small dir="ltr">{amount(used)} / {amount(total)}</small></>}
                {sub.usage?.expire > 0 && <small>{t('sub.expires', { date: new Date(sub.usage.expire * 1000).toLocaleDateString(lang) })}</small>}
                <small>{local ? t('sub.local') : sub.updatedAt ? t('sub.updated', { date: new Date(sub.updatedAt).toLocaleString(lang) }) : t('sub.notUpdated')}</small>
              </button>
              <div className="sub-actions">
                {!local && <button className={refreshingId === sub.id ? 'spin' : ''} disabled={busy} aria-busy={refreshingId === sub.id} aria-label={`${t('sub.refresh')} · ${sub.name}`} onClick={() => onRefresh(sub)}><RefreshCw size={15} /></button>}
                {free?<button onClick={onFree} aria-label={t('free.accounts')}><Gift size={15}/></button>:<><button disabled={!count} aria-label={`${t(local ? 'sub.copyConfigs' : 'sub.copy')} · ${sub.name}`} onClick={() => onCopy(sub)}><Copy size={15} /></button>
                <button disabled={!count} aria-label={`${t('sub.qr')} · ${sub.name}`} onClick={() => showQr(sub)}><QrCode size={15} /></button></>}
                <button className={arming === sub.id ? 'armed' : ''} disabled={busy} aria-label={`${t(arming === sub.id ? 'sub.confirmDelete' : 'sub.delete')} · ${sub.name}`} onClick={() => { if (arming === sub.id) { onDelete(sub); setArming(''); } else setArming(sub.id); }}><Trash2 size={15} />{arming === sub.id && <span>{t('sub.confirmDelete')}</span>}</button>
              </div>
            </article>;
          })}
          {!subscriptions.length && <p className="sub-empty">{t('sub.empty')}</p>}
        </div>
        {qrError && <p className="sheet-error">{t('sub.qrError')}</p>}
        <button className="sheet-btn primary sub-add" disabled={busy} onClick={onAdd}><Plus size={15} />{t('sub.add')}</button>
        <button className="sheet-btn" onClick={onFree}><Gift size={15}/>{t('free.title')}</button>
      </>}
    </section>
  </div>;
}
