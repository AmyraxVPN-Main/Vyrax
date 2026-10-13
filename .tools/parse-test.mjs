// تست پارسر کانفیگ‌ها. usage: node .tools/parse-test.mjs
import { parseImport, mergeProfiles } from '../src/lib/profiles.mjs';

const VLESS =
  'vless://b831381d-6324-4d53-ad4f-8cda48b30811@de-frankfurt.example.com:443?type=tcp&security=reality&pbk=xhbP9NRnM3XZK4vG3BcCk2yYwC7P0m1vFq4hT8sL2kE&fp=chrome&sni=www.microsoft.com&sid=6ba85179e30d4fc2&flow=xtls-rprx-vision#Frankfurt%20Germany';
const TROJAN =
  'trojan://password123@de1.example.net:8443?type=ws&path=%2Fws&security=tls&sni=de1.example.net#Berlin%20Node';
const SS = 'ss://YWVzLTI1Ni1nY206cGFzc3dvcmQ@198.51.100.7:8388#Stockholm%20Sweden';
const VMESS =
  'vmess://eyJ2IjoiMiIsInBzIjoiSXN0YW5idWwgVHVya2V5IiwiYWRkIjoidHIxLmV4YW1wbGUub3JnIiwicG9ydCI6IjQ0MyIsImlkIjoiYjgzMTM4MWQtNjMyNC00ZDUzLWFkNGYtOGNkYTQ4YjMwODExIiwiYWlkIjoiMCIsIm5ldCI6IndzIiwidHlwZSI6Im5vbmUiLCJob3N0IjoidHIxLmV4YW1wbGUub3JnIiwicGF0aCI6Ii93cyIsInRscyI6InRscyJ9';

const ALL = [VLESS, TROJAN, SS, VMESS].join('\n');

const CLASH = `proxies:
  - name: "Amsterdam NL"
    type: vless
    server: nl1.example.com
    port: 443
    uuid: b831381d-6324-4d53-ad4f-8cda48b30811
    network: ws
    ws-opts:
      path: /ws
      headers:
        Host: nl1.example.com
    tls: true
    servername: nl1.example.com
`;

const SINGBOX = JSON.stringify({
  outbounds: [
    {
      type: 'vless',
      tag: 'Vienna Austria',
      server: 'at1.example.com',
      server_port: 443,
      uuid: 'b831381d-6324-4d53-ad4f-8cda48b30811',
      flow: 'xtls-rprx-vision',
      tls: { enabled: true, server_name: 'at1.example.com', reality: { enabled: true, public_key: 'AAAABBBBCCCC', short_id: 'abcd' } }
    },
    { type: 'selector', tag: 'pick' }
  ]
});

const cases = [
  ['single vless', VLESS],
  ['four links', ALL],
  ['base64 subscription', Buffer.from(ALL).toString('base64')],
  ['clash yaml', CLASH],
  ['sing-box json', SINGBOX],
  ['garbage', 'hello world'],
  ['bad port', 'vless://b831381d-6324-4d53-ad4f-8cda48b30811@host.example.com:99999#x']
];

let pass = 0;
for (const [label, input] of cases) {
  try {
    const { profiles, errors } = parseImport(input, (k) => k);
    console.log(`\n## ${label} → ${profiles.length} profile(s), ${errors.length} error(s)`);
    for (const p of profiles) {
      console.log(
        `   ${p.protocol.padEnd(12)} ${p.host}:${p.port}  tls=${p.tls ? 'y' : 'n'} reality=${p.reality ? 'y' : 'n'} ${p.transport}/${p.path ?? ''}  "${p.name}"`
      );
    }
    for (const e of errors) console.log(`   ! line ${e.line}: ${e.message}`);
    pass++;
  } catch (e) {
    console.log(`\n## ${label} → threw: ${e.message}`);
  }
}

/* ادغام: افزودن دوبارهٔ همان کانفیگ نباید رکورد تکراری بسازد */
const first = parseImport(ALL, (k) => k).profiles;
const merged = mergeProfiles(first, parseImport(ALL, (k) => k).profiles);
console.log(`\n## merge → ${first.length} → ${merged.length} (must stay ${first.length})`);

/* و ادغام با منبع اشتراک باید رکوردهای قبلی همان منبع را جایگزین کند */
const fromSub = mergeProfiles(first, parseImport(CLASH, (k) => k).profiles, 'sub-1');
const resub = mergeProfiles(fromSub, parseImport(CLASH, (k) => k).profiles, 'sub-1');
console.log(`## resub → ${fromSub.length} → ${resub.length} (must stay ${fromSub.length})`);

console.log(`\ncases completed: ${pass}/${cases.length}`);
