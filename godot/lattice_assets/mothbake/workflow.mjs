// Pinned latest Mothbake local-first workflow; no credentials, network or engine.
// node workflow.mjs <mothbake-checkout> <new-workspace> --dry|prepare|finalize
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
const PIN = '93e182557c7c47b75c556477127fb27686fea20d';
const [checkoutArg, workspaceArg, action = '--dry'] = process.argv.slice(2);
if (!checkoutArg || !workspaceArg || !['--dry','prepare','finalize'].includes(action)) throw new Error('Expected checkout workspace --dry|prepare|finalize');
const checkout = path.resolve(checkoutArg), workspace = path.resolve(workspaceArg);
if (execFileSync('git',['rev-parse','HEAD'],{cwd:checkout,encoding:'utf8'}).trim() !== PIN) throw new Error('Mothbake commit mismatch');
const load = (file) => import(pathToFileURL(path.join(checkout,'src',file)).href);
const sha = (bytes) => createHash('sha256').update(bytes).digest('hex');
const here = path.dirname(fileURLToPath(import.meta.url));
const request = JSON.parse(fs.readFileSync(path.join(here,'variations.json'),'utf8'));
const { resolveVariationPlan } = await load('variations.mjs');
const plan = resolveVariationPlan(request);
if (action === '--dry') {
  console.log(JSON.stringify({mothbake:PIN,action,plan,remoteJobs:0,credits:0,writes:0,outputs:['assets/*.png','candidates/','variation-plan.json','delivery/godot/current.json (after human approval)']},null,2));
} else {
  const { createMaterialFamily } = await load('material-family.mjs');
  const { encodePng } = await load('decoders/png.mjs');
  const { createCandidateStore } = await load('candidates.mjs');
  const store = createCandidateStore({workspaceRoot:workspace});
  const png = (record) => encodePng(record.width,record.height,record.maps.color.data,{alpha:true});
  if (action === 'prepare') {
    if (fs.existsSync(workspace) && fs.readdirSync(workspace).length) throw new Error('Use a new empty candidate workspace');
    fs.mkdirSync(path.join(workspace,'assets'),{recursive:true});
    fs.writeFileSync(path.join(workspace,'variation-plan.json'),JSON.stringify(plan,null,2)+'\n');
    for (const entry of plan.candidates) {
      const family = createMaterialFamily(entry.params);
      const source = png(family.baseline), result = png(family.candidate);
      const sourcePath = `assets/${entry.id}-baseline.png`, resultPath = `assets/${entry.id}-candidate.png`;
      fs.writeFileSync(path.join(workspace,sourcePath),source);
      fs.writeFileSync(path.join(workspace,resultPath),result);
      await store.addCandidate({version:1,id:entry.id,kind:'material',source:{path:sourcePath,sha256:sha(source)},result:{path:resultPath,sha256:sha(result)},params:entry.params,parameterDelta:entry.parameterDelta,backend:'local:material-family-v1',provenance:{planFingerprint:plan.fingerprint,mothbakeCommit:PIN,source:'procedural',remoteJobs:0},qualityReport:family.candidate.quality,favorite:false,rejected:false,notes:'Unreviewed LATTICE armor microdetail candidate; map palettes remain runtime-owned.'});
    }
    console.log(`Prepared ${plan.candidates.length} local candidates; review in Mothbake workbench before approval.`);
  } else {
    const { createApprovalStore } = await load('approvals.mjs');
    const approval = await createApprovalStore({workspaceRoot:workspace}).get();
    if (!approval) throw new Error('Human content approval required; no automatic visual acceptance');
    const candidate = await store.get(approval.candidateId);
    if (!candidate || candidate.provenance.mothbakeCommit !== PIN) throw new Error('Missing or unpinned candidate');
    const family = createMaterialFamily(candidate.params);
    if (sha(png(family.candidate)) !== approval.result.sha256) throw new Error('Offline rebuild differs from approved bytes');
    const { exportGodotMaterialFamily, validateGodotPack } = await load('emitters/godot.mjs');
    const pack = exportGodotMaterialFamily(family.candidate,path.join(workspace,'delivery','godot'));
    validateGodotPack(pack.projectDir);
    fs.writeFileSync(path.join(workspace,'delivery','APPROVAL.json'),JSON.stringify(approval,null,2)+'\n');
    console.log(JSON.stringify({projectDir:pack.projectDir,engineImport:'not-run',visualAcceptance:'approval-record-only'}));
  }
}
