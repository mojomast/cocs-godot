// Read-only reuse of the owner's installed dependencies; no package mutations.
import {pathToFileURL} from 'node:url';
import {resolve as pathResolve} from 'node:path';
export async function resolve(specifier, context, nextResolve) {
  try { return await nextResolve(specifier, context); }
  catch (error) {
    if (error.code !== 'ERR_MODULE_NOT_FOUND' || !process.env.GUEST_NODE_MODULES || specifier.startsWith('.') || specifier.startsWith('/') || specifier.includes(':')) throw error;
    return nextResolve(specifier, {...context, parentURL:pathToFileURL(pathResolve(process.env.GUEST_NODE_MODULES, '../package.json')).href});
  }
}
