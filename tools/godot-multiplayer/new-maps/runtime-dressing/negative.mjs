// Negative tests for check.mjs: a verifier that only ever passes proves nothing,
// so every rule the dressing check relies on is shown here to reject a profile.
//
// Each case takes an already-shipped control profile (helix-conservatory, which
// author.mjs does not emit, so the byte-drift rule stays out of the way), breaks
// exactly one thing, and asserts that check.mjs exits non-zero with the expected
// message. Nothing is written into the repository: the broken copies live in a
// temporary directory that is removed on the way out.
//
//   node tools/godot-multiplayer/new-maps/runtime-dressing/negative.mjs
import {execFileSync} from 'node:child_process';
import {mkdtempSync, writeFileSync, readFileSync, rmSync, copyFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {resolve, dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '../../../..');
const CHECK = resolve(HERE, 'check.mjs');
const CONTROL = 'helix-conservatory';
const PROFILE_DIR = resolve(ROOT, 'godot/multiplayer_worlds/dressing/profiles');

const cases = [
  {
    name: 'a plate outside the map world bounds',
    expect: /outside the map's world bounds/,
    // Inside profile.gd's +-512 m box, outside the map's own +-120 m world.
    break: p => { p.panels[0].position[0] = 300; },
  },
  {
    name: 'two placements on one point',
    expect: /coincides with/,
    break: p => { p.signs[1].position = [...p.panels[0].position]; },
  },
  {
    name: 'a panel budget below its own placement count',
    expect: /panels exceeds profile budget/,
    break: p => { p.budgets.panels = p.panels.length - 1; },
  },
  {
    name: 'a thirteenth mote pocket',
    expect: /pockets exceeds hard cap/,
    break: p => {
      const last = p.pockets[p.pockets.length - 1];
      // helix-conservatory dresses four, so the cap needs nine more.
      for (let i = 1; i <= 9; i++) {
        p.pockets.push({...last, id: `${last.id}-overflow-${i}`, count: 1,
          position: [last.position[0] + i * 2, last.position[1], last.position[2]]});
      }
    },
  },
  {
    name: 'a mote total above its budget',
    expect: /motes \d+ exceed budget/,
    break: p => { p.budgets.motes = p.pockets.reduce((sum, e) => sum + e.count, 0) - 1; },
  },
  {
    name: 'a sign below the 4.5:1 contrast floor',
    expect: /sign contrast below 4.5:1/,
    break: p => { p.signs[0].foreground = '3a3f4a'; p.signs[0].background = '343a44'; },
  },
  {
    name: 'an art material the profile never dresses',
    expect: /unmatched art material/,
    break: p => { p.materials.pop(); },
  },
  {
    name: 'a selector the map art does not contain',
    expect: /unused selector/,
    break: p => { p.materials[0].source = 'obsidian'; },
  },
  {
    name: 'a Moth texture that is not in the manifest',
    expect: /unresolved Moth resource/,
    break: p => { p.panels[0].texture = 'obsidian_weave'; },
  },
];

let failures = 0;
for (const testCase of cases) {
  const dir = mkdtempSync(join(tmpdir(), 'dressing-negative-'));
  try {
    const profile = JSON.parse(readFileSync(resolve(PROFILE_DIR, `${CONTROL}.json`), 'utf8'));
    testCase.break(profile);
    // check.mjs reads every accepted map, so the controls travel with the broken
    // copy and the pass/fail line for each of them stays in the output.
    for (const mapId of ['gravemill-foundry', 'parallax-observatory']) {
      copyFileSync(resolve(PROFILE_DIR, `${mapId}.json`), resolve(dir, `${mapId}.json`));
    }
    writeFileSync(resolve(dir, `${CONTROL}.json`), `${JSON.stringify(profile, null, 2)}\n`);
    let output = '', code = 0;
    try {
      output = execFileSync(process.execPath, [CHECK, CONTROL], {
        encoding: 'utf8', env: {...process.env, DRESSING_PROFILE_DIR: dir}, stdio: 'pipe',
      });
    } catch (e) {
      output = `${e.stdout ?? ''}${e.stderr ?? ''}`;
      code = e.status ?? 1;
    }
    if (code === 0) {
      console.error(`FAIL ${testCase.name}: check.mjs accepted the broken profile`);
      failures++;
    } else if (!testCase.expect.test(output)) {
      console.error(`FAIL ${testCase.name}: rejected, but not for the expected reason`);
      console.error(`  expected ${testCase.expect}`);
      failures++;
    } else {
      console.log(`PASS rejected: ${testCase.name}`);
    }
  } finally {
    rmSync(dir, {recursive: true, force: true});
  }
}
console.log(`negative cases: ${cases.length - failures}/${cases.length} rejected as expected`);
process.exitCode = failures ? 1 : 0;