// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import React from 'react';
import { useI18n } from '../i18n.jsx';
export default function Segment({ options,value,onChange }) {
  const { lang }=useI18n(),index=Math.max(0,options.findIndex(option=>option.id===value));
  return <div className="material-segment" role="group" dir={lang==='fa'?'rtl':'ltr'} style={{'--segments':options.length,'--segment-index':lang==='fa'?options.length-1-index:index}}><span className="material-segment-highlight" aria-hidden="true"/>{options.map(option=><button key={option.id} type="button" aria-pressed={value===option.id} onClick={()=>onChange(option.id)}>{option.label}</button>)}</div>;
}
