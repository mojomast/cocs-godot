import path from 'node:path';
import assert from 'node:assert/strict';

// Inventory identities are POSIX; disk paths remain native. Check containment
// before conversion, and never interpret backslash/URL escapes as ESM imports.
export function dependencyPath(root,importer,spec,paths=path) {
  assert.ok(spec.startsWith('.')&&!/[\\?#%\0]/.test(spec),'Unsafe dependency specifier');
  assert.ok(!importer.includes('\\')&&!importer.split('/').includes('..'),'Unsafe importer identity');
  const absolute=paths.resolve(root,paths.dirname(importer),spec);
  const native=paths.relative(root,absolute);
  assert.ok(native&&!paths.isAbsolute(native)&&native!=='..'&&!native.startsWith('..'+paths.sep),'Dependency escapes repository');
  return native.split(paths.sep).join('/');
}
