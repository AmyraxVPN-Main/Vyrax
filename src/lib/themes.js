/* فهرست تم‌ها برای انتخابگر.
   قانون: هر نمونهٔ رنگ باید همان چیزی را نشان دهد که کاربر واقعاً می‌گیرد، پس از
   خودِ themes.css خوانده می‌شود — `bg` = `--bg` و `a`/`b` = `--teal`/`--green`.
   (قبلاً `bg` اشتباهاً از `--liquid` پر می‌شد، یعنی رنگ پنل به‌جای رنگ پس‌زمینه،
   و همین باعث شد همهٔ نمونه‌ها رنگ غلط نشان بدهند. رنگ واقعی صفحه از themes.css
   می‌آید؛ این‌ها فقط برای پیش‌نمایش دکمه‌اند.) */
export const THEMES = [
  { id: 'dark', bg: '#0a0f11', a: '#1ecab7', b: '#52d887' },
  { id: 'crimson', bg: '#0a0708', a: '#ff3b4f', b: '#ff7a59' },
  { id: 'black', bg: '#000000', a: '#ffffff', b: '#d9d9d9' },
  { id: 'ocean', bg: '#060a12', a: '#3b9bff', b: '#22d3ee' },
  { id: 'violet', bg: '#0b0911', a: '#a371f7', b: '#d58cff' },
  { id: 'gold', bg: '#0a0906', a: '#e8b931', b: '#ffd166' },
  { id: 'rose', bg: '#0f090c', a: '#ff5c8a', b: '#ff8fab' },
  { id: 'light', bg: '#edf3f1', a: '#0eb09f', b: '#36bf6a' }
];

export const DEFAULT_THEME = 'dark';

export function themeMeta(id) {
  return THEMES.find((t) => t.id === id) || THEMES[0];
}
