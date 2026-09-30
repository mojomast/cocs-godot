// Real authority + real native scene; scripted visual scenarios are conspicuously
// labelled. Run only in the centrally serialized graphical validation slot.
import http from 'node:http';
import {spawn} from 'node:child_process';
import {mkdir,mkdtemp,writeFile,readFile,rm} from 'node:fs/promises';
import {resolve,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createAuthority} from '../native-campaign/authority.mjs';
import {createCaptureScenarios} from './capture-scenarios.mjs';

const root=fileURLToPath(new URL('../../',import.meta.url));
const args=process.argv.slice(2),option=name=>args.find(a=>a.startsWith(`--${name}=`))?.slice(name.length+3);
const unknown=args.filter(a=>!['map','profile','pack','output'].some(k=>a.startsWith(`--${k}=`)));
if(unknown.length)throw Error(`Unknown capture arguments: ${unknown.join(' ')}`);
const roster=['rootfall-verge','siltwake-crossing','emberline-ascent','crown-array'];
const maps=option('map')?[option('map')]:roster;
const profiles=option('profile')?[option('profile')]:['wide','compact'];
if(maps.some(m=>!roster.includes(m))||profiles.some(p=>!['wide','compact'].includes(p)))throw Error('Unknown map/profile');
const pack=option('pack')?resolve(option('pack')):null;
const base=resolve(option('output')||'/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/live-captures');
if(base===resolve(root)||base.startsWith(resolve(root)+'/'))throw Error('Capture evidence must be outside the repository');
await mkdir(base,{recursive:true});
const output=await mkdtemp(join(base,'run-'));
console.log('CAMPAIGN_CAPTURE_OUTPUT',output);
const reports=[];
for(const mapId of maps)for(const profile of profiles){
  const directory=join(output,`${mapId}-${profile}`);await mkdir(directory);
  const fixture=createCaptureScenarios(),wire=[];
  let seed=42;
  let authority,control,child,done,timer,log='',result;
  const runtime=await mkdtemp('/tmp/opencode/campaign-capture-settings-');
  try{
    authority=createAuthority({mapId,difficulty:'easy',random:()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296),matchFactory:fixture.matchFactory,observe(record){
      const f=record.frame;
      if(f&&['start','results','campaign-action','error','events'].includes(f.type))wire.push(record);
    }});
    await new Promise((resolve,reject)=>{authority.server.once('error',reject);authority.server.listen(0,'127.0.0.1',resolve);});
    control=http.createServer((req,res)=>{
      if(req.method!=='POST'||!['127.0.0.1','::ffff:127.0.0.1'].includes(req.socket.remoteAddress)){res.writeHead(403);res.end();return;}
      const stage=req.url?.replace(/^\/stage\//,'');
      try{const value=fixture.select(stage);res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify(value));}
      catch(error){res.writeHead(400,{'Content-Type':'application/json'});res.end(JSON.stringify({error:error.message}));}
    });
    await new Promise((resolve,reject)=>{control.once('error',reject);control.listen(0,'127.0.0.1',resolve);});
    const env={...process.env};
    for(const key of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']){env[key]=join(runtime,key);await mkdir(env[key]);}
    const command=['--audio-driver','Dummy','--rendering-method','gl_compatibility',
      '--resolution',profile==='wide'?'1280x800':'760x520',
      ...(pack?['--main-pack',pack]:['--path',join(root,'godot')]),
      '--script',join(root,'godot/tests/campaign/live_capture.gd'),'--',
      `--map=${mapId}`,'--mode=campaign','--difficulty=easy','--mute',
      `--endpoint=ws://127.0.0.1:${authority.server.address().port}/native-campaign`,
      `--capture-control=http://127.0.0.1:${control.address().port}`,`--capture-output=${directory}`,
      `--capture-profile=${profile}`];
    await writeFile(join(directory,'invocation.json'),JSON.stringify({scripted:true,pack,command},null,2));
    done=new Promise((resolve,reject)=>{
      child=spawn(process.env.GODOT_BIN||'godot',command,{cwd:root,env,stdio:['ignore','pipe','pipe']});
      child.stdout.on('data',b=>{log+=b;});child.stderr.on('data',b=>{log+=b;});
      child.once('error',reject);child.once('exit',(code,signal)=>resolve({code,signal}));
      timer=setTimeout(()=>child.kill('SIGKILL'),240000);
    });
    result=await done;
    const ui=JSON.parse(await readFile(join(directory,'capture-report.json'),'utf8'));
    const endingIndex=wire.findIndex(r=>r.direction==='out'&&r.frame.type==='results'&&r.frame.state.campaign.phase==='campaign-complete');
    const beforeEnding=wire.slice(0,Math.max(0,endingIndex));
    const boundary=beforeEnding.filter(r=>r.direction==='out'&&['start','results'].includes(r.frame.type)).at(-1)?.frame;
    const continued=beforeEnding.filter(r=>r.direction==='in'&&r.frame.type==='campaign-action'&&r.frame.action==='continue').at(-1)?.frame;
    const finalWireOk=mapId!=='crown-array'||(endingIndex>=0&&boundary?.type==='start'&&boundary.mapId===mapId&&
      boundary.inputEpoch===wire[endingIndex].frame.inputEpoch&&continued?.inputEpoch<boundary.inputEpoch);
    const passed=result.code===0&&ui.passed&&finalWireOk&&log.includes('CAMPAIGN_CAPTURE_OK')&&!/SCRIPT ERROR|^ERROR:/m.test(log);
    reports.push({mapId,profile,directory,passed,result,finalWireOk,failures:ui.failures});
    if(!passed)process.exitCode=1;
  }catch(error){reports.push({mapId,profile,directory,passed:false,error:error.stack,result});process.exitCode=1;}
  finally{
    clearTimeout(timer);
    if(child&&child.exitCode===null&&child.signalCode===null)child.kill('SIGKILL');
    if(done)await done.catch(()=>{});
    if(control)await new Promise(resolve=>control.close(resolve));
    if(authority)await authority.close();
    await writeFile(join(directory,'godot.log'),log);
    await writeFile(join(directory,'authority-wire.json'),JSON.stringify(wire,null,2));
    await rm(runtime,{recursive:true,force:true});
  }
}
await writeFile(join(output,'index.json'),JSON.stringify({scripted:true,organicGameplayEvidence:false,renderedPerformanceAcceptance:false,pack,runs:reports},null,2));
console.log('CAMPAIGN_CAPTURE_COMPLETE',JSON.stringify({output,passed:reports.every(r=>r.passed)}));
