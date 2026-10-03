// Source-only snapshot of the explicitly reviewed foundation and released K
// metadata. Never consult the active L worktree or generate import cache paths.
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,existsSync,mkdirSync,copyFileSync} from 'node:fs';
import {dirname} from 'node:path';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
const foundation='8921ed41',previous='5b5c8791';
const hash=b=>createHash('sha256').update(b).digest('hex');
const git=(rev,p)=>execFileSync('git',['show',`${rev}:${p}`],{maxBuffer:128*1024*1024});
const read=p=>readFileSync(p),write=(p,b)=>{mkdirSync(dirname(p),{recursive:true});writeFileSync(p,b);};
const groups={
 nativeCorrections:['godot/input_bindings/settings_panel.gd','godot/ui/main_menu.gd','godot/source_operators/locomotion.gd','godot/source_operators/melee_events.gd','godot/source_operators/operator_visual.gd','godot/world/presentation.gd','godot/multiplayer_worlds/sports_demo.gd','tools/godot-multiplayer/generate-scenes.mjs'],
 opaqueWeather:['godot/moth/surface.gdshader','godot/moth/surfaces.gd','godot/ambience/weather_look.gd','godot/ambience/wet_surface.gd','godot/world/environment_style.gd'],
 supportCues:['godot/graphics_fx/moth_world.gd','godot/world/combat_feedback.gd'],
 explosionFallback:['godot/weapon_effects/controller.gd'],muzzleSheets:['godot/weapon_effects/flash.gdshader'],
 identityAtmosphere:['godot/native_arenas/identity_environment.gd'],
 lobby:['godot/social/room_browser.gd','godot/ui/lobby_choice.gd','godot/ui/lobby_menu.gd','godot/ui/match_setup.gd'],
};
const changed={};for(const [reason,paths]of Object.entries(groups))for(const p of paths){const bytes=git(foundation,p);assert.deepEqual(read(p),bytes);changed[p]={before:hash(git(previous,p)),after:hash(bytes),reason};}
const shader='godot/moth/surface_opaque.gdshader';assert.deepEqual(read(shader),git(foundation,shader));
const added={[shader]:hash(read(shader))};
assert.equal(execFileSync('git',['diff','--name-only',previous,foundation,'--','game/','server/','port/multiplayer-worlds/derived/','port/multiplayer-worlds/wall_candidates.mjs','*.glb','*.blend','*.png'],{encoding:'utf8'}),'','Authority or authored asset changed');
const evidenceRoot='/home/mojo/.tmp-on-disk/cocs-motion-native-evidence-20261003/';
const archive='port/finish/polish/package-evidence-k/';
const evidence={};
for(const p of ['moth-import-policy.json','generated-sidecars-final/manifest.json','k-finish-binder/queue.json','k-finish-binder/operator-finish/native.log','release-K.json','NATIVE_RESULTS_K.json']){
 const bytes=read(evidenceRoot+p),dest=archive+p;write(dest,bytes);evidence[dest]=hash(bytes);
}
const policy=JSON.parse(read(evidenceRoot+'moth-import-policy.json'));
const manifest=new Set(JSON.parse(read(evidenceRoot+'generated-sidecars-final/manifest.json')));
const tracked=new Set(execFileSync('git',['ls-tree','-r','--name-only',foundation,'--','godot/source_operators/moth_finish/'],{encoding:'utf8'}).trim().split('\n'));
const pngs=[...tracked].filter(p=>p.startsWith('godot/source_operators/moth_finish/assets/')&&p.endsWith('.png')).sort();
assert.equal(policy.length,116);assert.deepEqual(policy.map(r=>r.path).sort(),pngs);
const imports={},pending=[];
for(const row of policy){
 const p=row.path,sidecar=p+'.import';assert.equal(row.sidecarExists,true);assert.equal(row.sidecarTracked,false);
 assert.deepEqual(row.parameters,['compress/mode=0','compress/normal_map=0']);assert.equal(hash(git(foundation,p)),row.sha256);assert.equal(hash(read(p)),row.sha256);
 assert.ok(manifest.has(sidecar));assert.ok(!tracked.has(sidecar),'Metadata must be untracked at reviewed foundation');
 const bytes=read(evidenceRoot+'generated-sidecars-final/'+sidecar),text=bytes.toString();
 for(const line of [`source_file="res://${p.slice(6)}"`,'importer="texture"','compress/mode=0','compress/normal_map=0','process/normal_map_invert_y=false','process/size_limit=0'])assert.ok(text.split('\n').includes(line),sidecar+': '+line);
 imports[p]={sha256:row.sha256,sidecar,sidecarSHA256:hash(bytes)};pending.push([sidecar,bytes]);
}
for(const [p,bytes]of pending){
 if(existsSync(p)&&!read(p).equals(bytes)){
  const dest='/tmp/opencode/scenery-pre-polish-sidecars/'+p;
  if(existsSync(dest))assert.deepEqual(read(dest),read(p),'Backup collision');else{mkdirSync(dirname(dest),{recursive:true});copyFileSync(p,dest);}
 }
 write(p,bytes);
}
const finishData=[...tracked].filter(p=>p==='godot/source_operators/moth_finish/manifest.json'||/^godot\/source_operators\/moth_finish\/profiles\/[^/]+\.json$/.test(p)).sort();
assert.equal(finishData.length,10);
const data=Object.fromEntries(finishData.map(p=>[p,hash(git(foundation,p))]));
const snapshot={foundation,previous,scope:'supporting package dependency reconciliation only; combined polish native checks pending',changed,added,operatorFinish:{policy:'track only the 116 exact released-K sidecars; no reimport, cache fabrication or normal enum changes',imports,data},evidence};
write('tools/godot-package/polish_8921_inventory.json',JSON.stringify(snapshot,null,2)+'\n');
console.log(JSON.stringify({changed:Object.keys(changed).length,added:Object.keys(added).length,operatorPNGs:pngs.length,sidecars:pending.length,finishData:finishData.length,snapshotSHA256:hash(read('tools/godot-package/polish_8921_inventory.json'))}));
