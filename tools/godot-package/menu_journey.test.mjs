// Synthetic native children; real supervisor processes and owned HTTP listeners.
// This checks lifecycle/storage plumbing, not Godot input or gameplay acceptance.
import test from 'node:test';
import assert from 'node:assert/strict';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {mkdtemp, mkdir, copyFile, writeFile, chmod, readFile, readdir, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createConnection} from 'node:net';

const exec = promisify(execFile);
const repo = fileURLToPath(new URL('../../', import.meta.url));
const authority = `import http from 'node:http';
import {appendFileSync} from 'node:fs';
export function createGameServer(options) {
 const audit=(record)=>appendFileSync(process.env.SHELL_JOURNEY_STATE+'.authority',JSON.stringify(record)+'\\n');
 audit({phase:'create',historyPath:options.historyPath,progressionPath:options.progressionPath});
 const server=http.createServer((_req,res)=>{res.setHeader('content-type','application/json');res.end(JSON.stringify({service:'token-arena-game-server',port:server.address().port}));});
 return {server,wss:{clients:[]},history:{whenPersisted:async()=>{audit({phase:'history-flushed'});return true;}},close:()=>new Promise(resolve=>server.close(resolve))};
}`;
const native = `#!${process.execPath}
const fs=require('node:fs');
if(process.argv.includes('--version')){console.log('journey-fixture');process.exit(0);}
const statePath=process.env.SHELL_JOURNEY_STATE;
const state=fs.existsSync(statePath)?JSON.parse(fs.readFileSync(statePath)):{menu:0,routes:0,paths:[],runtime:[]};
const settings=process.env.COCS_SETTINGS_PATH;
if(!settings)throw Error('Missing shared settings path');
state.paths.push(settings);
if(process.argv.includes('res://ui/main_menu.tscn')){
 const saved=fs.existsSync(settings)?JSON.parse(fs.readFileSync(settings)):{visits:0};
 if(saved.visits!==state.routes)throw Error('Settings did not survive route exit');
 if(state.menu===9)console.log('MENU_QUIT');
 else{
  const picks=[['--experience=combat','--play'],['--experience=lattice-world'],['--experience=sports']];
  console.log('MENU_ROUTE '+JSON.stringify({args:picks[state.menu%3]}));
 }
 state.menu++;
}else{
 if(!process.argv.some(a=>a.startsWith('--endpoint=ws://127.0.0.1:')))throw Error('Missing owned endpoint');
 state.routes++;
 state.runtime.push(process.env.XDG_CONFIG_HOME);
 fs.mkdirSync(require('node:path').dirname(settings),{recursive:true});
 fs.writeFileSync(settings,JSON.stringify({visits:state.routes}));
 console.log('SYNTHETIC_ROUTE_EXIT '+state.routes);
}
fs.writeFileSync(statePath,JSON.stringify(state));
`;

async function listening(port) {
  return new Promise(resolve => {
    const socket = createConnection({host:'127.0.0.1', port});
    socket.once('connect', () => {socket.destroy();resolve(true);});
    socket.once('error', () => {socket.destroy();resolve(false);});
    socket.setTimeout(1000, () => {socket.destroy();resolve(true);});
  });
}

for (const kind of ['dev','package']) {
  test(`${kind}: three menu/combat/LATTICE/sports cycles preserve settings and close owned listeners`, {timeout:30000}, async () => {
    const root=await mkdtemp(join(tmpdir(),'cocs-menu-journey-'));
    const put=async (name,text)=>{await mkdir(dirname(join(root,name)),{recursive:true});await writeFile(join(root,name),text);};
    const copy=async (from,to)=>{await mkdir(dirname(join(root,to)),{recursive:true});await copyFile(join(repo,from),join(root,to));};
    try {
      await put('package.json','{"type":"commonjs"}\n');
      await put('cocs.x86_64',native);await chmod(join(root,'cocs.x86_64'),0o755);
      let script;
      if(kind==='package') {
        for(const name of ['run.mjs','options.mjs','endpoint.mjs','settings_path.mjs','career_path.mjs'])await copy('tools/godot-package/'+name,name);
        await copy('port/contracts/map-selection.json','catalog.json');
        await put('runtime/server/game-server.mjs',authority);
        script=join(root,'run.mjs');
      } else {
        for(const name of ['launch.mjs','launch_options.mjs'])await copy('tools/godot-dev/'+name,'tools/godot-dev/'+name);
        for(const name of ['endpoint.mjs','settings_path.mjs','career_path.mjs'])await copy('tools/godot-package/'+name,'tools/godot-package/'+name);
        await copy('port/contracts/map-selection.json','port/contracts/map-selection.json');
        await put('port/contracts/source-lock.json',JSON.stringify({godot_version:'journey-fixture'}));
        await put('tools/godot-export/semantic.mjs','export function verifySource(){}\n');
        await put('server/game-server.mjs',authority);
        script=join(root,'tools/godot-dev/launch.mjs');
      }
      const settings=join(root,'preferences','local_settings.json');
      const {stdout,stderr}=await exec(process.execPath,[script,'--experience=menu'],{
        cwd:root,env:{...process.env,PORT:'0',TMPDIR:root,GODOT_BIN:join(root,'cocs.x86_64'),
          COCS_SETTINGS_PATH:settings,COCS_CAREER_ROOT:join(root,'career'),SHELL_JOURNEY_STATE:join(root,'state.json')},timeout:25000,
      });
      assert.doesNotMatch(stderr,/Error|ERROR/);
      const state=JSON.parse(await readFile(join(root,'state.json'),'utf8'));
      assert.equal(state.menu,10);assert.equal(state.routes,9);
      assert.deepEqual([...new Set(state.paths)],[settings]);
       assert.deepEqual(JSON.parse(await readFile(settings,'utf8')),{visits:9});
       const authorityAudit=(await readFile(join(root,'state.json.authority'),'utf8')).trim().split('\n').map(line=>JSON.parse(line));
       assert.equal(authorityAudit.length,18);
       for(let i=0;i<9;i++){
         assert.deepEqual(authorityAudit[i*2],{phase:'create',historyPath:join(root,'career','history.json'),progressionPath:join(root,'career','progression.json')});
         assert.deepEqual(authorityAudit[i*2+1],{phase:'history-flushed'},'supervisor waits for history persistence before the next route');
       }
      const ports=kind==='package'
        ? stdout.split('\n').filter(line=>line.startsWith('PACKAGE_SERVER_READY ')).map(line=>JSON.parse(line.slice('PACKAGE_SERVER_READY '.length)).port)
        : [...stdout.matchAll(/Owned local server ready at ws:\/\/127\.0\.0\.1:(\d+)/g)].map(match=>Number(match[1]));
      assert.equal(ports.length,9,'every match has its own authority lifecycle');
      for(const port of new Set(ports))assert.equal(await listening(port),false,`owned port ${port} survived`);
      assert.equal((await readdir(root)).some(name=>name.startsWith('cocs-native-')),false,'disposable runtimes survived');
      if(kind==='package')assert.equal(stdout.split('\n').filter(line=>line==='PACKAGE_STOPPED').length,9);
    } finally {await rm(root,{recursive:true,force:true});}
  });
}
