// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
// Preserve the Material palette on older WebView/Safari without color-mix().
export function themeFallbackColors(colors) {
  const rgb=value=>{const hex=value.trim().replace(/^#/,'');return [0,2,4].map(i=>parseInt(hex.slice(i,i+2),16));};
  const mix=(a,b,weight)=>`rgb(${rgb(a).map((n,i)=>Math.round(n*weight+rgb(b)[i]*(1-weight))).join(', ')})`;
  return {
    '--card-border':`rgba(${rgb(colors.text).join(', ')}, 0.13)`,
    '--nav-active':mix(colors.text,colors.liquid,.08),
    '--window-bar':mix(colors.text,colors.liquid,.1),
    '--secondary-fill':mix(colors.text,colors.liquid,.18),
    '--switch-active':mix(colors.teal,'#ffffff',.6),
    '--selection-warm':mix(colors.warn,colors.liquid,.18),
    '--selection-green':mix(colors.green,colors.liquid,.18),
    '--donut-track':mix(colors.text,colors.liquid,.12)
  };
}
export function applyThemeFallback(root) {
  if (globalThis.CSS?.supports('color','color-mix(in srgb, black, white)')) return;
  const style=getComputedStyle(root),colors={};
  for (const name of ['text','liquid','teal','warn','green']) colors[name]=style.getPropertyValue('--'+name).trim();
  if (!Object.values(colors).every(value=>/^#[0-9a-f]{6}$/i.test(value))) return;
  for (const [name,value] of Object.entries(themeFallbackColors(colors))) root.style.setProperty(name,value);
}
