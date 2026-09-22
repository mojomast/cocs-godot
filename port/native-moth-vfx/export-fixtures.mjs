// Read-only source extraction; these are renderer fixtures, never live gameplay.
import {writeFileSync, mkdirSync, readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {MOTH_BAKED} from '../../game/moth-baked.mjs';
import {Match} from '../../game/core.mjs';
// Import the exact self-contained cursor class without opening/loading transport
// dependencies. Fail if the source boundaries change; do not duplicate its logic.
const authority = readFileSync(new URL('../native-horde/authority.mjs',import.meta.url),'utf8');
const cursorCode = authority.slice(authority.indexOf('export class EventCursor {'),authority.indexOf('export function outboundAllowed'));
assert(cursorCode.startsWith('export class EventCursor {'));
const {EventCursor} = await import(`data:text/javascript;base64,${Buffer.from(cursorCode).toString('base64')}`);

const out = new URL('../../godot/tests/graphics_fx/', import.meta.url);
mkdirSync(out, {recursive:true});
const effects = Object.fromEntries(['spark-impact','effect-explosion','effect-teleport','effect-heal'].map(key => [key,MOTH_BAKED.effects[key]]));
const pixels = [];
for (const [name, sheet] of Object.entries(effects)) for (const [index, frame] of sheet.frames.entries()) {
  const bytes = Buffer.from(frame.data, 'base64');
  assert.equal(bytes.length,frame.width*frame.height*4);
  const rgba = new Set(), alpha = new Set();
  for(let i=0;i<bytes.length;i+=4){rgba.add(bytes.subarray(i,i+4).toString('hex'));alpha.add(bytes[i+3]);}
  assert(rgba.size>20, `${name} is not a flat fixture`);
  pixels.push({name,index,width:frame.width,height:frame.height,fps:sheet.fps,colors:rgba.size,alpha:[...alpha],sha256:createHash('sha256').update(bytes).digest('hex')});
}
writeFileSync(new URL('frames.json',out),JSON.stringify(effects));

// Exercise the actual source emit envelope and actual production Horde cursor.
// The payloads below are explicit fixtures matching core.mjs/singleplayer.mjs.
const source={serial:0,time:1,events:[],emit:Match.prototype.emit};
const cursor=new EventCursor();
const at=(x,y,z)=>({x,y,z});
source.emit('damage',{actor:7,source:2,amount:25,shield:0,shieldBreak:false});
source.emit('explosion',{pos:at(-1.8,1.5,0),weapon:1});
source.emit('teleport',{actor:7,id:'fixture-pad',from:at(1.8,1.5,0),to:at(1.8,1.5,-8)});
source.emit('pickup',{actor:8,kind:'health',powerup:false,economy:false});
source.emit('mender-heal',{actor:9,x:5.4,z:-8,radius:3,healed:2});
const events=cursor.take(source);
assert.deepEqual(cursor.take(source),[]);
source.emit('teleport',{actor:7,id:'same-pad',from:at(0,0,0),to:at(1,0,0)});
source.emit('teleport',{actor:7,id:'same-pad',from:at(0,0,0),to:at(1,0,0)});
const duplicates=cursor.take(source);
assert.deepEqual(source.events.at(-1),source.events.at(-2));
assert.notEqual(duplicates[0].id,duplicates[1].id);
assert.equal(duplicates[0].sourceId,duplicates[1].sourceId);
const fixture={provenance:'Source-informed fixture: actual Match.emit + Horde EventCursor, manually supplied payloads; not a live match',events,duplicates,
  actors:[{id:7,...at(-5.4,.5,0)},{id:8,...at(5.4,.5,0)},{id:9,...at(5.4,.5,-8)}]};
writeFileSync(new URL('events.json',out),JSON.stringify(fixture,null,2)+'\n');
mkdirSync(new URL('evidence/',import.meta.url),{recursive:true});
writeFileSync(new URL('evidence/source-pixels.json',import.meta.url),JSON.stringify(pixels,null,2)+'\n');
console.log(`SOURCE_FIXTURE_OK frames=${pixels.length} opaque_source_alpha=${pixels.every(p=>p.alpha.length===1&&p.alpha[0]===255)} retained_equal_events=2 distinct_wire_ids=2`);
