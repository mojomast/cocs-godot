import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

export const maps = ['prism-foundry','aurora-basin','cinder-array'];
export function verifyOptions(parse, experiences, nativeExperiences) {
  const catalog = JSON.parse(readFileSync(new URL('../contracts/map-selection.json',import.meta.url)));
  assert.equal(catalog.maps.length,9);
  assert.deepEqual(Object.keys(experiences).sort(), ['combat','lobby','arms-race','horde','zones','assault','combined-arms','sports','objectives','lattice','lattice-world','campaign'].sort());
  assert.deepEqual(Object.keys(nativeExperiences).sort(), ['showcase','aurora-basin','cinder-array','particle-lab','shader-lab'].sort());
  const defaults = parse(['--experience=native-dm'],null);
  assert.deepEqual([defaults.map,defaults.mode,defaults.bots,defaults.roundSeconds],['prism-foundry','deathmatch',2,180]);
  assert.equal(defaults.nativeArena,true);
  assert.equal(defaults.nativeOnly,undefined);
  assert.equal(defaults.endpoint,null);
  for (const map of maps) for (const [bots,seconds] of [[1,60],[24,300],[2,180]]) {
    assert.ok(!catalog.maps.some(m=>m.id===map));
    const plan = parse(['--experience','native-dm','--map',map,'--mode=deathmatch',`--bots=${bots}`,'--round-seconds',String(seconds),'--smoke'],{maps:[]});
    const userArgs = plan.userArgs ?? plan.sessionOptions;
    assert.deepEqual(userArgs,[`--map=${map}`,'--mode=deathmatch',`--bots=${bots}`,`--round-seconds=${seconds}`,'--smoke']);
    assert.equal(plan.scene ?? plan.args.at(-1),'res://native_arenas/demo.tscn');
    if (plan.args) assert.deepEqual(plan.args.slice(0,3),['--headless','--audio-driver','Dummy']);
  }
  const rejected = [
    '--map=meridian-exchange','--map=showcase','--map=Prism-foundry','--map=__proto__',
    '--mode=teamdeathmatch','--mode=horde','--mode=exploration','--endpoint=ws://127.0.0.1:12345',
    '--endpoint=wss://example.invalid','--setup','--play','--join','--join=ABC','--host',
    '--native-trace','--mute','--debug-hud','--time-limit=60','--round-target=1','--bots=-1',
    '--bots=0','--bots=25','--bots=99','--bots=1.5','--bots=1e0','--bots=NaN','--bots=Infinity','--bots=0x2',
    '--round-seconds=59','--round-seconds=301','--round-seconds=180.0','--round-seconds=1e2',
    '--round-seconds=Infinity','--smoke=true','--session-smoke','--network-smoke',
    '--lifecycle-smoke','--port=0','--unknown','--','--help',
  ];
  for (const arg of rejected) assert.throws(()=>parse(['--experience=native-dm',arg],catalog),Error,arg);
  for (const key of ['map','mode','bots','round-seconds']) {
    assert.throws(()=>parse(['--experience=native-dm',`--${key}`],catalog),Error,key);
    assert.throws(()=>parse(['--experience=native-dm',`--${key}=`],catalog),Error,key);
  }
  for (const args of [['--map=prism-foundry','--map=aurora-basin'],['--bots=2','--bots=2'],['--round-seconds=60','--round-seconds=60'],['--smoke','--smoke'],['--experience=native-dm']]) {
    assert.throws(()=>parse(['--experience=native-dm',...args],catalog),Error,args.join(' '));
  }
  for (const experience of [...Object.keys(experiences),...Object.keys(nativeExperiences)]) {
    for (const key of ['bots','round-seconds']) {
      // LATTICE has its own --time-limit parser; its legacy dev early return
      // predates the generic round-seconds guard. This native-DM fixture owns
      // neither that parser nor its ignored-option behavior.
      if (key === 'round-seconds' && ['lattice','lattice-world'].includes(experience)) continue;
      if (key === 'bots' && ['combat','zones','assault','combined-arms','lattice','lattice-world'].includes(experience)) {
        const plan = parse([`--experience=${experience}`,'--bots=2'],catalog);
        assert.ok((plan.userArgs ?? plan.sessionOptions).includes('--bots=2'), experience);
        continue;
      }
      assert.throws(()=>parse([`--experience=${experience}`,`--${key}=2`],catalog),Error,experience);
    }
    // The dev combat launcher historically leaves map validation to its client.
    if (experience !== 'combat') for (const map of maps) assert.throws(()=>parse([`--experience=${experience}`,`--map=${map}`],catalog),Error,experience);
  }
}
