// Dynamic resource reads are explicit. This supplements all_resources, whose
// dependency scanner cannot infer FileAccess or constructed audio paths.
import {readFileSync,existsSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
export const FEATURE_JSON = Object.freeze({
  'godot/experience/kill_feed.gd':['godot/experience/public_event_types.json'],
  'godot/input_bindings/service.gd':['godot/input_bindings/contexts.json'],
  'godot/replay/bridge.gd':['godot/replay/admission.json'],
  'godot/audio/threat_service.gd':['godot/audio/telegraphs/manifest.json'],
});
export function featureResources(root) {
  const files=[];
  for (const [anchor,paths] of Object.entries(FEATURE_JSON)) {
    if (!existsSync(join(root,anchor))) continue;
    for (const path of paths) {
      JSON.parse(readFileSync(join(root,path),'utf8'));
      files.push(path);
    }
  }
  if (files.includes('godot/audio/telegraphs/manifest.json')) {
    const manifest=JSON.parse(readFileSync(join(root,'godot/audio/telegraphs/manifest.json'),'utf8'));
    assert.ok(Array.isArray(manifest.inventory)&&manifest.inventory.length===160,'Expected reviewed 160 telegraph samples');
    const seen=new Set();
    for (const entry of manifest.inventory) {
      assert.match(entry.file,/^\d+-(overseer|mender|flanker|phalanx|sapper|artillery|boss|generic)\.wav$/);
      assert.ok(!seen.has(entry.file),'Duplicate telegraph');seen.add(entry.file);
      const path=`godot/audio/telegraphs/${entry.file}`;
      assert.equal(createHash('sha256').update(readFileSync(join(root,path))).digest('hex'),entry.sha256,`Telegraph PCM changed: ${path}`);
      files.push(path);
    }
    for (const path of ['godot/audio/threat_policy.gd','godot/audio/threat_service.gd']) {
      assert.ok(existsSync(join(root,path)),`Missing audio runtime: ${path}`);files.push(path);
    }
  }
  if (files.includes('godot/input_bindings/contexts.json')) {
    const project=readFileSync(join(root,'godot/project.godot'),'utf8');
    assert.match(project,/InputBindings="\*res:\/\/input_bindings\/service\.gd"/,'InputBindings autoload missing');
  }
  return files.sort();
}
if (process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) console.log(JSON.stringify(featureResources(resolve(process.argv[2]))));
