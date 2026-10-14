// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
export function formatBytes(bytes) {
  let value = Number.isFinite(bytes) ? Math.max(0,bytes) : 0, index = 0;
  const units = ['B','KB','MB','GB','TB'];
  while (value >= 1024 && index < units.length - 1) { value /= 1024;index++; }
  return `${index && value < 100 ? value.toFixed(1) : Math.round(value)} ${units[index]}`;
}
export function formatUptime(seconds) {
  const n = Number.isFinite(seconds) ? Math.max(0,Math.floor(seconds)) : 0;
  return [Math.floor(n / 3600),Math.floor(n / 60) % 60,n % 60].map(v => String(v).padStart(2,'0')).join(':');
}
export function trafficPath(samples, width = 320, height = 80) {
  const rate = value => Number.isFinite(value) ? Math.max(0,value) : 0;
  const values = samples.slice(-60).map(p => rate(rate(p.up) + rate(p.down)));
  if (!values.length) return '';
  const max = Math.max(8192,...values), step = width / 59;
  const points = values.map((value,i) => ({ x:(60 - values.length + i) * step,y:height - value / max * (height - 8) }));
  const slopes = points.slice(1).map((p,i) => (p.y - points[i].y) / step);
  // Monotone cubic interpolation rounds the trace without overshooting a peak
  // or drawing negative rates between samples. At most 60 points are retained.
  const tangents = points.map((_,i) => {
    if (i === 0) return slopes[0] || 0;
    if (i === points.length - 1) return slopes.at(-1) || 0;
    const a = slopes[i - 1], b = slopes[i];
    return a * b > 0 ? 2 * a * b / (a + b) : 0;
  });
  const n = value => value.toFixed(2);
  return `M${n(points[0].x)},${n(points[0].y)}` + points.slice(1).map((p,i) => {
    const previous = points[i];
    return ` C${n(previous.x + step / 3)},${n(previous.y + tangents[i] * step / 3)} ${n(p.x - step / 3)},${n(p.y - tangents[i + 1] * step / 3)} ${n(p.x)},${n(p.y)}`;
  }).join('');
}
