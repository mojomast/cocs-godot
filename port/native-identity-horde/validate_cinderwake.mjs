// Source- and scene-correlated Cinderwake acceptance. The controlled source
// fixtures remain separate; this validator consumes only ordinary socket,
// product-observer and exported engine evidence from a bounded live run.
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import {dirname,resolve} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {validateRun} from '../native-horde/validate.mjs';
import {readCinderwake} from '../native-horde/cinderwake-schema.mjs';

const lines=(text,prefix)=>text.split('\n').filter(line=>line.startsWith(prefix)).map(line=>JSON.parse(line.slice(prefix.length)));

export function verifyStageSequence(events,snapshots,nativeGates,scenario){
  const waveClears=events.filter(item=>item.type==='horde-wave-cleared');
  assert(snapshots.length>20,'source stage snapshots absent');
  const stages=snapshots.map(row=>row.frame.state.singleplayer.stage);
  assert(stages.every(stage=>stage&&Number.isInteger(stage.geometryRevision)&&Number.isInteger(stage.gateMask)),
    'source stage/revision absent');
  assert(stages[0].stageId==='B'&&stages[0].gateMask===0,'first stage must start with both gates closed');
  assert(nativeGates.some(row=>row.revision===0&&row.gateMask===0&&row.nativeGateVisible?.every(Boolean)),
    'native bodies did not start closed');
  if(!['waves','stages'].includes(scenario))return {stages:['B'],initialGatesClosed:true};
  const clear=waveClears.find(item=>item.wave===2);
  const begin=events.find(item=>item.type==='horde-transit-begin'&&item.from==='B'&&item.to==='C');
  // The wire event itself has a global `id`; its `sourceId` retains the
  // transit's local ID because source emits `{...transit}` at begin.
  const opened=events.find(item=>item.type==='horde-gate-open'&&item.transitId===begin?.sourceId&&item.gateMask===1);
  const entered=events.find(item=>item.type==='horde-stage-entered'&&item.stageId==='C'&&item.transitId===begin?.sourceId);
  assert(clear&&begin&&opened&&entered,'wave-2 source transition incomplete');
  assert.equal(begin.causeEventId,clear.sourceId,'transit lacks the wave-clear cause event');
  assert.equal(entered.causeEventId,clear.sourceId,'arrival lacks the same wave-clear cause');
  assert(clear.time<=begin.time&&begin.time+2.99<=opened.time&&opened.time<entered.time,
    'warning/open/arrival ordering or three-second warning changed');
  assert(entered.arrivalTicks>=30,'source grounded arrival hold missing');
  const travel=snapshots.find(row=>row.frame.state.singleplayer.stage.transit?.phase==='travel');
  const arrived=snapshots.find(row=>row.frame.state.singleplayer.stage.stageId==='C');
  assert(travel&&arrived&&travel.frame.state.singleplayer.wave===2&&arrived.frame.state.singleplayer.wave===2,
    'source transition skipped wave-clear travel');
  assert(travel.frame.state.singleplayer.stage.gateMask===1&&arrived.frame.state.singleplayer.stage.gateMask===1,
    'source gate mask does not match authored B→C transition');
  assert(nativeGates.some(row=>row.gateMask===1&&row.revision===1&&row.nativeGateVisible?.[0]===false&&row.nativeGateVisible?.[1]===true),
    'native gate did not open from the source revision');
  assert(snapshots.some(row=>row.frame.state.singleplayer.wave>=3&&row.frame.state.singleplayer.stage.stageId==='C'),
    'wave 3 did not begin in the destination stage');
  if(scenario==='stages'){
    const clear5=waveClears.find(item=>item.wave===5);
    const begin2=events.find(item=>item.type==='horde-transit-begin'&&item.from==='C'&&item.to==='D');
    const opened2=events.find(item=>item.type==='horde-gate-open'&&item.transitId===begin2?.sourceId&&item.gateMask===3);
    const entered2=events.find(item=>item.type==='horde-stage-entered'&&item.stageId==='D'&&item.transitId===begin2?.sourceId);
    assert(clear5&&begin2&&opened2&&entered2,'wave-5 C→D source transition incomplete');
    assert.equal(begin2.causeEventId,clear5.sourceId,'C→D warning lacks wave-5 clear cause');
    assert.equal(entered2.causeEventId,clear5.sourceId,'D arrival lacks wave-5 cause');
    assert(begin2.time+2.99<=opened2.time&&opened2.time<entered2.time&&entered2.arrivalTicks>=30,
      'C→D warning/open/grounded arrival ordering failed');
    assert(snapshots.some(row=>row.frame.state.singleplayer.stage.stageId==='D'&&
      row.frame.state.singleplayer.stage.gateMask===3),'source D stage/snapshot absent');
    assert(nativeGates.some(row=>row.gateMask===3&&row.nativeGateVisible?.every(value=>value===false)),
      'native CD slab did not open from source revision');
    return {stages:['B','C','D'],causeEventIds:[clear.sourceId,clear5.sourceId],
      warningSeconds:[opened.time-begin.time,opened2.time-begin2.time],
      arrivalTicks:[entered.arrivalTicks,entered2.arrivalTicks]};
  }
  return {stages:['B','C'],causeEventId:clear.sourceId,warningSeconds:opened.time-begin.time,
    arrivalTicks:entered.arrivalTicks,openedRevision:1};
}

export function validateCinderwakeRun({wire,stdout,stderr,summary,launch}){
  assert.equal(summary.exit,0,'Cinderwake run did not complete cleanly');
  assert.equal(summary.map,'cinderwake-drydock');
  assert.equal(launch.map,summary.map);
  assert.equal(launch.localOnly,true);
  const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
  const lock=JSON.parse(readFileSync(resolve(root,'port/contracts/source-lock.json')));
  assert.equal(launch.source,lock.source_commit,'observer must use selected source ancestry');
  for(const path of ['game/horde-stages.mjs','godot/horde_maps/generated/cinderwake-drydock.json',
    'godot/horde_maps/cinderwake.gd','godot/horde_maps/demo.gd',
    'godot/tests/horde/cinderwake_live.gd','godot/tests/horde/identity_live.gd']){
    assert.equal(launch.hashes[path],createHash('sha256').update(readFileSync(resolve(root,path))).digest('hex'),
      `evidence captured with stale ${path}`);
  }
  assert.equal(summary.serverClosed,true);
  assert.equal(summary.sockets,0);
  assert.equal(summary.temporaryTreeRemoved,true);
  const recipe=readCinderwake();
  const snapshots=wire.filter(row=>row.direction==='out'&&row.frame?.type==='snapshot'&&row.round===1);
  assert(snapshots.every(row=>row.frame.hordeMapContract?.geometryHash===recipe.geometryHash&&
    row.frame.hordeMapContract?.planHash===recipe.planHash),'source/scene recipe hash mismatch');
  const starts=wire.filter(row=>row.direction==='out'&&row.frame?.type==='start');
  assert(starts.length>=1&&starts.every(row=>row.frame.hordeMapContract?.geometryHash===recipe.geometryHash&&
    row.frame.hordeMapContract?.planHash===recipe.planHash),'source start contract mismatch');
  const base=validateRun({wire,stdout,stderr,summary,launch,
    expected:{scene:'res://horde_maps/demo.tscn',script:'res://horde_maps/demo.gd',interpolatedRemote:true}});
  const events=wire.filter(row=>row.direction==='out'&&row.frame?.type==='events'&&row.round===1).flatMap(row=>row.frame.items);
  const stage=verifyStageSequence(events,snapshots,lines(stdout,'CINDERWAKE_GATE '),summary.scenario);
  assert(base.clockDiagnostic.sourceSeconds<=base.clockDiagnostic.wallSeconds*1.15+3,
    'source simulation ran faster than the normal-rate wall clock');
  const scene=lines(stdout,'CINDERWAKE_STAGE ');
  assert(scene.length===1&&scene[0].map===summary.map&&scene[0].nativeGateCount===2&&scene[0].stage==='B',
    'actual Cinderwake product did not load its two native gates');
  if(summary.scenario==='waves'){
    assert(summary.waves>=3,'source stage acceptance requires a later wave');
    const result=wire.find(row=>row.direction==='out'&&row.frame?.type==='results'&&row.round===1)?.frame.state;
    assert(result?.singleplayer.phase==='won'&&result.singleplayer.wave===summary.waves,
      'natural source result missing');
    assert(lines(stdout,'IDENTITY_RESTART ').some(row=>row.rounds===2&&row.results===1&&row.captured===false),
      'clean source restart missing');
    assert(lines(stdout,'CINDERWAKE_TRAVEL ').some(row=>row.from==='B'&&row.to==='C'&&row.waypoints>=4),
      'ordinary-input authored travel absent');
  }
  return {status:'PASS',scenario:summary.scenario,map:summary.map,source:launch.source,
    stage,receiptCount:base.receipts,steppedSamples:base.steppedSamples,engine:launch.binary,
    sourceSeconds:base.clockDiagnostic.sourceSeconds,wallSeconds:base.clockDiagnostic.wallSeconds};
}

if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
  const dir=process.argv[2];
  assert(dir,'Provide the bounded Cinderwake evidence directory');
  const text=name=>gunzipSync(readFileSync(`${dir}/${name}.gz`)).toString();
  const result=validateCinderwakeRun({wire:text('wire.jsonl').trim().split('\n').map(JSON.parse),
    stdout:text('native.stdout.log'),stderr:text('native.stderr.log'),
    summary:JSON.parse(readFileSync(`${dir}/summary.json`)),launch:JSON.parse(readFileSync(`${dir}/launch.json`))});
  writeFileSync(`${dir}/validation.json`,`${JSON.stringify(result,null,2)}\n`);
  console.log(JSON.stringify(result));
}
