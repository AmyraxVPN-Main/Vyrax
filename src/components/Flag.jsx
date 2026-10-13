import React from 'react';
import { FLAG_CODES } from '../lib/flag-codes.js';

/* ویندوز ایموجی پرچم را رندر نمی‌کند، پس تصویر واقعی لازم است.
   پرچم‌ها به‌صورت فایل جدا در public/flags هستند و فقط وقتی لود می‌شوند که لازم شوند.
   اگر کشور معلوم نباشد، به‌جای پرچم برچسب پروتکل نشان داده می‌شود. */

const BASE = import.meta.env.BASE_URL || './';

export default function Flag({ cc, size = 'md', label, className = '' }) {
  const code = String(cc || '').toLowerCase();
  const cls = `flag ${size === 'md' ? 'flag-md' : ''} ${className}`;

  if (FLAG_CODES.has(code)) {
    return (
      <span
        className={cls}
        style={{ backgroundImage: `url("${BASE}flags/${code}.svg")` }}
        aria-hidden="true"
      />
    );
  }

  if (label) {
    return (
      <span className={`${cls} flag-ph`} aria-hidden="true">
        {label}
      </span>
    );
  }

  return <span className={`${cls} flag-blank`} aria-hidden="true" />;
}
