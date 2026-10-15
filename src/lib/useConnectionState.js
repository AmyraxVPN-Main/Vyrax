// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import { useCallback, useEffect, useReducer } from 'react';
import { connectionReducer, normalizeConnection } from './connection-state.mjs';

export default function useConnectionState(initial) {
  const [state, dispatch] = useReducer(connectionReducer, initial, value => normalizeConnection({}, value));
  const setState = useCallback(update => dispatch({ type:'patch',update }), []);
  useEffect(() => {
    if (!state.connected) return;
    const tick = () => dispatch({ type:'tick' });
    const timer = setInterval(tick, 1000);
    document.addEventListener('visibilitychange', tick);
    return () => { clearInterval(timer);document.removeEventListener('visibilitychange', tick); };
  }, [state.connected]);
  return [state, setState, dispatch];
}
