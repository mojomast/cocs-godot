import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync,existsSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {OPERATORS} from './final_resources.mjs';
export function fighterImports({read,has}) {
  if(!has('godot/fighting/main.gd'))return {};
  return Object.fromEntries(OPERATORS.map(id=>{
    const path=`godot/fighting/assets/operators/${id}.glb.import`,bytes=read(path),text=bytes.toString();
    assert.ok(text.includes(`source_file="res://fighting/assets/operators/${id}.glb"`),'Fighter import source identity');
    assert.match(text,/^animation\/import=true$/m);assert.match(text,/^animation\/fps=60$/m);
    assert.match(text,/^animation\/trimming=false$/m);
    const body=text.match(/^_subresources=(\{[\s\S]*^\})[ \t]*$/m)?.[1];
    assert.ok(body,'Fighter per-node import settings absent');
    const player=JSON.parse(body).nodes?.['PATH:AnimationPlayer'];
    assert.equal(player?.['optimizer/enabled'],false,'Fighter optimizer must stay disabled');
    assert.equal(player?.['compression/enabled'],false,'Fighter animation compression must stay disabled');
    return [path,createHash('sha256').update(bytes).digest('hex')];
  }));
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  const root=resolve(process.argv[2]);console.log(JSON.stringify(fighterImports({read:p=>readFileSync(join(root,p)),has:p=>existsSync(join(root,p))}),null,2));
}
