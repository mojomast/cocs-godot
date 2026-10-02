import fs from 'node:fs';
const root='/home/mojo/.tmp-on-disk/cocs-new-map-foundry-evidence-20261002/revision3';
const candidate=JSON.parse(fs.readFileSync(new URL('candidate.json',import.meta.url)));
const receipts=['source-check.json','round-check-payload-assault-domination-combined-arms-deathmatch-teamdeathmatch.json'].map(name=>JSON.parse(fs.readFileSync(`${root}/${name}`)));
for(const r of receipts)if(r.geometryHash!==candidate.geometryHash)throw Error('Candidate proof mismatch');
fs.writeFileSync(new URL('source-validation.json',import.meta.url),JSON.stringify({status:'SOURCE PASSED; BLENDER/NATIVE PENDING',geometryHash:candidate.geometryHash,recipeHash:candidate.recipeHash,evidence:root,receipts},null,2)+'\n');
