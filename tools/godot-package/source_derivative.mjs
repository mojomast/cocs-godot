// Resolve the reviewed overlay without rewriting either historical contract.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
export const MOVEMENT_CONTRACT='port/contracts/movement-candidate-derivative.json';
export const MOVEMENT_COMMIT='91f58a1c5dcd85544574ba9cd11fcecd0d50d522';
export const MOVEMENT_CONTRACT_SHA='b775686e10f21d54150f37a231690d9d24a2da15f8ed775001acc2328b63f830';
const hash=b=>createHash('sha256').update(b).digest('hex');
export function resolveSourceDerivative(contract,read,gitRead,isAncestor){
 if(!contract?.runtime_overrides)return contract;
 const {runtime_files:resolved,...overlay}=contract;
 assert.deepEqual(overlay,JSON.parse(read(MOVEMENT_CONTRACT)),'Recorded movement overlay differs');
 assert.equal(hash(read(MOVEMENT_CONTRACT)),MOVEMENT_CONTRACT_SHA,'Exact reviewed movement contract');
 assert.equal(contract.derivative_commit,MOVEMENT_COMMIT);
 assert.equal(contract.status,'source-candidate-not-native-acceptance');
 assert.equal(contract.parent_contract,'port/contracts/lattice-catalog-derivative.json');
 const parentBytes=read(contract.parent_contract),parent=JSON.parse(parentBytes);
 assert.deepEqual(parentBytes,gitRead(contract.baseline_commit,contract.parent_contract),'Historical parent contract changed');
 assert.equal(parent.derivative_commit,contract.parent_derivative_commit);
 assert.equal(parent.source_commit,contract.source_commit);
 assert.ok(isAncestor(contract.parent_derivative_commit,contract.baseline_commit),'Parent ancestry');
 assert.ok(isAncestor(contract.baseline_commit,contract.derivative_commit),'Candidate ancestry');
 const runtime={...parent.runtime_files};
 for(const [p,sha]of Object.entries(runtime))assert.equal(hash(gitRead(parent.derivative_commit,p)),sha,'Historical derivative source: '+p);
 for(const [p,c]of Object.entries(contract.runtime_overrides)){
  assert.equal(hash(gitRead(contract.baseline_commit,p)),c.before,'Movement predecessor: '+p);
  assert.equal(hash(gitRead(contract.derivative_commit,p)),c.after,'Movement candidate: '+p);
  runtime[p]=c.after;
 }
 if(resolved)assert.deepEqual(resolved,runtime,'Resolved movement inventory differs');
 return {...contract,runtime_files:runtime};
}
