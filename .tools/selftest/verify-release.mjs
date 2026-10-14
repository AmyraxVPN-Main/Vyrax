import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
import path from 'node:path';

// Inspect PE resources directly; never launch the installer or the elevated host.
function resources(file) {
  const bytes = readFileSync(file);
  const pe = bytes.readUInt32LE(0x3c);
  assert.equal(bytes.toString('ascii', pe, pe + 4), 'PE\0\0');
  const optional = pe + 24, optionalSize = bytes.readUInt16LE(pe + 20);
  const sections = Array.from({ length: bytes.readUInt16LE(pe + 6) }, (_, i) => {
    const p = optional + optionalSize + i * 40;
    return { rva: bytes.readUInt32LE(p + 12), length: Math.max(bytes.readUInt32LE(p + 8), bytes.readUInt32LE(p + 16)), offset: bytes.readUInt32LE(p + 20) };
  });
  function address(rva) {
    const section = sections.find(s => rva >= s.rva && rva < s.rva + s.length);
    assert.ok(section, 'resource RVA is mapped');
    return section.offset + rva - section.rva;
  }
  const directory = optional + (bytes.readUInt16LE(optional) === 0x20b ? 112 : 96);
  const root = address(bytes.readUInt32LE(directory + 16));
  const found = [];
  function walk(offset, path = []) {
    assert.ok(path.length <= 3, 'bounded resource tree');
    const p = root + offset;
    const count = bytes.readUInt16LE(p + 12) + bytes.readUInt16LE(p + 14);
    for (let i = 0; i < count; i++) {
      const entry = p + 16 + i * 8, name = bytes.readUInt32LE(entry), target = bytes.readUInt32LE(entry + 4);
      const keys = [...path, name];
      if (target & 0x80000000) walk(target & 0x7fffffff, keys);
      else {
        const data = root + target;
        const begin = address(bytes.readUInt32LE(data)), length = bytes.readUInt32LE(data + 4);
        found.push({ keys, data: bytes.subarray(begin, begin + length) });
      }
    }
  }
  walk(0);
  return { bytes, entries: found };
}

const ico = readFileSync('native/Vyrax.ico');
const count = ico.readUInt16LE(4);
assert.equal(count, 9);
const iconImages = Array.from({ length: count }, (_, i) => {
  const entry = 6 + 16 * i, length = ico.readUInt32LE(entry + 8), start = ico.readUInt32LE(entry + 12);
  return ico.subarray(start, start + length);
});
const { version } = JSON.parse(readFileSync('package.json', 'utf8'));
const files = [process.argv[2] || 'release/Vyrax/Vyrax.exe', `release/VyraxSetup-${version}.exe`];
const result = files.map(file => {
  const { bytes, entries } = resources(file);
  const groups = entries.filter(e => e.keys[0] === 14);
  const images = entries.filter(e => e.keys[0] === 3);
  assert.ok(groups.length > 0, `${file}: icon group exists`);
  const matchingImages = iconImages.filter(data => images.some(image => data.equals(image.data))).length;
  assert.equal(matchingImages, 9, `${file}: all nine Vyrax icon images embedded`);
  const manifests = entries.filter(e => e.keys[0] === 24).map(e => e.data.toString('utf8')).join('\n');
  const requestedLevel = /requestedExecutionLevel[^>]+level="([^"]+)"/.exec(manifests)?.[1];
  assert.equal(requestedLevel, path.basename(file).toLowerCase() === 'vyrax.exe' ? 'requireAdministrator' : 'asInvoker');
  const versionResources = entries.filter(e => e.keys[0] === 16);
  assert.ok(versionResources.some(e => e.data.includes(Buffer.from('Copyright (c) 2026 Amyrax','utf16le'))), `${file}: Amyrax copyright embedded`);
  return { file, bytes: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex'), iconSizesVerified: matchingImages, requestedLevel };
});
writeFileSync(`release/verification-${version}.json`, JSON.stringify(result, null, 2) + '\n');
const bundle=path.dirname(files[0]);
assert.match(readFileSync(path.join(bundle,'licenses/LICENSE'),'utf8'), /MIT License[\s\S]*Copyright \(c\) 2026 Amyrax/);
assert.ok(readFileSync(path.join(bundle,'licenses/GPL-3.0.txt')).equals(readFileSync('third_party/GPL-3.0.txt')), 'upstream full GPL text preserved');
console.log(JSON.stringify(result, null, 2));
