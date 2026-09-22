// Read committed JS bytes without changing any historical files. Absolute import
// rewriting supports data-URL loading; optional instrumentation is read-only.
import {execFileSync} from 'node:child_process';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
export async function revision(commit,file,instrument=source=>source) {
 const bytes=execFileSync('git',['show',`${commit}:${file}`]);
 let source=instrument(bytes.toString());
 source=source.replace(/from '([^']+)'/g,(all,ref)=>{
  if(ref==='ws')return `from '${new URL('wrapper.mjs',pathToFileURL(require.resolve('ws'))).href}'`;
  return ref.startsWith('.')?`from '${new URL(ref,pathToFileURL(resolve(file))).href}'`:all;
 });
 return {module:await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64')),bytes};
}
