import { readFileSync, readdirSync, mkdirSync, copyFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const lock = JSON.parse(readFileSync('package-lock.json', 'utf8'));
const target = path.resolve('vendor/npm-licenses');
mkdirSync(target, { recursive:true });
const manifest = [];
for (const directory of Object.keys(lock.packages).filter(p => p.startsWith('node_modules/'))) {
  let pkg;
  try { pkg = JSON.parse(readFileSync(path.join(directory, 'package.json'), 'utf8')); }
  catch { if (lock.packages[directory].optional) continue;throw new Error(`Missing dependency: ${directory}`); }
  const prefix = `${pkg.name}-${pkg.version}`.replace(/[^A-Za-z0-9_.-]/g, '-');
  const files = readdirSync(directory).filter(name => /^(?:licen[cs]e|copying|ofl)(?:$|[._-])/i.test(name));
  for (const file of files) copyFileSync(path.join(directory, file), path.join(target, `${prefix}-${file}`));
  manifest.push({ name:pkg.name, version:pkg.version, license:pkg.license || 'See package notices', files:files.map(file => `${prefix}-${file}`) });
}
writeFileSync(path.join(target, 'dependencies.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(`Prepared notices for ${manifest.length} installed dependencies`);
