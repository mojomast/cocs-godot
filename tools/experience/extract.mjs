// Read-only source extraction. Run from repository root; --check never writes.
import fs from 'node:fs';
import vm from 'node:vm';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {audioCaption, captionPriority, acceptCaption, CAPTION_TTL, killFeedBadges, weaponRangeLabel} from '../../game/hud.mjs';
import {WEAPONS} from '../../game/data.mjs';
const source = fs.readFileSync('game/hud.mjs', 'utf8');
const literal = source.match(/const CAPTION_EVENTS = Object.freeze\((.*)\);/)[1];
const types = Object.keys(vm.runInNewContext(`(${literal})`));
const captions = Object.fromEntries(types.map(type => [type, {text: audioCaption({type})?.text ?? '', priority: captionPriority({type})}]));
const sha256 = crypto.createHash('sha256').update(source).digest('hex');
const samples = [
  {type:'pickup'}, ...['health','armor','ammo','megahealth','rifle'].map(kind=>({type:'pickup',kind})),
  {type:'spawn'}, {type:'spawn',actor:0}, {type:'damage'},
  ...['overseer','mender','flanker','phalanx','sapper','artillery','boss','unknown'].map(kind=>({type:'enemy-telegraph',kind})),
  ...Array.from({length:10},(_,weapon)=>({type:'shot',alt:true,weapon})),
  {type:'charge',state:'ready'}, {type:'charge'}, {type:'weather-change',kind:'rain'}, {type:'time-change',phase:'night'},
];
const priorities = [...new Set(Object.values(captions).map(c=>c.priority))];
const replacement = [];
for (const currentPriority of priorities) for (const priority of priorities) for (const age of [-1,0,1,2.199,2.2,3]) for (const same of [true,false]) {
  const current = {text:'First',priority:currentPriority,at:10};
  const candidate = {text:same?'First':'Next',priority};
  replacement.push({current,candidate,at:10+age,expected:acceptCaption(current,10,candidate,10+age)});
}
const badges = [null,{}, {self:true,overkill:90}, {fall:true,assist:true}, {assist:true,victimStreak:2,overkill:55,killerStreak:3}, {victimStreak:1,overkill:54,killerStreak:1}].map(entry=>({entry,expected:killFeedBadges(entry).map(b=>b.label)}));
const outputs = {
  'godot/experience/source_catalog.json': {source:'game/hud.mjs',sha256,ttl:CAPTION_TTL,captions,alt:Array.from({length:10},(_,weapon)=>audioCaption({type:'shot',alt:true,weapon}).text),ranges:WEAPONS.map(weaponRangeLabel)},
  'godot/tests/experience/source_fixture.json': {sha256,samples:samples.map(event=>({event,expected:audioCaption(event)?.text??''})),replacement,badges},
};
for (const [path,value] of Object.entries(outputs)) {
  const bytes=JSON.stringify(value,null,2)+'\n';
  if (process.argv.includes('--check')) assert.equal(fs.readFileSync(path,'utf8'),bytes,path);
  else {fs.mkdirSync(path.slice(0,path.lastIndexOf('/')),{recursive:true});fs.writeFileSync(path,bytes);}
}
console.log(`EXPERIENCE_SOURCE_OK ${types.length} captions, ${replacement.length} replacement cases, ${WEAPONS.length} weapon ranges; ${sha256}`);
