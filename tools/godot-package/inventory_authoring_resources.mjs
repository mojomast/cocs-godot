// Source-only inventory generator. Reads immutable Git objects, never provider APIs.
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const commit='9dc08e53c97422b80c969615bbc31d7a05498196',root='assets/moth/map-variety-20261003';
const git=(...args)=>execFileSync('git',args,{maxBuffer:128*1024*1024});
const tree=git('rev-parse',`${commit}:${root}`).toString().trim();
assert.equal(tree,'d61690d7907ba562e4fc7b87de7f4d3dec1c79d0');
const paths=git('ls-tree','-r','--name-only','-z',commit,'--',root).toString().split('\0').filter(Boolean).sort();
const files=Object.fromEntries(paths.map(p=>{const b=git('show',`${commit}:${p}`);return [p,{sha256:createHash('sha256').update(b).digest('hex'),bytes:b.length}];}));
const contract={schema_version:1,status:'authoring-resources-not-runtime-map-adoption',reviewed_commit:commit,reviewed_tree:tree,root,shipping:'excluded-from-runtime-copy',files};
const bytes=JSON.stringify(contract,null,2)+'\n';
writeFileSync('port/contracts/moth-authoring-resources.json',bytes);
console.log(JSON.stringify({files:paths.length,bytes:Object.values(files).reduce((n,r)=>n+r.bytes,0),contractSHA256:createHash('sha256').update(bytes).digest('hex')}));
