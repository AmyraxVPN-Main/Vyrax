// جدول کشورها را از دادهٔ ip3country به یک فایل دودویی فشرده تبدیل می‌کند
// تا هاست C# بدون هیچ وابستگی‌ای، آفلاین کشورِ یک IP را پیدا کند.
//
// قالب فایل (کم‌اندین، بدون علامت):
//   uint16  تعداد کشورها
//   N × 2   کد دوحرفی هر کشور (ASCII)
//   uint32  تعداد بازه‌ها
//   M × 6   انتهای هر بازه (uint32) + اندیس کشور (uint16)
//
// usage: node .tools/gen-geo.mjs
import { createRequire } from 'node:module';
import { writeFileSync } from 'node:fs';

const require = createRequire(import.meta.url);
const ip3country = require('ip3country');
ip3country.init();

const codes = ip3country.countryCodes;
const ranges = ip3country.ipRanges;
const MAX = 0xffffffff;

const table = [...new Set(codes)];
const index = new Map(table.map((c, i) => [c, i]));

if (table.length > 0xffff) throw new Error('too many country codes');
if (ranges.length > 0xffffffff) throw new Error('too many ranges');

const size = 2 + table.length * 2 + 4 + ranges.length * 6;
const buf = Buffer.alloc(size);
let at = 0;

buf.writeUInt16LE(table.length, at);
at += 2;
for (const cc of table) {
  buf.write(cc, at, 2, 'ascii');
  at += 2;
}

buf.writeUInt32LE(ranges.length, at);
at += 4;
for (let i = 0; i < ranges.length; i++) {
  buf.writeUInt32LE(Math.min(ranges[i], MAX) >>> 0, at);
  at += 4;
  buf.writeUInt16LE(index.get(codes[i]), at);
  at += 2;
}

writeFileSync('native/geo.bin', buf);
console.log(
  `wrote native/geo.bin — ${table.length} countries, ${ranges.length} ranges, ` +
    `${(size / 1048576).toFixed(2)} MB`
);
