// Read-only source projection. No gameplay tuning is owned by the native port.
import {readFileSync,writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {OPERATOR_KITS,MOVEMENT_VERBS} from '../../../game/kits.mjs';
import {HARNESS_PROFILES} from '../../../game/harness-profiles.mjs';
import {OPERATOR_VERBS} from '../../../game/operator-verbs.mjs';
export const catalog={schema:1,operators:Object.fromEntries(OPERATOR_KITS.map(k=>[k.id,{passive:k.verb,movement:MOVEMENT_VERBS.find(v=>v.id===k.movement)}])),harnesses:Object.fromEntries(Object.entries(HARNESS_PROFILES).map(([id,p])=>[id,p.ability])),verbs:OPERATOR_VERBS};
if(process.argv[1]?.endsWith('/catalog.mjs')){
 const path=new URL('../../../godot/player_gameplay/catalog.json',import.meta.url);
 const bytes=JSON.stringify(catalog,null,2)+'\n';
 if(process.argv.includes('--check'))assert.equal(readFileSync(path,'utf8'),bytes,'Player gameplay catalog differs from source');
 else writeFileSync(path,bytes);
}
