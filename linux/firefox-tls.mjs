// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import { readFileSync } from 'node:fs';

// Public GlobalSign roots used by Firefox CONNECT upstreams. Keep the OS store
// as well: these anchors cover minimal/older desktop certificate installations.
const roots = readFileSync(new URL('./firefox-roots.pem', import.meta.url), 'utf8')
  .match(/-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----/g);
if (roots?.length !== 4) throw Error('err.config');

export function firefoxTls(outbound) {
  const stream = outbound.streamSettings, tls = stream?.tlsSettings;
  if (stream?.security !== 'tls' || !tls || tls.allowInsecure !== false) throw Error('err.config');
  return {
    ...outbound,
    streamSettings: {
      ...stream,
      tlsSettings: {
        ...tls,
        certificates: [
          ...(tls.certificates || []),
          ...roots.map(pem => ({ usage:'verify', certificate:pem.split(/\r?\n/) }))
        ]
      }
    }
  };
}
