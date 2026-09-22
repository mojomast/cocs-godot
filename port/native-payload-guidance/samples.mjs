// Extract real archived public snapshots, without changing their fields.
import {readFileSync,writeFileSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {createHash} from 'node:crypto';
const file='port/native-objective-completion/evidence/2d6b7e66-6adc-43f2-b29e-9d26fed86387/wire.jsonl.gz';
const bytes=readFileSync(file), rows=gunzipSync(bytes).toString().trim().split('\n').map(JSON.parse);
const picks={};
for(const r of rows){
 if(r.connection!==0||r.round!==1||!['snapshot','results'].includes(r.type))continue;
 const p=r.state.objectives?.payload;if(!p)continue;
 const floor=p.checkpointsReached?r.state.objectives.zones[p.checkpointsReached-1].distance:0;
 const status=p.delivered?'DELIVERED':p.contested?'CONTESTED':p.pushing===0?'PUSHING RED [1]':p.pushing===1?(Math.abs(p.distance-floor)<=.001?(p.checkpointsReached?'HOLDING CHECKPOINT':'HOLDING START'):'ROLLING BACK'):'IDLE';
 picks[status]??={status,seq:r.seq,type:r.type,state:r.state};
}
writeFileSync('port/native-payload-guidance/snapshots.json',JSON.stringify({source:file,sha256:createHash('sha256').update(bytes).digest('hex'),samples:Object.values(picks)},null,2)+'\n');
console.log(Object.keys(picks));
