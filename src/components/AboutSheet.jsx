import React, { useEffect, useRef, useState } from 'react';
import { ArrowUpRight, Check, Code2, Github, RefreshCw, Send, X } from 'lucide-react';
import { version } from '../../package.json';
import license from '../../LICENSE?raw';
import notices from '../../THIRD_PARTY_NOTICES.md?raw';
import { useI18n } from '../i18n.jsx';
import { links, project } from '../lib/project.js';

export default function AboutSheet({ onClose, onLink, updates }) {
  const { t } = useI18n();
  const [licenses, setLicenses] = useState(false);
  const [asked, setAsked] = useState(false);
  const dialog = useRef(null);
  useEffect(() => {
    const previous = document.activeElement;
    dialog.current?.querySelector('button')?.focus();
    return () => previous?.focus();
  }, []);
  function keyboard(e) {
    if (e.key === 'Escape') { e.preventDefault();onClose(); }
    if (e.key !== 'Tab') return;
    const items = [...dialog.current.querySelectorAll('button:not(:disabled), a[href], textarea, [tabindex="0"]')];
    if (e.shiftKey && document.activeElement === items[0]) { e.preventDefault();items.at(-1)?.focus(); }
    else if (!e.shiftKey && document.activeElement === items.at(-1)) { e.preventDefault();items[0]?.focus(); }
  }
  const link = (target, icon, title, detail) => <a className="about-link" href={links[target]} onClick={e => { e.preventDefault();onLink(target); }}>
    {icon}<span><b>{title}</b><small><bdi>{detail}</bdi></small></span><ArrowUpRight size={16} />
  </a>;
  return <div className="sheet-backdrop" onClick={onClose} role="presentation">
    <section className="sheet about-sheet" ref={dialog} role="dialog" aria-modal="true" aria-label={t('acc.about')} onClick={e => e.stopPropagation()} onKeyDown={keyboard}>
      <b className="sheet-title">{t('acc.about')}</b>
      <button className="sheet-close" aria-label={t('win.close')} onClick={onClose}><X size={16} /></button>
      <div className="about-body">
        <div className="about-brand"><div className="avatar brand-avatar" aria-hidden="true"><span /></div><b>Vyrax</b><small dir="ltr">v{version}</small></div>
        <p className="about-description">{t('about.free')}</p>
        <p className="about-copyright"><bdi>© {project.copyrightYear} {project.author} · {project.license}</bdi></p>
        {link('telegram', <Send size={18} />, t('about.telegram'), '@AmyraxVPN')}
        {link('source', <Github size={18} />, t('about.source'), project.repository)}
        <button className="about-link about-check" disabled={updates.status === 'checking'} onClick={() => { setAsked(true);void updates.check(); }}>
          <RefreshCw size={18} className={updates.status === 'checking' ? 'rotating' : ''} /><span><b>{t(updates.status === 'checking' ? 'update.checking' : 'update.check')}</b></span>
        </button>
        {asked && updates.status === 'current' && <p className="about-update-status"><Check size={14} />{t('update.current')}</p>}
        {asked && updates.status === 'unavailable' && <p className="about-update-status">{t('update.unavailable')}</p>}
        {updates.release && <button className="sheet-btn primary about-release" onClick={() => onLink('release')}><ArrowUpRight size={15} />{t('update.view', { version:updates.release.version })}</button>}
        <button className="about-license-toggle" aria-expanded={licenses} onClick={() => setLicenses(value => !value)}><Code2 size={14} />{t('about.licenses')}</button>
        {licenses && <div className="about-licenses"><pre tabIndex={0}>{license}</pre><pre tabIndex={0}>{notices}</pre></div>}
      </div>
    </section>
  </div>;
}
