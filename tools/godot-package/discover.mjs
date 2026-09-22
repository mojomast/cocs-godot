// Build-time parser: V8 parses actual ESM imports rather than grepping comments.
// Invoke with node --experimental-vm-modules. Nothing here is shipped at play time.
import {SourceTextModule} from 'node:vm';
import {readFileSync} from 'node:fs';
import {resolve, dirname, relative} from 'node:path';
import {isBuiltin} from 'node:module';
const root = resolve(process.argv[2]);
const pending = ['server/game-server.mjs'], modules = {}, external = new Set();
while (pending.length) {
  const path = pending.pop();
  if (Object.hasOwn(modules, path)) continue;
  if (!/^(server|game)\/.+\.mjs$/.test(path) || path.includes('..') || path.includes('.test.')) throw Error(`Unexpected runtime input: ${path}`);
  const source = readFileSync(resolve(root, path), 'utf8');
  const module = new SourceTextModule(source, {identifier:path});
  modules[path] = [...module.dependencySpecifiers];
  for (const spec of module.dependencySpecifiers) {
    if (spec.startsWith('.')) pending.push(relative(root, resolve(root, dirname(path), spec)));
    else if (!isBuiltin(spec)) external.add(spec);
  }
}
if (JSON.stringify([...external].sort()) !== '["ws"]') throw Error(`Review new external dependencies: ${[...external]}`);
console.log(JSON.stringify({entry:'server/game-server.mjs', modules:Object.fromEntries(Object.entries(modules).sort()), external:[...external]}, null, 2));
