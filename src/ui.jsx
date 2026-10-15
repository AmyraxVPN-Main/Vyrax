import React from 'react';
import { ChevronRight } from './components/Glyph.jsx';

/* رنگ عدد بر پایهٔ کیفیت تأخیر */
export function speedClass(ms) {
  if (ms === null || ms === undefined) return '';
  if (ms <= 150) return 'good';
  if (ms <= 320) return 'warn';
  return 'bad';
}

/* `failed` یعنی تست انجام شد و سرور جواب نداد — با «تست‌نشده» یکی نیست */
export function MsTag({ value, failed = false }) {
  const missing = value === null || value === undefined;
  const cls = failed ? 'bad' : speedClass(value);
  return (
    <span className={`ms-tag ${cls}`}>
      {failed ? 'Timeout' : missing ? '--' : `${value} ms`}
    </span>
  );
}

export function Chevron() {
  return <ChevronRight size={15} className="chev" strokeWidth={2.2} />;
}

/* کلید کشویی: شیارِ چسبناک با گرهی که سُر می‌خورد */
export function Toggle({ on, onClick, label, disabled = false }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={on}
      aria-label={label}
      disabled={disabled}
      className={`material-switch ${on ? 'on' : ''}`}
      onClick={onClick}
    >
      <span aria-hidden="true"/>
    </button>
  );
}
