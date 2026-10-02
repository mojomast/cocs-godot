import {spawn} from 'node:child_process';
import {open} from 'node:fs/promises';
// Owned process group only. Timeout/signal cleanup is awaited before releasing logs/slot.
export async function runProcess(command,args,{cwd,log,timeoutMs=600000,env={}}) {
  const file=await open(log,'wx');
  try {
    await new Promise((resolve,reject)=>{
      const child=spawn(command,args,{cwd,detached:true,stdio:['ignore',file.fd,file.fd],
        env:{...process.env,...env,LP_NUM_THREADS:'1',OMP_NUM_THREADS:'1'}});
      let reason=null,killTimer;
      const kill=signal=>{if(child.pid)try{process.kill(-child.pid,signal);}catch(e){if(e.code!=='ESRCH')throw e;}};
      const stop=why=>{reason??=why;kill('SIGTERM');killTimer??=setTimeout(()=>kill('SIGKILL'),2000);};
      const interrupt=()=>stop('interrupted'),timer=setTimeout(()=>stop('wall deadline exceeded'),timeoutMs);
      process.on('SIGINT',interrupt);process.on('SIGTERM',interrupt);
      const cleanup=()=>{clearTimeout(timer);clearTimeout(killTimer);process.off('SIGINT',interrupt);process.off('SIGTERM',interrupt);};
      child.once('error',e=>{cleanup();reject(e);});
      child.once('close',(code,signal)=>{cleanup();code===0&&!reason?resolve():reject(Error(`${command}: ${reason??`exit ${code}/${signal}`}; ${log}`));});
    });
  } finally {await file.close();}
}
