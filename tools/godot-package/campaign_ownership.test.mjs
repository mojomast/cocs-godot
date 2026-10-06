// Synthetic launcher lifecycle checks only: no engine or simulation is run.
import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, mkdirSync, copyFileSync, writeFileSync, rmSync} from 'node:fs';
import {join, dirname} from 'node:path';
import {tmpdir} from 'node:os';

const authority = `import http from 'node:http';
export function createAuthority(options) {
 console.log('FACTORY '+JSON.stringify(options));
 const server=http.createServer((req,res)=>res.end(JSON.stringify({service:process.env.SCENARIO==='bad-health'?'wrong':'cocs-native-campaign',localOnly:process.env.SCENARIO!=='not-local',port:server.address().port})));
 const listen=server.listen.bind(server);
 server.listen=(port,host,done)=>{if(port!==0||host!=='127.0.0.1')throw Error('not private ephemeral');return listen(port,host,done);};
 return {server,wss:{clients:new Set()},async close(){server.closeAllConnections();await new Promise(r=>server.close(r));console.log('CLOSED');}};
}`;

for (const kind of ['package','dev']) for (const scenario of ['exit','native-failure','bad-health','not-local','bad-args']) {
  test(`${kind}: synthetic campaign ownership ${scenario}`, () => {
    const root = mkdtempSync(join(tmpdir(),'campaign ownership '));
    const put = (path, text, mode) => {const full=join(root,path);mkdirSync(dirname(full),{recursive:true});writeFileSync(full,text,{mode});};
    const copy = (path, dest=path) => {mkdirSync(dirname(join(root,dest)),{recursive:true});copyFileSync(new URL('../../'+path,import.meta.url),join(root,dest));};
    try {
      put('package.json','{"type":"commonjs"}');
      put('cocs.x86_64',`#!${process.execPath}
if(process.argv.includes('--version'))console.log('synthetic-pinned');
else { console.log('CHILD '+JSON.stringify({args:process.argv.slice(2),career:process.env.COCS_CAREER_SCOPE}));process.exitCode=process.env.SCENARIO==='native-failure'?17:0; }
`,0o755);
      let script;
      if (kind === 'package') {
        for (const name of ['run.mjs','options.mjs','endpoint.mjs','settings_path.mjs','career_path.mjs']) copy('tools/godot-package/'+name,name);
        copy('port/contracts/map-selection.json','catalog.json');
        put('runtime/port/native-campaign/authority.mjs',authority);
        put('runtime/server/game-server.mjs',"throw Error('WRONG_AUTHORITY');");
        script=join(root,'run.mjs');
      } else {
        for (const name of ['launch.mjs','launch_options.mjs']) copy('tools/godot-dev/'+name);
        copy('tools/godot-dev/active_source.mjs');
        copy('port/contracts/active-source.json');
        copy('port/contracts/racing-candidate-derivative.json');
        copy('port/contracts/contact-candidate-derivative.json');
        for (const name of ['endpoint.mjs','settings_path.mjs','career_path.mjs']) copy('tools/godot-package/'+name);
        copy('port/contracts/map-selection.json');
        put('port/contracts/source-lock.json','{"godot_version":"synthetic-pinned"}');
        put('tools/godot-export/semantic.mjs','export function verifySource(){}');
        put('port/native-campaign/authority.mjs',authority);
        put('server/game-server.mjs',"throw Error('WRONG_AUTHORITY');");
        script=join(root,'tools/godot-dev/launch.mjs');
      }
      const args=['--experience=campaign','--map=emberline-ascent','--difficulty=hard','--smoke'];
      if (scenario==='bad-args') args.push('--endpoint=ws://example.org');
      const result=spawnSync(process.execPath,[script,...args],{cwd:root,encoding:'utf8',timeout:10000,
        env:{...process.env,COCS_SOURCE_DERIVATIVE:'',SCENARIO:scenario,PORT:'must-not-be-used',GODOT_BIN:join(root,'cocs.x86_64'),TMPDIR:root}});
      const text=result.stdout+result.stderr;
      assert.equal(result.status,scenario==='exit'?0:scenario==='native-failure'?17:1,text);
      assert.doesNotMatch(text,/WRONG_AUTHORITY/);
      const record=prefix=>result.stdout.split('\n').find(line=>line.startsWith(prefix))?.slice(prefix.length);
      if (scenario==='bad-args') assert.equal(record('FACTORY '),undefined,text);
      else {
        assert.deepEqual(JSON.parse(record('FACTORY ')),{mapId:'emberline-ascent',difficulty:'hard'});
        assert.match(text,/CLOSED/);
      }
      if (['exit','native-failure'].includes(scenario)) {
        const child=JSON.parse(record('CHILD '));
        assert.ok(child.args.includes('res://campaign/demo.tscn'));
        assert.ok(child.args.some(arg=>/^--endpoint=ws:\/\/127\.0\.0\.1:\d+\/native-campaign$/.test(arg)));
        assert.ok(child.args.includes('--difficulty=hard'));
        assert.ok(child.args.includes('--mode=campaign'));
        assert.equal(child.career,'');
      } else assert.equal(record('CHILD '),undefined,text);
    } finally {rmSync(root,{recursive:true,force:true});}
  });
}
