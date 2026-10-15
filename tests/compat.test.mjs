import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from '../src/lib/compat.mjs';
import { themeFallbackColors } from '../src/lib/theme-compat.mjs';
test('UUID fallback preserves version/variant and uses the cryptographic source',()=>{
 let calls=0;const source={getRandomValues:b=>{calls++;b.fill(255);return b;}};
 assert.equal(randomUUID(source),'ffffffff-ffff-4fff-bfff-ffffffffffff');assert.equal(calls,1);
});
test('legacy theme colors retain alpha and weighted light/dark surface contrasts',()=>{
 const colors=themeFallbackColors({text:'#ffffff',liquid:'#000000',teal:'#000000',warn:'#ffffff',green:'#ffffff'});
 assert.equal(colors['--card-border'],'rgba(255, 255, 255, 0.13)');
 assert.equal(colors['--nav-active'],'rgb(20, 20, 20)');assert.equal(colors['--switch-active'],'rgb(102, 102, 102)');
 assert.ok(Object.values(colors).every(c=>!c.includes('NaN')));
});
