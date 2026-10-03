import {join} from 'node:path';
import {readFile} from 'node:fs/promises';
import {root} from './contracts.mjs';
import {runProcess} from './process.mjs';

export function nativeCommand(godot,args,log,timeoutMs) {
  if(!Number.isFinite(timeoutMs)||timeoutMs<=15000)throw Error('Native wall budget must allow bounded display/cleanup overhead');
  return {command:'python3',args:['-B',join(root,'tools/release/cinematic-v3/native.py'),
    '--report',log+'.supervision.json','--timeout',String((timeoutMs-15000)/1000),'--',godot,...args],
    display:'owned TCP via xvfb_run.start_server(False)',supervisor:'finish_runner.run_bounded',timeoutMs};
}
export async function runNative(godot,args,options) {
  const invocation=nativeCommand(godot,args,options.log,options.timeoutMs);
  await runProcess(invocation.command,invocation.args,options);
  const result=JSON.parse(await readFile(options.log+'.supervision.json'));
  if(result.status!=='passed'||result.exit_code!==0||result.cleanup?.remaining?.length||result.zero_audits?.length!==3||result.zero_audits.some(a=>a.remaining.length))throw Error('Native supervisor did not close with three empty audits');
}
