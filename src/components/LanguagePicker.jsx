import React from 'react';
import { LANGS, useI18n } from '../i18n.jsx';

export default function LanguagePicker() {
  const { lang, setLang, t } = useI18n();
  return <div className="language-picker" role="group" aria-label={t('acc.language')}>
    {LANGS.map((item) => <button key={item.id} type="button" lang={item.id}
      className={lang === item.id ? 'on' : ''} aria-pressed={lang === item.id}
      onClick={() => setLang(item.id)}>{item.label}</button>)}
  </div>;
}
