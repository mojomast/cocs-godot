import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {launchOptions,EXPERIENCES} from './launch_options.mjs';
const catalog=JSON.parse(readFileSync(new URL('../../port/contracts/map-selection.json',import.meta.url)));

test('Horde is default-ten-wave local-only and refuses unsupported or ignored controls',()=>{
  for(const map of ['meridian-exchange','verdant-reliquary','ember-crucible']){
    const plan=launchOptions(['--experience=horde',`--map=${map}`],catalog);
    assert.ok(plan.args.includes('res://horde/demo.tscn'));
    assert.deepEqual(plan.sessionOptions,[`--map=${map}`,'--mode=horde']);
    assert.equal(plan.endpoint,null);
  }
  for(const arg of ['--map=tidal-citadel','--mode=deathmatch','--waves=1','--round-target=1','--endless','--upgrades','--endpoint=ws://127.0.0.1:1234','--time-limit=900','--setup','--native-trace','--mute','--debug-hud','--session-smoke','--horde-evidence']){
    assert.throws(()=>launchOptions(['--experience=horde',arg],catalog),Error,arg);
  }
  assert.throws(()=>launchOptions(['--experience=horde'],{maps:[]}),/locked catalog/);
});

test('existing viewer, combat setup and smoke routes stay compatible',()=>{
  assert.deepEqual(launchOptions([],catalog).args,['--path','godot']);
  const setup=launchOptions(['--play','--setup','--map','verdant-reliquary','--mode=rockets','--mute'],catalog);
  assert.deepEqual(setup.args,['--path','godot','res://world/session.tscn']);
  assert.deepEqual(setup.sessionOptions,['--map=verdant-reliquary','--mode=rockets','--setup','--mute']);
  for(const smoke of ['--network-smoke','--session-smoke','--lifecycle-smoke']){
    const plan=launchOptions([smoke],catalog);
    assert.equal(plan.args[0],'--headless');
    assert.equal(plan.smoke,smoke);
    assert.equal(plan.args.includes('res://tests/protocol/live.gd'),smoke==='--network-smoke');
  }
});

test('each standalone map/mode reaches its actual scene and locked identity',()=>{
  for(const [experience,entry]of Object.entries(EXPERIENCES)){
    assert.ok(existsSync(new URL('../../godot/'+entry.scene.slice(6),import.meta.url)));
    for(const [map,modes]of Object.entries(entry.modes??{}))for(const mode of modes){
      const plan=launchOptions([`--experience=${experience}`,`--map=${map}`,`--mode=${mode}`],catalog);
      assert.ok(plan.args.includes(entry.scene));
      assert.deepEqual(plan.sessionOptions,[`--map=${map}`,`--mode=${mode}`,...(experience==='lobby'?['--lobby-menu']:[])]);
      assert.equal(plan.smoke,null);
      assert.ok(!plan.args.includes('--headless'));
    }
    if(entry.modes)assert.deepEqual(launchOptions([`--experience=${experience}`],catalog).sessionOptions,
      [`--map=${entry.map}`,`--mode=${entry.modes[entry.map][0]}`,...(experience==='lobby'?['--lobby-menu']:[])]);
  }
});

test('standalone selection rejects substitutions, unsupported modes and ignored options',()=>{
  for(const args of [
    ['--experience=unknown'],['--experience=__proto__'],['--experience=sports','--map=__proto__'],
    ['--experience=sports','--map=tidal-citadel'],
    ['--experience=objectives','--map=sunscar-convoy','--mode=ctf'],
    ['--experience=lattice','--mode=deathmatch'],['--experience=lattice','--setup'],
    ['--experience=sports','--session-smoke'],['--experience=objectives','--debug-hud'],
    ['--experience=sports','--mute'],['--map'],['--mode='],['--experience','--play'],
    ['--map=ion-speedway','--map=aurora-stadium'],['--session-smoke','--lifecycle-smoke'],
    ['--endpont=ws://localhost:3'],
    ['--experience=zones','--map=tidal-citadel','--mode=koth'],
    ['--experience=zones','--map=aurora-stadium'],
    ['--experience=combined-arms','--map=tidal-citadel'],
    ['--experience=combined-arms','--mode=payload'],
    ['--experience=arms-race','--map=ion-speedway'],
    ['--experience=arms-race','--mode=deathmatch'],
    ['--experience=arms-race','--time-limit=60'],
  ])assert.throws(()=>launchOptions(args,catalog),Error,args.join(' '));
  assert.throws(()=>launchOptions(['--experience=sports'],{maps:[]}),/locked catalog/);
});

test('sports round options preserve legal ordinary configuration without silent clamping',()=>{
  const race=launchOptions(['--experience=sports','--time-limit=90','--round-target=10'],catalog);
  assert.deepEqual(race.sessionOptions,['--map=ion-speedway','--mode=puma-race','--time-limit=90','--round-target=10']);
  const soccer=launchOptions(['--experience=sports','--map=aurora-stadium','--round-target','15','--time-limit','60'],catalog);
  assert.deepEqual(soccer.sessionOptions,['--map=aurora-stadium','--mode=puma-soccer','--time-limit=60','--round-target=15']);
  for(const extra of ['--time-limit=59','--time-limit=901','--time-limit=60.5','--round-target=0','--round-target=11','--round-target=abc']){
    assert.throws(()=>launchOptions(['--experience=sports',extra],catalog));
  }
  assert.throws(()=>launchOptions(['--experience=sports','--map=aurora-stadium','--round-target=16'],catalog));
  assert.throws(()=>launchOptions(['--time-limit=60'],catalog),/sports launcher/);
  assert.throws(()=>launchOptions(['--experience=objectives','--round-target=1'],catalog),/sports launcher/);
});

test('world traversal and command board remain distinct native scenes',()=>{  const world=launchOptions(['--experience=lattice-world','--map=monsoon-foundry','--mode=cocs-coop'],catalog);
  assert.ok(world.args.includes('res://lattice/world_demo.tscn'));
  assert.deepEqual(world.sessionOptions,['--map=monsoon-foundry','--mode=cocs-coop']);
  assert.ok(launchOptions(['--experience=lattice'],catalog).args.includes('res://lattice/board.tscn'));
  assert.throws(()=>launchOptions(['--experience=lattice-world','--map=ion-speedway'],catalog));
  assert.throws(()=>launchOptions(['--experience=lattice-world','--session-smoke'],catalog));
});

test('identity-zones routes Domination on Vermilion Fold only',()=>{
  const plan=launchOptions(['--experience=identity-zones'],catalog);
  assert.ok(plan.args.includes('res://native_arenas/identity_zone_demo.tscn'));
  assert.equal(plan.identityZone,true);
  assert.equal(plan.endpoint,null);
  assert.deepEqual(plan.sessionOptions,['--map=vermilion-fold','--mode=domination','--bots=2','--round-seconds=120','--score-limit=30']);
  // Solo practice is a reviewed bound on this route, unlike native-dm.
  const solo=launchOptions(['--experience=identity-zones','--bots=0','--smoke'],catalog);
  assert.deepEqual(solo.sessionOptions,['--map=vermilion-fold','--mode=domination','--bots=0','--round-seconds=120','--score-limit=30','--smoke']);
  assert.equal(solo.smoke,'--smoke');
  assert.equal(solo.args.includes('--headless'),true);
  for(const args of [['--map=lacuna-court'],['--mode=koth'],['--bots=8'],['--round-seconds=59'],['--score-limit=0'],['--score-limit=901'],['--time-limit=60'],['--round-target=5'],['--play']]){
    assert.throws(()=>launchOptions(['--experience=identity-zones',...args],catalog),Error,args.join(' '));
  }
});
