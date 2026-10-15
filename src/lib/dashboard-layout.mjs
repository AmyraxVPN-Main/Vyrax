// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
export function dashboardMetrics(availableWidth) {
  const width = Math.max(0,Math.min(1120,Number(availableWidth)||0));
  const progress = Math.max(0,Math.min(1,(width-600)/520));
  return { columns:width < 480 ? 2 : width <= 840 ? 3 : 4,
    unit:80+40*progress,inset:16+6*progress,vertical:14+8*progress,radius:20+10*progress,textScale:1+.15*progress };
}
// Interpolate matching polygons instead of fading between two unrelated icons.
// Both pieces share an edge at rest; on activation they turn into pause bars.
export function connectionSymbol(progress) {
  const fold = Math.max(0,Math.min(1,progress)),angle=progress*Math.PI/2;
  const from=[[[8,6],[18,12],[18,12],[8,12]],[[8,12],[18,12],[18,12],[8,18]]];
  const to=[[[6,7],[18,7],[18,9.5],[6,9.5]],[[6,14.5],[18,14.5],[18,17],[6,17]]];
  return from.map((piece,j) => piece.map(([x,y],i) => {
    const a=x+(to[j][i][0]-x)*fold-12,b=y+(to[j][i][1]-y)*fold-12;
    return `${(12+a*Math.cos(angle)-b*Math.sin(angle)).toFixed(3)},${(12+a*Math.sin(angle)+b*Math.cos(angle)).toFixed(3)}`;
  }).join(' '));
}
