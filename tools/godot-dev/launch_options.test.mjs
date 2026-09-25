import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {launchOptions,EXPERIENCES} from './launch_options.mjs';
import {options as packageOptions} from '../godot-package/options.mjs';
const catalog=JSON.parse(readFileSync(new URL('../../port/contracts/map-selection.json',import.meta.url)));

test('Horde is default-ten-wave local-only and refuses unsupported or ignored controls',()=>{
  for(const map of ['meridian-exchange','verdant-reliquary','ember-crucible']){
    const plan=launchOptions(['--experience=horde',`--map=${map}`],catalog);
    assert.ok(plan.args.includes('res://horde/demo.tscn'));
    assert.deepEqual(plan.sessionOptions,[`--map=${map}`,'--mode=horde']);
    assert.equal(plan.endpoint,null);
  }
  const selected=launchOptions(['--experience=horde','--map=nacre-engine','--waves=10','--operator=claude','--harness=claudecode'],catalog);
  assert.ok(selected.args.includes('res://native_arenas/identity_horde_demo.tscn'));
  assert.ok(selected.sessionOptions.includes('--operator=claude'));
  assert.ok(selected.sessionOptions.includes('--harness=claudecode'));
  for(const arg of ['--waves=0','--waves=31','--operator=invalid','--harness=invalid','--map=tidal-citadel','--mode=deathmatch','--round-target=1','--endless','--upgrades','--endpoint=ws://127.0.0.1:1234','--time-limit=900','--join-room=other','--rung=4v4','--setup','--native-trace','--mute','--debug-hud','--session-smoke','--horde-evidence']){
    assert.throws(()=>launchOptions(['--experience=horde',arg],catalog),Error,arg);
  }
  assert.throws(()=>launchOptions(['--experience=horde','--operator=claude','--harness=openclaw'],catalog));
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
      assert.deepEqual(plan.sessionOptions,experience.startsWith('lattice') ? [`--map=${map}`,`--mode=${mode}`,'--time-limit=900','--bots=2','--operator=chatgpt','--harness=openclaw'] : [`--map=${map}`,`--mode=${mode}`,...(experience==='lobby'?['--lobby-menu']:[])]);
      assert.equal(plan.smoke,null);
      assert.ok(!plan.args.includes('--headless'));
    }
    if(entry.modes)assert.deepEqual(launchOptions([`--experience=${experience}`],catalog).sessionOptions,
      (experience.startsWith('lattice') ? [`--map=${entry.map}`,`--mode=${entry.modes[entry.map][0]}`,'--time-limit=900','--bots=2','--operator=chatgpt','--harness=openclaw'] : [`--map=${entry.map}`,`--mode=${entry.modes[entry.map][0]}`,...(experience==='lobby'?['--lobby-menu']:[])]));
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

test('dev menu route opens the main menu scene without authority; no-arg default stays the viewer',()=>{
  const plan=launchOptions(['--experience=menu'],catalog);
  assert.deepEqual(plan.args,['--path','godot','res://ui/main_menu.tscn']);
  assert.equal(plan.experience,'menu');
  assert.equal(plan.nativeOnly,true);
  assert.equal(plan.endpoint,null);
  assert.equal(plan.smoke,null);
  assert.deepEqual(plan.sessionOptions,[]);
  // Dev no-arg default is still the map viewer (launch_options.test.mjs:21 pins it).
  assert.deepEqual(launchOptions([],catalog).args,['--path','godot']);
  assert.equal(launchOptions([],catalog).experience,'viewer');
  // --experience=menu --smoke runs headlessly and forwards --smoke after '--'.
  const smoke=launchOptions(['--experience=menu','--smoke'],catalog);
  assert.deepEqual(smoke.args,['--headless','--audio-driver','Dummy','--path','godot','res://ui/main_menu.tscn']);
  assert.deepEqual(smoke.sessionOptions,['--smoke']);
  assert.equal(smoke.smoke,'--smoke');
  // Parameterless: stray keys and flags are rejected, --debug-panel included.
  for(const args of [['--map=meridian-exchange'],['--mode=deathmatch'],['--bots=2'],['--round-seconds=60'],
    ['--score-limit=30'],['--waves=1'],['--time-limit=60'],['--endpoint=ws://127.0.0.1:1234'],
    ['--setup'],['--play'],['--mute'],['--debug-hud'],['--native-trace'],['--session-smoke'],
    ['--network-smoke'],['--debug-panel'],['--debug-panel','--smoke']]){
    assert.throws(()=>launchOptions(['--experience=menu',...args],catalog),Error,args.join(' '));
  }
});

test('world traversal and command board remain distinct native scenes',()=>{
  const world=launchOptions(['--experience=lattice-world','--map=monsoon-foundry','--mode=cocs-coop'],catalog);
  assert.ok(world.args.includes('res://lattice/world_demo.tscn'));
  assert.deepEqual(world.sessionOptions,['--map=monsoon-foundry','--mode=cocs-coop','--time-limit=900','--bots=2','--operator=chatgpt','--harness=openclaw']);
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
  const full=launchOptions(['--experience=identity-zones','--bots=24','--diagnostics'],catalog);
  assert.ok(full.sessionOptions.includes('--bots=24'));
  assert.ok(full.sessionOptions.includes('--diagnostics'));
  for(const args of [['--map=lacuna-court'],['--mode=koth'],['--bots=25'],['--round-seconds=59'],['--score-limit=0'],['--score-limit=901'],['--time-limit=60'],['--round-target=5'],['--play']]){
    assert.throws(()=>launchOptions(['--experience=identity-zones',...args],catalog),Error,args.join(' '));
  }
});

test('dev launcher mirrors owned route bot and diagnostics bounds',()=>{
  const dm=launchOptions(['--experience=native-dm','--bots=24','--diagnostics','--debug-panel'],catalog);
  assert.equal(dm.bots,24);
  assert.ok(dm.sessionOptions.includes('--debug-panel'));
  assert.ok(dm.sessionOptions.includes('--diagnostics'));
  assert.throws(()=>launchOptions(['--experience=native-dm','--bots=25'],catalog),/bots/);
  const combat=launchOptions(['--experience=combat','--bots=8'],catalog);
  assert.ok(combat.sessionOptions.includes('--bots=8'));
  assert.throws(()=>launchOptions(['--experience=combat','--bots=9'],catalog),/bots/);
  assert.throws(()=>launchOptions(['--experience=lobby','--bots=4'],catalog),/bots/);
  assert.throws(()=>launchOptions(['--experience=lobby','--debug-panel'],catalog),/debug-panel/);
});

test('LATTICE dev/package argv and native flags are equivalent and validate host/guest contracts',()=>{
  for(const experience of ['lattice','lattice-world']) for(const map of ['asterion-relay','monsoon-foundry']) for(const mode of ['cocs','cocs-coop']) {
    const argv=[`--experience=${experience}`,`--map=${map}`,`--mode=${mode}`,'--time-limit=900','--bots=7','--operator=claude','--harness=claudecode',...(experience==='lattice-world'?['--native-trace','--diagnostics']:[])];
    const dev=launchOptions(argv,catalog), pkg=packageOptions(argv,catalog);
    assert.deepEqual(dev.sessionOptions,pkg.userArgs); assert.equal(dev.endpoint,pkg.endpoint);
    assert.equal(dev.args.at(-1),pkg.scene);
  }
  for(const rung of ['4v4','8v8']) for(const experience of ['lattice','lattice-world']) {
    const argv=[`--experience=${experience}`,'--rung='+rung];
    assert.ok(launchOptions(argv,catalog).sessionOptions.includes('--rung='+rung));
    assert.ok(packageOptions(argv,catalog).userArgs.includes('--rung='+rung));
  }
  for(const bad of [['--map=unknown'],['--mode=nope'],['--time-limit=59'],['--time-limit=901'],['--bots=17'],['--rung=4v4','--bots=1'],['--mode=cocs-coop','--rung=8v8'],['--operator=claude'],['--operator=claude','--harness=openclaw'],['--join-room=r','--endpoint=ws://localhost:2','--bots=3']]) {
    const argv=['--experience=lattice-world',...bad]; assert.throws(()=>launchOptions(argv,catalog),Error,JSON.stringify(bad)); assert.throws(()=>packageOptions(argv,catalog),Error,JSON.stringify(bad));
  }
  const guest=['--experience=lattice-world','--endpoint=ws://127.0.0.1:4321','--join-room=room-a'];
  assert.deepEqual(launchOptions(guest,catalog).sessionOptions,packageOptions(guest,catalog).userArgs);
  assert.throws(()=>launchOptions(['--experience=lattice-world','--join-room=room-a'],catalog),/endpoint/);
  assert.throws(()=>packageOptions(['--experience=lattice-world','--join-room=room-a'],catalog),/endpoint/);
});
