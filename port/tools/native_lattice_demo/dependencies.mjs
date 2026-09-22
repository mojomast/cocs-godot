import {pathToFileURL} from 'node:url';
import {resolve as pathResolve} from 'node:path';
export async function resolve(specifier,context,nextResolve){
 if(specifier==='ws' && process.env.GUEST_NODE_MODULES){
  return nextResolve(pathToFileURL(pathResolve(process.env.GUEST_NODE_MODULES,'ws/wrapper.mjs')).href,context);
 }
 return nextResolve(specifier,context);
}
