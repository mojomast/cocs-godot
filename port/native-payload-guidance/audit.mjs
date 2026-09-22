import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,readdirSync,existsSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import {connect} from 'node:net';
const root='port/native-payload-guidance',sha=b=>createHash('sha256').update(b).digest('hex');
const json=p=>JSON.parse(readFileSync(p));
const finalRenderer=readFileSync('godot/objectives/renderer.gd','utf8').replace(/\n\t{4}if role == "DEFEND" and status == "IDLE":[\s\S]*?\n\t{5}hud_model.hint = "Living players near cart affect progress · Both teams nearby stop it"/, '');
// Exact live product source predates only the rollback-category compatibility copy.
const liveRenderer=finalRenderer.replace('\t\t\t\t# Keep the accepted rollback category, including the arrival-at-bank\n\t\t\t\t# snapshot, while explicitly distinguishing its stationary limit.\n\t\t\t\tvar display_status := status\n\t\t\t\tif status == "HOLDING CHECKPOINT": display_status = "ROLLING BACK: CHECKPOINT LIMIT"\n\t\t\t\telif status == "HOLDING START": display_status = "ROLLING BACK: START LIMIT"\n\t\t\t\thud_model.title = "PAYLOAD · %s · YOU: %s · %s" % [role, team_name(local_team), display_status]', '\t\t\t\thud_model.title = "PAYLOAD · %s · YOU: %s · %s" % [role, team_name(local_team), status]');
const initialHud=readFileSync('godot/objectives/hud.gd','utf8').replace('\tcart_guidance.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING\n\tcart_guidance.custom_minimum_size.y = 20\n','');
const liveGuidance=readFileSync('godot/objectives/guidance.gd','utf8').replace('Dead · Wait for respawn','Dead · Respawn to escort').replace(' and p.checkpointsReached <= zones.size() and p.checkpointsReached == floor(p.checkpointsReached)','');
const reports=[];
const firstDriver=readFileSync('godot/tests/objectives/guidance_live.gd','utf8')
 .replace('var taking_shot := false\n','')
 .replace(/func shot\(tag: String\) -> void:[\s\S]*?(?=func on_snapshot)/,`func shot(tag: String) -> void:
	if captured.has(tag): return
	captured[tag] = true
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(output.replace(".png","-"+tag+".png"))
	var p: Dictionary = state.objectives.payload
	var cart := Vector3(p.position.x,p.position.y,p.position.z)
	print("GUIDANCE_SHOT ",JSON.stringify({"tag":tag,"error":error,"seq":sequence,"time":state.time,"actor":presentation.local_actor,"payload":p,"model":objectives.hud_model,"guidance":objective_hud.cart_guidance.text,"camera":[camera.position.x,camera.position.y,camera.position.z],"projected":[camera.unproject_position(cart).x,camera.unproject_position(cart).y],"behind":camera.is_position_behind(cart),"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED}))

`)
 .replace('if finishing or taking_shot: return','if finishing: return')
 .replace('await shot("off-cart" if position.distance_to(cart) > p.radius else "spawn-in-range")','await shot("off-cart")')
 .replace('if not captured.has("off-cart") and position.distance_to(cart) > 12: shot("off-cart")\n\t\t\telif index > 0','if index > 0')
 .replace('captured.has("off-cart") and captured.has("approach")','captured.has("approach")');
for(const id of ['77dd0c9f-a066-4bad-84b2-c258d1932e3b','a3cec2b2-e154-4d7e-8468-87f070d4ef41']){
 const dir=`${root}/evidence/${id}`,launch=json(dir+'/launch.json'),summary=json(dir+'/summary.json'),archive=json(dir+'/archive.json');
 const initial=id.startsWith('77dd');
 assert.equal(sha(liveRenderer),launch.hashes['godot/objectives/renderer.gd']);
 writeFileSync(dir+'/live-renderer.gd.txt',liveRenderer);
 assert.equal(sha(liveGuidance),launch.hashes['godot/objectives/guidance.gd']);writeFileSync(dir+'/live-guidance.gd.txt',liveGuidance);
 if(initial){
  assert.equal(sha(initialHud),launch.hashes['godot/objectives/hud.gd']);writeFileSync(dir+'/live-hud.gd.txt',initialHud);
  assert.equal(sha(firstDriver),launch.hashes['godot/tests/objectives/guidance_live.gd']);writeFileSync(dir+'/live-driver.gd.txt',firstDriver);
 }
 const mismatches=[];
 for(const [path,expected] of Object.entries(launch.hashes)){
  if(sha(readFileSync(path))!==expected)mismatches.push(path);
 }
 assert.ok(mismatches.every(p=>p==='godot/objectives/renderer.gd'||p==='godot/objectives/guidance.gd'||(initial&&p==='godot/objectives/hud.gd')||p.startsWith('godot/tests/objectives/guidance_')),'all non-guidance source/runtime unchanged');
 const logs={};for(const [name,meta] of Object.entries(archive)){const raw=gunzipSync(readFileSync(dir+'/'+name+'.gz'));assert.equal(raw.length,meta.bytes);assert.equal(sha(raw),meta.sha256);logs[name]=raw.toString();}
 assert.ok(!/SCRIPT ERROR|Parse Error|ERROR:/.test(logs['native.stdout.log']+logs['native.stderr.log']));
 const rows=logs['wire.jsonl'].trim().split('\n').map(JSON.parse),wire=new Map(rows.filter(r=>r.type==='snapshot').map(r=>[r.seq,r]));
 const parse=prefix=>logs['native.stdout.log'].split('\n').filter(x=>x.startsWith(prefix)).map(x=>JSON.parse(x.slice(prefix.length)));
 const natives=parse('OBJECTIVE_NATIVE ');
 for(const n of natives){
  const w=wire.get(n.snapshot_seq);assert.ok(w);
  const a=w.state.actors.find(a=>a.id===n.actor_id);assert.ok(a);
  for(const axis of ['x','y','z']){assert.ok(Math.abs(a[axis]-n.actor[axis])<1e-4);assert.ok(Math.abs(w.state.objectives.payload.position[axis]-n.rendered.cart[axis])<1e-4);}
 }
 const shots=parse('GUIDANCE_SHOT ');
 const observed=[];
 for(const s of shots){
  const w=wire.get(s.seq);assert.ok(w);assert.deepEqual(s.payload,w.state.objectives.payload);assert.equal(s.error,0);
  const a=w.state.actors.find(a=>a.id===s.actor.id),p=s.payload;
  const distance=Math.hypot(a.x-p.position.x,a.z-p.position.z);
  const image=`guidance-${s.tag}${initial?'':`-${s.size[0]}x${s.size[1]}`}.png`;
  const png=readFileSync(dir+'/'+image),size=[png.readUInt32BE(16),png.readUInt32BE(20)];
  assert.deepEqual(size,initial?[960,640]:s.size);
  if(!initial){
   assert.ok(s.guidance_height>=20);assert.ok(s.guidance.includes('Cart '));
   const displayDistance=Number(s.guidance.match(/· ([\d.]+) m away/)[1]);assert.ok(Math.abs(displayDistance-distance)<.25);
   if(s.tag==='off-cart'||s.tag==='approach'){assert.ok(distance>p.radius);assert.ok(s.guidance.includes('Get within 4.5 m'));}
   if(s.tag==='escorting'||s.tag==='release'){assert.ok(distance<=p.radius&&a.health>0&&Math.abs(a.y-p.position.y)<=5);assert.equal(p.pushing,w.state.objectives.attacker);assert.equal(p.contested,false);assert.ok(s.guidance.includes('Inside 4.5 m range'));}
   if(s.tag==='release'){assert.equal(s.captured,false);assert.ok(s.guidance.includes('Controls released'));}
   if(s.tag==='escorting')assert.equal(s.captured,true);
   if(s.guidance.startsWith('Cart Right')&&!s.behind)assert.ok(s.projected[0]>size[0]/2);
   if(s.guidance.startsWith('Cart Left')&&!s.behind)assert.ok(s.projected[0]<size[0]/2);
  }
  observed.push({image,seq:s.seq,time:s.time,distance,pushing:p.pushing,guidance:s.guidance,sha256:sha(png)});
 }
 if(!initial){assert.equal(shots.length,8);for(const tag of ['off-cart','approach','escorting','release'])assert.equal(shots.filter(s=>s.tag===tag).length,2);}
 const snapshots=[...wire.values()],first=snapshots[0],last=snapshots.at(-1);
 const sourceSeconds=last.state.time-first.state.time,wallSeconds=(last.wall-first.wall)/1000;
 assert.ok(Math.abs(sourceSeconds-wallSeconds)<1,'normal-rate source/wall comparison');
 assert.ok(summary.elapsed<=120&&summary.portClosed&&summary.serverClosed&&summary.sockets===0&&summary.temporaryTreeRemoved);
 for(const p of summary.cleanup){assert.ok(p.absent&&p.reaped);assert.ok(!existsSync(`/proc/${p.pid}`));}
 const closed=await new Promise(r=>{const s=connect(summary.port,'127.0.0.1');s.once('connect',()=>{s.destroy();r(false);});s.once('error',()=>r(true));});assert.ok(closed);
 reports.push({id,visual:initial?'FAIL: zero-height label; all original evidence retained':'PASS: eight PNGs directly reviewed',elapsed:summary.elapsed,sourceSeconds,wallSeconds,nativeSourceMatches:natives.length,observed,currentFileDifferences:mismatches,cleanupRechecked:true});
}
function files(dir){return readdirSync(dir,{withFileTypes:true}).flatMap(d=>d.isDirectory()?files(dir+'/'+d.name):[dir+'/'+d.name]);}
const finalFiles=['godot/objectives/guidance.gd','godot/objectives/hud.gd','godot/objectives/renderer.gd',...files('godot/content/generated')];
writeFileSync(root+'/audit.json',JSON.stringify({scope:'bounded presentation observations; archived/fixture completion separate',reports,finalRuntimeAndGeneratedHashes:Object.fromEntries(finalFiles.map(p=>[p,sha(readFileSync(p))]))},null,2)+'\n');
console.log('PASS: two owned runs audited; first visual failure retained, final eight-image observation passed');
