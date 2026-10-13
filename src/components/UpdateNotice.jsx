import React from 'react';
import { ArrowUpRight, Sparkles, X } from 'lucide-react';
import { useI18n } from '../i18n.jsx';

export default function UpdateNotice({ release, onOpen, onDismiss }) {
  const { t } = useI18n();
  if (!release) return null;
  return <aside className="update-notice" role="status" aria-live="polite">
    <Sparkles size={16} aria-hidden="true" />
    <button className="update-open" onClick={onOpen}>
      <span>{t('update.available')} <bdi className="update-version">v{release.version}</bdi></span>
      <ArrowUpRight size={15} aria-hidden="true" />
    </button>
    <button className="update-dismiss" aria-label={t('update.dismiss')} onClick={onDismiss}><X size={14} /></button>
  </aside>;
}
