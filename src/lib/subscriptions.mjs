import { exportProfiles, mergeProfiles, parseImport } from './profiles.mjs';

export const isLocalSubscription = sub => sub?.kind === 'local';
const cleanGroupName = value => String(value || '').replace(/[\x00-\x1f\x7f]/g, '').trim().slice(0, 100);

export function importLocalSubscription(text, profiles, subscriptions, name, t) {
  const result = parseImport(text, t);
  let number = 1;
  while (subscriptions.some(sub => sub.name === t('sub.imported', { n:number }))) number++;
  const sub = { id:crypto.randomUUID(), kind:'local',
    name:cleanGroupName(name) || cleanGroupName(result.profiles.length === 1 ? result.profiles[0].name : '') || t('sub.imported', { n:number }),
    createdAt:new Date().toISOString() };
  return { ...result, subscription:sub, catalog:mergeProfiles(profiles, result.profiles, sub.id) };
}

export function subscriptionContent(sub, profiles) {
  return isLocalSubscription(sub) ? exportProfiles(scopedProfiles(profiles, sub.id)) : sub.url;
}

export function subscriptionUrl(value) {
  const text = String(value || '').trim();
  const url = new URL(text);
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || text.length > 8192) throw new Error('err.subUrl');
  return text;
}

export function subscriptionUsage(header) {
  const fields = {};
  for (const part of String(header || '').split(';')) {
    const [key, text] = part.trim().split('=');
    const n = Number(text);
    if (['upload', 'download', 'total', 'expire'].includes(key) && text && Number.isSafeInteger(n) && n >= 0) fields[key] = n;
  }
  return Object.keys(fields).length ? fields : null;
}

export function subscriptionName(header, url) {
  let value = String(header || '').trim();
  if (/^base64:/i.test(value)) {
    try {
      const encoded = value.slice(7).trim().replace(/-/g, '+').replace(/_/g, '/');
      value = new TextDecoder('utf-8', { fatal:true }).decode(Uint8Array.from(atob(encoded.padEnd(Math.ceil(encoded.length / 4) * 4, '=')), c => c.charCodeAt(0)));
    } catch { value = ''; }
  }
  try { value = decodeURIComponent(value); } catch { /* Preserve literal percent signs. */ }
  return value.replace(/[\x00-\x1f\x7f]/g, '').trim().slice(0, 100) || new URL(url).hostname;
}

const genericName = value => /^(?:subscription|subscriptions|config|configuration|profile|اشتراک)$/i.test(String(value || '').trim());

// A generic profile-title (e.g. "Subscription") must not hide the actual
// account name supplied in Content-Disposition or saved in the named link.
export function subscriptionMetadata(response, url, previousName = '') {
  const hostname = new URL(url).hostname;
  const candidates = [];
  const candidate = (name, nameSource) => {
    if (name && name !== hostname) candidates.push({ name, nameSource });
  };
  const title = subscriptionName(response?.title, url);
  candidate(title, 'provider');
  const text = String(response?.text || '').slice(0, 16384);
  const comment = /^\s*#\s*profile-(?:title|name)\s*[:=]\s*(.+)$/im.exec(text)?.[1];
  if (comment) {
    const name = subscriptionName(comment, url);
    candidate(name, 'provider');
  }
  const disposition = String(response?.disposition || '');
  const encoded = /(?:^|;)\s*filename\*\s*=\s*(?:"?)(?:UTF-8)'[^']*'([^;"\r\n]+)/i.exec(disposition)?.[1];
  const plain = /(?:^|;)\s*filename\s*=\s*(?:"([^"\r\n]+)"|([^;\r\n]+))/i.exec(disposition);
  let filename = encoded || plain?.[1] || plain?.[2];
  if (filename) {
    filename = subscriptionName(filename, url).split(/[\\/]/).at(-1).replace(/\.(?:txt|json|ya?ml|conf)$/i, '');
    candidate(filename, 'provider');
  }
  if (previousName) candidate(subscriptionName(previousName, url), 'saved');
  const fragment = new URL(url).hash.slice(1);
  if (fragment) candidate(subscriptionName(fragment, url), 'link');
  return candidates.find(item => !genericName(item.name)) || candidates[0] || { name:hostname, nameSource:'host' };
}

export function needsSubscriptionName(sub) {
  if (isLocalSubscription(sub)) return false;
  try { return !sub.name || sub.name === new URL(sub.url).hostname || genericName(sub.name); } catch { return false; }
}

export function migrateSubscriptions(saved, localName = 'Imported servers') {
  const subscriptions = Array.isArray(saved?.subscriptions) ? saved.subscriptions.filter(s => s?.id && (s.url || isLocalSubscription(s))) : [];
  const mapped = new Map(subscriptions.filter(s => !isLocalSubscription(s)).map(s => [s.url, s.id]));
  const linked = (Array.isArray(saved?.profiles) ? saved.profiles : []).map(p => {
    if (!/^https?:\/\//i.test(p.sourceId || '')) return p;
    if (!mapped.has(p.sourceId)) {
      const id = crypto.randomUUID();
      subscriptions.push({ id, url: p.sourceId, name: subscriptionName('', p.sourceId), updatedAt: null });
      mapped.set(p.sourceId, id);
    }
    return { ...p, sourceId: mapped.get(p.sourceId) };
  });
  const localSources = new Map();
  const profiles = linked.map(p => {
    if (subscriptions.some(sub => sub.id === p.sourceId)) return p;
    const source = p.sourceId || '';
    if (!localSources.has(source)) {
      const id = source || crypto.randomUUID();
      subscriptions.push({ id, kind:'local', name:localName });
      localSources.set(source, id);
    }
    return { ...p, sourceId:localSources.get(source) };
  });
  let activeSourceId = mapped.get(saved?.activeSourceId) || saved?.activeSourceId;
  if (activeSourceId !== undefined && localSources.has(activeSourceId || '')) activeSourceId = localSources.get(activeSourceId || '');
  if (activeSourceId === undefined) activeSourceId = profiles.find(p => p.id === saved?.selectedId)?.sourceId || '';
  if (!subscriptions.some(s => s.id === activeSourceId)) activeSourceId = profiles.find(p => p.id === saved?.selectedId)?.sourceId || profiles[0]?.sourceId || '';
  return { profiles, subscriptions, activeSourceId };
}

export const scopedProfiles = (profiles, source) => profiles.filter(p => (p.sourceId || '') === source);
