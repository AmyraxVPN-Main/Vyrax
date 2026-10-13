export function parseAddresses(text) {
  const input = Array.isArray(text) ? text.join('\n') : String(text || '');
  if (input.length > 16000) throw new Error('err.routeList');
  const addresses = [...new Set(input.split(/[\s,;]+/).filter(Boolean).map((entry) => {
    let value = entry.toLowerCase().replace(/^\*\./, '').replace(/\.$/, '');
    const [address, prefix, extra] = value.split('/');
    const v4 = /^(?:\d{1,3}\.){3}\d{1,3}$/.test(address) && address.split('.').every(n => +n <= 255);
    let v6 = false;
    if (address.includes(':')) {
      try { v6 = new URL(`http://[${address}]/`).hostname.startsWith('['); } catch { /* invalid IP */ }
    }
    if (prefix !== undefined && (!v4 && !v6 || extra !== undefined || !/^\d+$/.test(prefix) || +prefix > (v4 ? 32 : 128))) throw new Error('err.routeList');
    if (v4 || v6) return value;
    if (/[\s/:@?#\\]/.test(value)) throw new Error('err.routeList');
    try { value = new URL(`http://${value}`).hostname; } catch { throw new Error('err.routeList'); }
    if (value.length > 253 || !/^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(value)) throw new Error('err.routeList');
    return value;
  }))];
  if (addresses.length > 200) throw new Error('err.routeList');
  return addresses;
}

export function validatePreferences(settings) {
  const splitAddresses = parseAddresses(settings.splitAddresses);
  const bypassAddresses = parseAddresses(settings.bypassAddresses);
  if (settings.splitTunneling && settings.bypassSites) throw new Error('err.routeConflict');
  if (settings.splitTunneling && !splitAddresses.length || settings.bypassSites && !bypassAddresses.length) throw new Error('err.routeEmpty');
  return { ...settings, splitAddresses, bypassAddresses, preferencesVersion: 1 };
}
