import assert from 'node:assert/strict';
import { availableRelease, compareVersions, publishedRelease, releaseVersion, shouldNotify, projectLinks } from '../../src/lib/releases.mjs';
import { readFileSync } from 'node:fs';

const project = JSON.parse(readFileSync('project.json','utf8'));
const repository = project.repository;
const now = Date.parse('2026-10-13T12:00:00Z');
const stable = { tag_name:'v0.1.18', draft:false, prerelease:false, published_at:'2026-10-13T00:00:00Z', html_url:`https://github.com/${repository}/releases/tag/v0.1.18` };
let checks = 0;
function check(actual, expected, name) { assert.deepEqual(actual, expected, name);checks++; }
check(availableRelease(stable,'0.1.17',repository,now), { version:'0.1.18',tag:'v0.1.18' }, 'published newer release is shown');
for (const current of ['0.1.18','v0.1.18','0.1.19','1.0.0']) check(availableRelease(stable,current,repository,now),null,'same/older release is hidden');
for (const change of [
  {draft:true}, {prerelease:true}, {draft:undefined}, {prerelease:undefined},
  {published_at:null}, {published_at:'invalid'}, {published_at:'2026-10-14T00:00:00Z'},
  {tag_name:'v0.1.18-beta.1'}, {tag_name:'latest'}, {tag_name:'v0.01.18'},
  {html_url:'https://example.test/releases/tag/v0.1.18'},
  {html_url:`https://github.com/another-owner/Vyrax/releases/tag/v0.1.18`},
  {html_url:`http://github.com/${repository}/releases/tag/v0.1.18`},
  {html_url:`https://user:secret@github.com/${repository}/releases/tag/v0.1.18`},
  {html_url:`https://github.com/${repository}/releases/tag/v0.1.18?redirect=1`},
  {html_url:`https://github.com/${repository}/releases/tag/v0.1.18#other`},
  {html_url:`https://github.com/${repository}/releases/tag/%invalid`},
  {html_url:`https://github.com/${repository}/releases/tag/v0.1.19`}
]) check(availableRelease({...stable,...change},'0.1.17',repository,now),null,'nonpublished/invalid/untrusted release hidden');
check(availableRelease(null,'0.1.17',repository,now),null,'empty GitHub releases do not produce a notice');
check(compareVersions('0.1.10','0.1.9'),1,'numeric rather than string comparison');
check(compareVersions('1.0.0','0.99.99'),1,'major version comparison');
check(compareVersions('0.2.0','0.1.99'),1,'minor version comparison');
check(compareVersions('v0.1.18+build.5','0.1.18'),0,'build metadata and v prefix normalize');
for (const invalid of ['','0.1','-1.1.1',' 0.1.18','01.1.1','1.1.1-rc.1','1.2.9007199254740992']) check(releaseVersion(invalid),null,'invalid/nonstable tags rejected');
const available = availableRelease(stable,'0.1.17',repository,now);
check(shouldNotify(available,''),true,'first new release is visible');
check(shouldNotify(available,'0.1.18'),false,'dismissal survives reload with persisted version');
check(shouldNotify(available,'v0.1.18'),false,'canonical version dismissal');
check(shouldNotify(available,'0.1.19'),false,'rollback does not repeat older notices');
check(shouldNotify(available,'0.1.17'),true,'a later release can notify');
check(shouldNotify(null,''),false,'no fabricated notice');
check(publishedRelease(stable,repository,now)?.version,'0.1.18','stable metadata is validated separately from installed version');
check(projectLinks(project), { source:`https://github.com/${repository}`, release:`https://github.com/${repository}/releases/latest`, telegram:'https://t.me/AmyraxVPN',firefoxAccount:'https://accounts.firefox.com/',firefoxHelp:'https://support.mozilla.org/en-US/kb/firefox-vpn' }, 'fixed project destinations');
assert.throws(()=>projectLinks({...project, repository:'owner/repo/../../other'}));checks++;
console.log(`${checks} release validation, semantic version, quiet dismissal and project-link checks passed`);
