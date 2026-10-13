// لایهٔ گفت‌وگو با میزبان.
// یک رابط مشترک روی سه بستر: Tauri (Rust)، WebView2 (هاست C#)، و مرورگر (فقط پیش‌نمایش).
// همان الگویی که اپ مرجع هم استفاده می‌کند: UI یکی است، شل عوض می‌شود.

const tauri = typeof window !== 'undefined' ? window.__TAURI__ : null;
const webview2 =
  typeof window !== 'undefined' ? window.chrome?.webview ?? null : null;

export const platform = tauri ? 'tauri' : webview2 ? 'webview2' : 'browser';
export const native = platform !== 'browser';

const listeners = new Set();
const pending = new Map();
let sequence = 0;

/* ---------- WebView2: پروتکل postMessage ---------- */
if (webview2) {
  webview2.addEventListener('message', ({ data }) => {
    if (data.event) {
      listeners.forEach((fn) => fn(data));
      return;
    }
    const item = pending.get(data.id);
    if (!item) return;
    clearTimeout(item.timer);
    pending.delete(data.id);
    data.error ? item.reject(new Error(data.error)) : item.resolve(data.result);
  });
}

/* ---------- Tauri: رویدادها ---------- */
if (tauri?.event?.listen) {
  tauri.event.listen('vyrax://event', (e) => {
    listeners.forEach((fn) => fn(e.payload));
  });
}

function callWebview2(action, args, timeout) {
  return new Promise((resolve, reject) => {
    const id = ++sequence;
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error('TIMEOUT'));
    }, timeout || 45000);
    pending.set(id, { resolve, reject, timer });
    webview2.postMessage({ id, action, args });
  });
}

function callTauri(action, args) {
  return tauri.core.invoke(action, args);
}

export function call(action, args = {}, options = {}) {
  if (platform === 'webview2') return callWebview2(action, args, options.timeout);
  if (platform === 'tauri') return callTauri(action, args);
  return Promise.reject(new Error('NO_NATIVE'));
}

export function subscribe(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}
