import { useCallback, useEffect, useRef, useState } from 'react';
import { version } from '../../package.json';
import { call, native } from '../bridge.js';
import { project } from './project.js';
import { availableRelease, publishedRelease, shouldNotify } from './releases.mjs';
import { createUpdateChecker } from './update-checker.mjs';

const dismissalKey = `vyrax-dismissed-update:${project.repository}`;
const readDismissal = () => { try { return localStorage.getItem(dismissalKey) || ''; } catch { return ''; } };

async function latestRelease() {
  if (native) return (await call('checkUpdates', {}, { timeout:15000 })).release;
  const controller = new AbortController();
  const deadline = setTimeout(() => controller.abort(), 12000);
  try {
    const response = await fetch(`https://api.github.com/repos/${project.repository}/releases/latest`, {
      signal:controller.signal, credentials:'omit', cache:'no-store', headers:{ Accept:'application/vnd.github+json' }
    });
    if (response.status === 404) return null;
    if (!response.ok) throw new Error('Update check unavailable');
    const text = await response.text();
    if (text.length > 262144) throw new Error('Update response too large');
    return JSON.parse(text);
  } finally { clearTimeout(deadline); }
}

export default function useUpdates(enabled = true) {
  const [release, setRelease] = useState(null);
  const [status, setStatus] = useState('idle');
  const [dismissed, setDismissed] = useState(readDismissal);
  const checker = useRef(null);
  if (!checker.current) {
    checker.current = createUpdateChecker({
      request:async () => {
        const data = await latestRelease();
        // Malformed data is unavailable, not proof that the app is current.
        if (data && !publishedRelease(data, project.repository))
          throw new Error('Invalid stable release');
        return availableRelease(data, version, project.repository);
      },
      onRelease:setRelease, onStatus:setStatus
    });
  }
  const check = useCallback(() => checker.current.check(), []);
  useEffect(() => {
    if (!enabled) return;
    checker.current.start();
    return () => checker.current.stop();
  }, [enabled]);

  function dismiss() {
    if (!release) return;
    setDismissed(release.version);
    try { localStorage.setItem(dismissalKey, release.version); } catch { /* In-memory dismissal still works. */ }
  }
  return { release, notice:shouldNotify(release, dismissed) ? release : null, status, check, dismiss };
}
