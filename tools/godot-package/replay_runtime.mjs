// Separate, read-only replay closure. No authority or checkout module is copied.
import {readFileSync,existsSync,mkdirSync,writeFileSync,lstatSync} from 'node:fs';
import {resolve,dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
export const REPLAY_FILES = Object.freeze(['game/demo.mjs','godot/replay/admission.json','tools/port/replay/adapter.mjs','tools/port/replay/service.mjs']);
export const REPLAY_KIND = 'read-only-source-demo-adapter';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
export function copyReplayRuntime(root,output,commit) {
  if (existsSync(output)) throw Error('Replay runtime output must be fresh');
  const bytes = Object.fromEntries(REPLAY_FILES.map(path=> {
    const source=join(root,path);
    if (!lstatSync(source).isFile() || lstatSync(source).isSymbolicLink()) throw Error(`Invalid replay input: ${path}`);
    const actual=readFileSync(source);
    const committed=execFileSync('git',['show',`${commit}:${path}`],{cwd:root});
    if (!actual.equals(committed)) throw Error(`Replay input differs from recorded commit: ${path}`);
    return [path,actual];
  }));
  const admission=JSON.parse(bytes['godot/replay/admission.json']);
  if (hash(bytes['game/demo.mjs'])!==admission.demoSha256) throw Error('Replay source demo hash mismatch');
  const files=Object.fromEntries(REPLAY_FILES.map(path=>[path,hash(bytes[path])]));
  for (const path of REPLAY_FILES) {
    const target=join(output,path); mkdirSync(dirname(target),{recursive:true});
    writeFileSync(target,bytes[path],{flag:'wx'});
  }
  writeFileSync(join(output,'manifest.json'),JSON.stringify({version:1,kind:REPLAY_KIND,files},null,2)+'\n',{flag:'wx'});
  return files;
}
if (process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  const [root,output,commit]=process.argv.slice(2);
  if (!root||!output||!/^[a-f0-9]{40}$/.test(commit??'')) throw Error('Expected root, fresh output and recorded commit');
  console.log(JSON.stringify(copyReplayRuntime(resolve(root),resolve(output),commit)));
}
