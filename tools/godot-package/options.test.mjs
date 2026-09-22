import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {options, EXPERIENCES} from './options.mjs';
const catalog = JSON.parse(readFileSync(new URL('../../port/contracts/map-selection.json', import.meta.url)));

test('package scene routing covers all nine locked identities and preserves native capability subsets', () => {
  const covered = new Set();
  for (const [experience, value] of Object.entries(EXPERIENCES)) {
    for (const [map, modes] of Object.entries(value.maps)) {
      covered.add(map);
      for (const mode of modes) {
        const plan = options([`--experience=${experience}`, `--map=${map}`, `--mode=${mode}`], catalog);
        assert.equal(plan.scene, value.scene);
        assert.ok(plan.userArgs.includes(`--map=${map}`));
        assert.ok(plan.userArgs.includes(`--mode=${mode}`));
      }
    }
  }
  assert.deepEqual([...covered].sort(), catalog.maps.map(m => m.id).sort());
  assert.ok(options([], catalog).userArgs.includes('--setup'));
  assert.ok(!options(['--play'], catalog).userArgs.includes('--setup'));
});

test('bad package arguments fail before opening an owned server; no silent scene/mode fallback', () => {
  for (const args of [
    ['--experience=__proto__'], ['--experience=viewer'], ['--map=unknown'],
    ['--map=tidal-citadel'], ['--mode=ctf'], ['--mode=constructor'],
    ['--experience=sports','--mode=deathmatch'], ['--experience=lattice-world','--setup'],
    ['--experience=lattice','--mute'], ['--experience=objectives','--native-trace'],
    ['--experience=lattice','--play'],
    ['--experience=zones','--map=tidal-citadel','--mode=koth'],
    ['--experience=zones','--map=aurora-stadium'],
    ['--experience=combined-arms','--map=tidal-citadel'],
    ['--experience=combined-arms','--mode=payload'],
    ['--experience=arms-race','--map=ion-speedway'],
    ['--experience=arms-race','--mode=deathmatch'],
    ['--experience=arms-race','--time-limit=60'],
    ['--play','--setup'], ['--play','--play'], ['--map=a','--map=b'],
    ['--experience'], ['--experience','--play'], ['--map='], ['--endpoint=ws://elsewhere'],
    ['--time-limit=60'], ['--experience=sports','--time-limit=59'],
    ['--experience=sports','--time-limit=901'], ['--experience=sports','--time-limit=60.5'],
    ['--experience=sports','--round-target=11'], ['--experience=sports','--round-target=0'],
    ['--experience=sports','--map=aurora-stadium','--round-target=16'],
    ['--experience=sports','--round-target=9007199254740993'], ['--session-smoke'],
  ]) assert.throws(() => options(args, catalog), undefined, JSON.stringify(args));
  assert.ok(options(['--experience=sports','--time-limit=900','--round-target=10'], catalog));
  assert.ok(options(['--experience=sports','--map=aurora-stadium','--round-target=15'], catalog));
});
