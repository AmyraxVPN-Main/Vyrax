// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
export function createConnectionActions({ transport, dispatch, onSnapshot = () => {}, onConnected = () => {},
  onError = () => {}, setTimer = setTimeout, clearTimer = clearTimeout }) {
  let generation = 0, wanted = null, pendingKind = '', deadline = null, active = false;
  function clearDeadline() { if (deadline !== null) clearTimer(deadline);deadline = null; }
  function accept(data) {
    if (!active) return false;
    if (!data || !['connected','connecting','disconnected'].includes(data.status)) return false;
    if (wanted === false && ['connected','connecting'].includes(data.status)) return false;
    if (pendingKind === 'connect' && data.status === 'disconnected' && !data.message) return false;
    if (data.status === 'connected') clearDeadline();
    dispatch({ type:'snapshot',data });onSnapshot(data);return true;
  }
  async function disconnect() {
    if (!active || pendingKind === 'disconnect') return;
    const current = ++generation;wanted = false;pendingKind = 'disconnect';clearDeadline();
    dispatch({ type:'stopping' });
    try {
      const result = await transport('disconnect');
      if (!active || current !== generation) return;
      if (result?.status && result.status !== 'disconnected') throw Error('err.coreStopped');
      dispatch({ type:'snapshot',data:result?.status ? result : { status:'disconnected' } });onSnapshot(result || {});return true;
    } catch (error) {
      if (!active || current !== generation) return;
      // Reconcile with the host instead of claiming the VPN stopped on failure.
      try { const result = await transport('status');if (active && current === generation) {
        wanted = ['connected','connecting'].includes(result.status);dispatch({ type:'snapshot',data:result });onSnapshot(result);
      } } catch { if (active && current === generation) {
        wanted = null;dispatch({ type:'patch',update:s => ({ ...s,disconnecting:false }) });
      } }
      if (active && current === generation) onError(error);return false;
    } finally { if (current === generation) pendingKind = ''; }
  }
  async function connect(profile, settings, routing) {
    if (!active || pendingKind) return;
    const current = ++generation;wanted = true;pendingKind = 'connect';dispatch({ type:'begin' });
    const mode = settings.mode || 'proxy';
    clearDeadline();deadline = setTimer(() => {
      if (!active || current !== generation) return;
      onError(Error('err.timeout'));void disconnect();
    }, mode === 'tun' ? 200000 : 45000);
    try {
      const result = await transport('connect', { profile,mode,mtu:settings.mtu || 1280,
        settings:{ ...settings,_catalog:routing.catalog,_selection:routing.selectionMode,_source:routing.source } },
        { timeout:mode === 'tun' ? 240000 : 60000 });
      if (!active || current !== generation) return;
      clearDeadline();pendingKind = '';accept(result || { status:'disconnected' });
      if (result?.status === 'connected') onConnected(profile);
    } catch (error) {
      if (!active || current !== generation) return;
      wanted = false;pendingKind = '';clearDeadline();dispatch({ type:'snapshot',data:{ status:'disconnected' } });onError(error);
    } finally { if (current === generation) pendingKind = ''; }
  }
  function toggle(profile, settings, routing, state) {
    if (pendingKind === 'disconnect' || state.disconnecting) return;
    if (pendingKind === 'connect' || state.connecting || state.connected) return disconnect();
    if (profile) return connect(profile, settings, routing);
  }
  return { connect, disconnect, toggle, receive:accept,
    revision:() => generation,
    isCurrent:revision => active && revision === generation,
    isBusy:() => !!pendingKind,
    start() { active = true; },
    dispose() { active = false;generation++;clearDeadline();pendingKind = ''; } };
}
