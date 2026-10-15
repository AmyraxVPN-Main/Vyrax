import snapshot from './free-locations.json' with { type:'json' };
import { FREE_SOURCE, parseFreeServers } from './free-servers.mjs';

export const FREE_CATALOG_VERSION = 1;

// Upgrade the previously truncated catalog before the native host auto-connects.
// Public Mozilla Remote Settings snapshot, fetched 2026-10-15 without credentials.
// This is a one-time offline migration; later live refreshes keep their own data.
export function upgradeSavedFreeCatalog(saved) {
  const sub = saved.subscriptions?.find(item => item.id === FREE_SOURCE && item.kind === 'firefox');
  if (!sub || sub.catalogVersion >= FREE_CATALOG_VERSION) return saved;
  const previous = saved.profiles || [], incoming = parseFreeServers(snapshot, previous);
  const selected = previous.find(profile => profile.id === saved.selectedId);
  const selectionRemoved = selected?.sourceId === FREE_SOURCE && !incoming.some(profile => profile.id === selected.id);
  return {
    ...saved,
    profiles:previous.filter(profile => profile.sourceId !== FREE_SOURCE).concat(incoming),
    subscriptions:saved.subscriptions.map(item => item === sub ? { ...item,catalogVersion:FREE_CATALOG_VERSION } : item),
    selectedId:selectionRemoved ? incoming[0].id : saved.selectedId
  };
}
