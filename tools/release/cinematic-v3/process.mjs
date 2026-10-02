import {spawn} from 'node:child_process';
import {open,writeFile} from 'node:fs/promises';
// Owned process group only. Timeout/signal cleanup is awaited before releasing logs/slot.
export async function runProcess(command,args,{cwd,log,timeoutMs=600000,env={}}) {
  const file=await open(log,'wx');
  const execution={command,args,cwd,startedAt:Date.now(),timeoutMs,status:'failed',LP_NUM_THREADS:1};
  try {
    await new Promise((resolve,reject)=>{
      const child=spawn(command,args,{cwd,detached:true,stdio:['ignore',file.fd,file.fd],
        env:{...process.env,...env,LP_NUM_THREADS:'1',OMP_NUM_THREADS:'1'}});
      let reason=null,killTimer;
      execution.pid=child.pid;
      const kill=signal=>{if(child.pid)try{process.kill(-child.pid,signal);}catch(e){if(e.code!=='ESRCH')throw e;}};
      const stop=why=>{reason??=why;kill('SIGTERM');killTimer??=setTimeout(()=>kill('SIGKILL'),2000);};
      const interrupt=()=>stop('interrupted'),timer=setTimeout(()=>stop('wall deadline exceeded'),timeoutMs);
      process.on('SIGINT',interrupt);process.on('SIGTERM',interrupt);
      const cleanup=()=>{clearTimeout(timer);clearTimeout(killTimer);process.off('SIGINT',interrupt);process.off('SIGTERM',interrupt);};
      child.once('error',e=>{execution.error=e.message;cleanup();reject(e);});
      child.once('close',(code,signal)=>{
        let descendants=false;if(child.pid)try{process.kill(-child.pid,0);descendants=true;}catch(e){if(e.code!=='ESRCH')descendants=true;}
        if(descendants){kill('SIGKILL');reason??='owned descendants survived parent exit';}
        cleanup();Object.assign(execution,{code,signal,reason,descendantsAfterParentExit:descendants,closedAt:Date.now(),status:code===0&&!reason?'passed':'failed'});
        execution.status==='passed'?resolve():reject(Error(`${command}: ${reason??`exit ${code}/${signal}`}; ${log}`));
      });
    });
  } finally {await file.close();await writeFile(log+'.process.json',JSON.stringify(execution,null,2)+'\n',{flag:'wx'});}
}
