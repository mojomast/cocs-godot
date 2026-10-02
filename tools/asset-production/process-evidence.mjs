// Own-child lifecycle evidence. Wait for close (stdio drained), never just exit.
export const faultPattern=/SCRIPT ERROR|Parse Error|ERROR:|FOUNDRY_NATIVE_ERROR|ObjectDB instances leaked|resources still in use|RID[^\n]*leak|leaked[^\n]*(?:instance|resource|RID)|orphan[^\n]*(?:node|resource)/i;
export function observeChild(child,role){
 const peer={child,role,log:'',stdout:'',stderr:'',closed:false,code:null,signal:null,spawnError:null,requested:false,forced:false};
 peer.done=new Promise(resolve=>{
  child.on('error',e=>{peer.spawnError=String(e);});
  child.on('close',(code,signal)=>{peer.closed=true;peer.code=code;peer.signal=signal;resolve();});
 });
 for(const name of ['stdout','stderr'])child[name]?.on('data',b=>{peer[name]+=b;peer.log+=b;});
 return peer;
}
async function wait(peer,ms){
 let timer;
 try{await Promise.race([peer.done,new Promise(r=>{timer=setTimeout(r,ms);})]);}
 finally{clearTimeout(timer);}
}
export function assessPeer(peer){
 const failures=[];
 if(peer.spawnError)failures.push('spawn-error: '+peer.spawnError);
 if(!peer.requested)failures.push('unexpected-exit');
 if(!peer.closed)failures.push('exit-timeout');
 if(peer.forced)failures.push('forced-kill');
 if(peer.code!==0||peer.signal)failures.push(`exit: ${peer.code}/${peer.signal}`);
 if(!peer.log.includes('CANDIDATE_TEARDOWN_READY '))failures.push('missing-graceful-notification');
 if(faultPattern.test(peer.log))failures.push('native-log-error-or-leak');
 return {role:peer.role,pid:peer.child.pid,closed:peer.closed,code:peer.code,signal:peer.signal,spawnError:peer.spawnError,requested:peer.requested,forced:peer.forced,failures,clean:failures.length===0};
}
export async function shutdownPeers(peers,request,{graceMs=10000,termMs=2000,killMs=2000}={}){
 return Promise.all(peers.map(async peer=>{
  if(!peer.closed&&!peer.spawnError){
   try{request(peer);peer.requested=true;}catch(e){peer.shutdownError=String(e);}
   await wait(peer,graceMs);
  }
  if(!peer.closed){peer.forced=true;peer.child.kill('SIGTERM');await wait(peer,termMs);}
  if(!peer.closed){peer.child.kill('SIGKILL');await wait(peer,killMs);}
  const report=assessPeer(peer);
  if(peer.shutdownError){report.failures.push('shutdown-command: '+peer.shutdownError);report.clean=false;}
  return report;
 }));
}
