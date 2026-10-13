import { useCallback, useEffect, useRef, useState } from 'react';
import { version } from '../../package.json';
import { call, native } from '../bridge.js';
import { project } from './project.js';
import { availableRelease, publishedRelease, shouldNotify } from './releases.mjs';

const dismissalKey = `vyrax-dismissed-update:${project.repository}`;
const readDismissal = () => { try { return localStorage.getItem(dismissalKey) || ''; } catch { return ''; } };

async function latestRelease() {
  if (native) return (await call('checkUpdates', {}, { timeout:15000 })).release;
  const controller = new AbortController();
  const deadline = setTimeout(() => controller.abort(), 12000);
  try {
    const response = await fetch(`https://api.github.com/repos/${project.repository}/releases/latest`, {
      signal:controller.signal, credentials:'omit', headers:{ Accept:'application/vnd.github+json' }
    });
    if (response.status === 404) return null;
    if (!response.ok) throw new Error('Update check unavailable');
    const text = await response.text();
    if (text.length > 262144) throw new Error('Update response too large');
    return JSON.parse(text);
  } finally { clearTimeout(deadline); }
}

export default function useUpdates(enabled) {
  const [release, setRelease] = useState(null);
  const [status, setStatus] = useState('idle');
  const [dismissed, setDismissed] = useState(readDismissal);
  const pending = useRef(null);
  const mounted = useRef(false);

  const check = useCallback(() => {
    if (pending.current) return pending.current;
    setStatus('checking');
    const request = latestRelease().then(data => {
      // Malformed data is an unavailable check, not proof that the app is current.
      if (data && !publishedRelease(data, project.repository))
        throw new Error('Invalid stable release');
      const found = availableRelease(data, version, project.repository);
      if (mounted.current) { setRelease(found);setStatus(found ? 'available' : 'current'); }
      return found;
    }).catch(() => { if (mounted.current) setStatus('unavailable');return null; })
      .finally(() => { pending.current = null; });
    pending.current = request;
    return request;
  }, []);

  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; };
  }, []);
  useEffect(() => {
    if (!enabled) return;
    const first = setTimeout(() => { void check(); }, 6000);
    const repeat = setInterval(() => { if (document.visibilityState === 'visible') void check(); }, 12 * 60 * 60 * 1000);
    return () => { clearTimeout(first);clearInterval(repeat); };
  }, [enabled, check]);

  function dismiss() {
    if (!release) return;
    setDismissed(release.version);
    try { localStorage.setItem(dismissalKey, release.version); } catch { /* In-memory dismissal still works. */ }
  }
  return { release, notice:shouldNotify(release, dismissed) ? release : null, status, check, dismiss };
}
