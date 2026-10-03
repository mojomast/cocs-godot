// Exact source-development addition; never a runtime derivative or map promotion.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
export const AUTHORING_CONTRACT='port/contracts/moth-authoring-resources.json';
export const AUTHORING_COMMIT='9dc08e53c97422b80c969615bbc31d7a05498196';
export const AUTHORING_SHA='abc05c5adf529e3b74ec42752c9fe9a650ab678c101ad5a89fe3158560f855aa';
const hash=b=>createHash('sha256').update(b).digest('hex');
export function authoringInventory(read){
 const bytes=read(AUTHORING_CONTRACT);assert.equal(hash(bytes),AUTHORING_SHA,'Exact authoring resource inventory');
 const r=JSON.parse(bytes);assert.equal(r.reviewed_commit,AUTHORING_COMMIT);
 assert.equal(r.status,'authoring-resources-not-runtime-map-adoption');
 assert.equal(r.shipping,'excluded-from-runtime-copy');return r.files;
}
export function verifyAuthoringResources({read,isAncestor,sourceCommit,portCommit,added}){
 // Historical artifacts before this review have no exemption and do not read
 // the newer contract. Presence in ambient HEAD cannot affect their validation.
 if(!isAncestor(AUTHORING_COMMIT,portCommit))return {};
 assert.ok(isAncestor(sourceCommit,AUTHORING_COMMIT),'Authoring source ancestry');
 const files=authoringInventory(read);
 for(const [p,r]of Object.entries(files)){
  assert.ok(added.includes(p),'Approved authoring resource missing from source additions: '+p);
  const b=read(p);assert.equal(b.length,r.bytes,'Authoring resource byte length: '+p);
  assert.equal(hash(b),r.sha256,'Authoring resource hash: '+p);
 }
 return files;
}
export function rejectAuthoringRuntime(paths,files){
 for(const p of paths)assert.ok(!Object.hasOwn(files,p.replace(/^runtime\//,'')),'Authoring resource cannot ship as runtime: '+p);
}
