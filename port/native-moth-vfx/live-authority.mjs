// Private process owner; observe public outbound events/step timing read-only.
import {writeFileSync} from 'node:fs';
import {createAuthority} from '../native-horde/authority.mjs';
const evidence={normal_rate:true,state_injection:false,events:[],steps:0,firstTime:null,lastTime:null};
const authority=createAuthority({observe(record){
  if(record.direction==='out'&&record.frame.type==='events')evidence.events.push(...record.frame.items);
  if(record.direction==='step'){evidence.steps++;evidence.firstTime??=record.sourceTime;evidence.lastTime=record.sourceTime;}
}});
await new Promise(resolve=>authority.server.listen(0,'127.0.0.1',resolve));
console.log(`MOTH_AUTHORITY_READY ${authority.server.address().port}`);
async function close(){
  await authority.close();
  evidence.closed=!authority.server.listening;
  writeFileSync(process.env.MOTH_VFX_EVIDENCE+'/live-authority.json',JSON.stringify(evidence,null,2)+'\n');
}
process.once('SIGTERM',close);
process.once('SIGINT',close);
