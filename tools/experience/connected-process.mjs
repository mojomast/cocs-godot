// Bounded Linux process-group ownership, shared by the journey and synthetic tests.
import {spawn} from 'node:child_process';
import {createWriteStream, readdirSync, readFileSync} from 'node:fs';
import {setTimeout as sleep} from 'node:timers/promises';

export function liveGroup(pgid) {
  if (!pgid) return [];
  return readdirSync('/proc').filter(x=>/^\d+$/.test(x)).flatMap(pid=>{
    try {
      const stat=readFileSync(`/proc/${pid}/stat`,'utf8');
      const fields=stat.slice(stat.lastIndexOf(')')+2).split(' ');
      return Number(fields[2])===pgid && !['Z','X'].includes(fields[0]) ? [Number(pid)] : [];
    } catch { return []; }
  });
}

export function ownProcess(command,args,{log,env=process.env,cwd=process.cwd()}={}) {
  const output=createWriteStream(log,{flags:'wx'});
  const child=spawn(command,args,{cwd,env,detached:true,stdio:['ignore','pipe','pipe']});
  const owned={child,text:'',error:null,closed:false,escalated:false,log};
  output.on('error',error=>{owned.error??=error;});
  for(const stream of [child.stdout,child.stderr]) stream.on('data',bytes=>{
    output.write(bytes); owned.text=(owned.text+String(bytes)).slice(-131072);
  });
  child.on('error',error=>{owned.error=error;output.write(error.stack+'\n');});
  owned.done=new Promise(resolve=>child.once('close',(code,signal)=>{
    owned.closed=true; output.end(()=>resolve({code,signal}));
  }));
  return owned;
}

export async function stopOwned(owned,{termMs=3000,killMs=3000}={}) {
  const {child}=owned;
  const signal=name=>{if(child.pid)try{process.kill(-child.pid,name);}catch(error){if(error.code!=='ESRCH')throw error;}};
  const drained=()=>owned.closed && liveGroup(child.pid).length===0;
  if(!drained())signal('SIGTERM');
  let end=Date.now()+termMs;
  while(!drained()&&Date.now()<end)await sleep(20);
  if(!drained()) {
    owned.escalated=true;signal('SIGKILL');end=Date.now()+killMs;
    while(!drained()&&Date.now()<end)await sleep(20);
  }
  if(!drained())throw Error(`Unreaped owned group ${child.pid}; live=${liveGroup(child.pid)}`);
  await owned.done;
  return {pid:child.pid??null,code:child.exitCode,signal:child.signalCode,escalated:owned.escalated,live:liveGroup(child.pid)};
}

export async function until(predicate,label,{ms=20000,abort=()=>{}}={}) {
  const end=Date.now()+ms;
  while(Date.now()<end) { abort();const value=await predicate();if(value)return value;await sleep(40); }
  throw Error(`Deadline (${ms}ms): ${label}`);
}
