import React from 'react';
import { Liquid } from 'liquid-gooey';
import Surface from './Surface.jsx';
import { useI18n } from '../i18n.jsx';

export default function Segment({ options, value, onChange }) {
  const index = Math.max(0, options.findIndex((opt) => opt.id === value));
  const { lang } = useI18n();
  const rtl = lang === 'fa';
  return (
    <div className="seg" dir={rtl ? 'rtl' : 'ltr'}>
      <Surface blur={6} className="seg-track" aria-hidden="true">
        <Surface.Item><div className="seg-bg" /></Surface.Item>
      </Surface>
      <Liquid blur={6} contrast={20} fill="var(--accent-fill)" className="seg-thumb-layer" aria-hidden="true">
        <Liquid.Item effect="move" move={{ springiness: .6, trail: .45 }}>
          <div className="seg-thumb" style={{ width: `${100 / options.length}%`, transform: `translateX(${(rtl ? options.length - 1 - index : index) * 100}%)` }} />
        </Liquid.Item>
      </Liquid>
      {options.map((opt) => (
        <button key={opt.id} type="button" className={`seg-btn ${value === opt.id ? 'on' : ''}`}
          aria-pressed={value === opt.id} onClick={() => onChange(opt.id)}>{opt.label}</button>
      ))}
    </div>
  );
}
