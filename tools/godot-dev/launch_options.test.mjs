import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {launchOptions,EXPERIENCES} from './launch_options.mjs';
const catalog=JSON.parse(readFileSync(new URL('../../port/contracts/map-selection.json',import.meta.url)));

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
      assert.deepEqual(plan.sessionOptions,[`--map=${map}`,`--mode=${mode}`]);
      assert.equal(plan.smoke,null);
      assert.ok(!plan.args.includes('--headless'));
    }
    if(entry.modes)assert.deepEqual(launchOptions([`--experience=${experience}`],catalog).sessionOptions,
      [`--map=${entry.map}`,`--mode=${entry.modes[entry.map][0]}`]);
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
  ])assert.throws(()=>launchOptions(args,catalog),Error,args.join(' '));
  assert.throws(()=>launchOptions(['--experience=sports'],{maps:[]}),/locked catalog/);
});
