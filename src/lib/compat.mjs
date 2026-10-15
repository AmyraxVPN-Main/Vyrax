// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
// Android 10's original WebView exposes getRandomValues but not randomUUID.
export function randomUUID(cryptoSource = globalThis.crypto) {
  const b=cryptoSource.getRandomValues(new Uint8Array(16));b[6]=(b[6]&15)|64;b[8]=(b[8]&63)|128;
  const h=Array.from(b,v=>v.toString(16).padStart(2,'0'));
  return h.slice(0,4).join('')+'-'+h.slice(4,6).join('')+'-'+h.slice(6,8).join('')+'-'+h.slice(8,10).join('')+'-'+h.slice(10).join('');
}
if (globalThis.crypto && !globalThis.crypto.randomUUID) Object.defineProperty(globalThis.crypto,'randomUUID',{value:()=>randomUUID()});
if (globalThis.document?.body) {
  const probe=document.createElement('div');probe.style.cssText='position:absolute;display:flex;flex-direction:column;row-gap:1px;visibility:hidden';
  probe.append(document.createElement('div'),document.createElement('div'));document.body.append(probe);
  document.documentElement.dataset.flexGap=probe.scrollHeight===1?'yes':'no';probe.remove();
}
