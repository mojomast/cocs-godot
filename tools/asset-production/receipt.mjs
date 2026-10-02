// Lightweight real-export inspection. Never manufactures success for absent GLBs.
import {readFileSync,readdirSync,mkdirSync,writeFileSync,existsSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {dirname,basename,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../../',import.meta.url));
const plan=JSON.parse(readFileSync(resolve(root,'port/finish/ASSET_PRODUCTION.json')));
const unit=plan.units.find(u=>u.id===process.argv[2]);
if(!unit||unit.external)throw Error('Specify a local production unit');
const sha=b=>createHash('sha256').update(b).digest('hex');
const sourceHashes=Object.fromEntries([...unit.recipePaths,plan.common.finishScript].sort().map(p=>[p,sha(readFileSync(resolve(root,p)))]));
const sourceFingerprint=sha(JSON.stringify(sourceHashes));
function files(spec){const dir=resolve(root,dirname(spec.glob)),pattern=new RegExp('^'+basename(spec.glob).replaceAll('.','\\.').replaceAll('*','.*')+'$');
  const out=existsSync(dir)?readdirSync(dir).filter(f=>pattern.test(f)).map(f=>resolve(dir,f)):[];
  if(out.length!==spec.count)throw Error(`${spec.glob}: ${out.length}/${spec.count} actual files`);return out.sort();}
const masters=files(unit.masters),exports=files(unit.exports),rows=[];
for(const path of exports){
  const bytes=readFileSync(path);
  if(bytes.readUInt32LE(0)!==0x46546c67||bytes.readUInt32LE(4)!==2||bytes.readUInt32LE(8)!==bytes.length)throw Error('Invalid GLB '+path);
  const jsonBytes=bytes.readUInt32LE(12),doc=JSON.parse(bytes.subarray(20,20+jsonBytes));
  const bin=bytes.subarray(28+jsonBytes),textures=[],materials=doc.materials??[];
  for(const image of doc.images??[]){
    if(image.bufferView===undefined)throw Error('Export requires embedded texture bytes');
    const view=doc.bufferViews[image.bufferView],data=bin.subarray(view.byteOffset??0,(view.byteOffset??0)+view.byteLength);
    textures.push({name:image.name??'',bytes:data.length,sha256:sha(data)});
  }
  let triangles=0,surfaces=0,texturedSurfaces=0;
  for(const node of doc.nodes??[])if(node.mesh!==undefined){
    const needsFinish=doc.meshes[node.mesh].primitives.some(p=>!plan.common.texturePreserveNames.includes((materials[p.material]?.name??'').split('.')[0]));
    if(needsFinish&&node.extras?.asset_source_fingerprint!==sourceFingerprint)throw Error('Stale or unproven asset source fingerprint: '+path+'/'+node.name);
  }
  for(const mesh of doc.meshes??[])for(const p of mesh.primitives){
    if((p.mode??4)!==4)throw Error('Unsupported primitive topology');
    triangles+=(p.indices===undefined?doc.accessors[p.attributes.POSITION].count:doc.accessors[p.indices].count)/3;surfaces++;
    const mat=materials[p.material],name=(mat?.name??'').split('.')[0];
    const preserved=plan.common.texturePreserveNames.includes(name);
    if(!preserved){
      if(p.attributes.TEXCOORD_0===undefined||!mat?.pbrMetallicRoughness?.baseColorTexture||!mat.normalTexture)throw Error(`Flat/untextured material or missing UV: ${path}/${name}`);
      texturedSurfaces++;
    }
  }
  if(!textures.length||!texturedSurfaces)throw Error('Flat-only asset rejected: '+path);
  rows.push({path:path.slice(root.length),bytes:bytes.length,sha256:sha(bytes),triangles,surfaces,texturedSurfaces,textures});
}
const measuredTriangles=rows.reduce((n,r)=>n+r.triangles,0);
if(measuredTriangles>unit.configuredTriangleCap)throw Error(`${unit.id}: ${measuredTriangles} exceeds configured cap ${unit.configuredTriangleCap}`);
const report={unit:unit.id,sourceCommits:unit.sourceCommits,sourceHashes,sourceFingerprint,masters:masters.map(p=>({path:p.slice(root.length),sha256:sha(readFileSync(p))})),exports:rows,measuredGLBTriangles:measuredTriangles,configuredTriangleCap:unit.configuredTriangleCap,accepted:false,pending:unit.gates};
const out=resolve(plan.evidenceRoot,'receipts',new Date().toISOString().replaceAll(':','-'));
mkdirSync(out,{recursive:true});writeFileSync(resolve(out,unit.id+'.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({unit:unit.id,measuredTriangles,report:resolve(out,unit.id+'.json'),accepted:false}));
