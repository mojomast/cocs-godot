// Controlled production-authority replay, not organic play or a network journey.
import {createTrailerFixture} from '../../../tools/godot-campaign/trailer-fixture.mjs';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
import assert from 'node:assert/strict';
const out=process.env.ASSET_STAGE_EVIDENCE;
assert.ok(out,'Use the granted bounded production runner');
const plan=JSON.parse(readFileSync('port/finish/ASSET_PRODUCTION.json'));
const summary=[];
for(const [id,kind] of [['skirmisher','combat'],['bulwark','melee'],['mortar','artillery']]){
  const directory=join(out,id);mkdirSync(directory);
  const shot={id,map:'emberline-ascent',seconds:6,kind,camera:'external'};
  const fixture=createTrailerFixture(shot,420930), records=[];
  let damage=0,tells=0,deaths=0,shots=0;
  for(let i=0;i<72;i++){
    const record=fixture.step(i,12);records.push(record);
    for(const event of record.events){
      if(event.type==='damage')damage++;
      if(event.type==='death')deaths++;
      if(event.type==='enemy-telegraph')tells++;
      if(['shot','launch','melee'].includes(event.type))shots++;
    }
  }
  const replay=JSON.stringify({header:fixture.header,records}), source=join(directory,'replay.json');
  writeFileSync(source,replay);
  assert.ok(records.some(r=>r.state.actors.some(a=>a.npcModel===id)),id+' source actor');
  if(kind!=='artillery')assert.ok(damage>0,id+' real source damage');
  else assert.ok(tells>0,'source mortar telegraph');
  const args=['-a','-s','-screen 0 1280x800x24',plan.tools.godot,'--path','godot','--rendering-method','gl_compatibility','--audio-driver','Dummy',
    '--script','res://tests/robot_assets/production_capture.gd','--','--map=emberline-ascent','--mode=campaign','--mute','--endpoint=ws://127.0.0.1:1/native-campaign',`--robot-replay=${source}`,`--robot-output=${directory}`];
  const result=spawnSync('xvfb-run',args,{encoding:'utf8',timeout:180000,maxBuffer:16*1024*1024,env:process.env});
  writeFileSync(join(directory,'native.log'),result.stdout+'\n'+result.stderr);
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.ok(!/SCRIPT ERROR|^ERROR:/m.test(result.stdout+result.stderr));
  const receipt=JSON.parse(readFileSync(join(directory,'native.json')));
  assert.equal(receipt.frames.length,72);assert.equal(receipt.workshop.length,6);
  assert.ok(receipt.skins.some(s=>s.role===id),id+' actual production factory skin');
  summary.push({id,kind,damage,tells,deaths,shots,sourceSHA256:createHash('sha256').update(replay).digest('hex'),receipt});
}
writeFileSync(join(out,'production.json'),JSON.stringify({kind:'controlled production-authority replay with validated source FIFO inputs',network:false,human:false,summary},null,2));
console.log('SWITCHYARD_PRODUCTION_CAPTURE_OK',summary.map(s=>({id:s.id,damage:s.damage,tells:s.tells,deaths:s.deaths,frames:s.receipt.frames.length})));
