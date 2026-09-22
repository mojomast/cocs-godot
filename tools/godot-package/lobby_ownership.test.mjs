// Process-boundary regression. The native executable is a labelled stub, not
// gameplay evidence; constructing any local authority on this route must fail.
import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp, mkdir, copyFile, writeFile, readdir, rm} from 'node:fs/promises';
import {join, dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {fileURLToPath} from 'node:url';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
const exec = promisify(execFile);
const here = dirname(fileURLToPath(import.meta.url));

for (const kind of ['package', 'dev']) {
  for (const scenario of ['exit', 'native-failure', 'missing-native']) {
    test(`${kind}: external authority ownership and cleanup on ${scenario}`, async () => {
      const root = await mkdtemp(join(tmpdir(), 'lobby-owner-test-'));
      // Shebanged cocs.x86_64 Node stub: the nearest package.json decides its
      // loader, so an ambient {"type":"module"} above tmpdir() (shared TMPDIR) would
      // force ESM and kill it with ERR_UNKNOWN_FILE_EXTENSION. Pin CJS explicitly.
      await writeFile(join(root, 'package.json'), '{"type":"commonjs"}\n');
      try {
        async function put(path, text) { await mkdir(dirname(join(root,path)), {recursive:true}); await writeFile(join(root,path), text); }
        async function copy(from, to) { await mkdir(dirname(join(root,to)), {recursive:true}); await copyFile(join(here,from), join(root,to)); }
        const server = `export function createGameServer(){throw Error('Unexpected owned authority creation');}\n`;
        const fake = join(root,'cocs.x86_64');
        await put('cocs.x86_64', `#!${process.execPath}\nif(process.argv.includes('--version'))console.log('test-pinned');else{console.log('STUB_NATIVE_ARGS '+JSON.stringify(process.argv.slice(2)));process.exitCode=Number(process.env.STUB_EXIT||0);}\n`);
        const {chmod} = await import('node:fs/promises'); await chmod(fake, 0o755);
        await copy('../../port/contracts/map-selection.json','catalog.json');
        let script;
        if (kind === 'package') {
          for (const name of ['run.mjs','options.mjs','endpoint.mjs']) await copy(name,name);
          await put('runtime/server/game-server.mjs',server);
          script = join(root,'run.mjs');
        } else {
          for (const name of ['launch.mjs','launch_options.mjs']) await copy('../godot-dev/'+name,'tools/godot-dev/'+name);
          await copy('endpoint.mjs','tools/godot-package/endpoint.mjs');
          await copy('../../port/contracts/map-selection.json','port/contracts/map-selection.json');
          await put('port/contracts/source-lock.json',JSON.stringify({godot_version:'test-pinned'}));
          await put('tools/godot-export/semantic.mjs','export function verifySource(){}\n');
          await put('server/game-server.mjs',server);
          script = join(root,'tools/godot-dev/launch.mjs');
        }
        if (scenario === 'missing-native') await rm(fake);
        let result;
        try {
          result = await exec(process.execPath,[script,'--experience=lobby','--endpoint=ws://127.0.0.1:12345'],{cwd:root,env:{...process.env,TMPDIR:root,GODOT_BIN:fake,STUB_EXIT:scenario==='native-failure'?'17':'0'},timeout:10000});
          result.code = 0;
        } catch (error) { result = error; }
        assert.equal(result.code, scenario==='exit'?0:scenario==='native-failure'?17:1, result.stderr);
        assert.doesNotMatch(result.stdout+result.stderr,/Unexpected owned authority creation|PACKAGE_SERVER_READY|Owned local server ready/);
        if (scenario !== 'missing-native') {
          const line = result.stdout.split('\n').find(s=>s.startsWith('STUB_NATIVE_ARGS '));
          const args = JSON.parse(line.slice('STUB_NATIVE_ARGS '.length));
          assert.ok(args.includes('--endpoint=ws://127.0.0.1:12345'));
          assert.ok(args.includes('--lobby-menu'));
        }
        if (kind === 'package') {
          assert.match(result.stdout,/PACKAGE_EXTERNAL_AUTHORITY/);
          assert.match(result.stdout,/PACKAGE_STOPPED/);
          assert.deepEqual((await readdir(root)).filter(name=>name.startsWith('cocs-native-')),[]);
        }
      } finally { await rm(root,{recursive:true,force:true}); }
    });
  }
}
