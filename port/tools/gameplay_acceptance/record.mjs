// Bounded protocol-only recorder. Never creates/starts a game or sends input.
import {openSync, writeFileSync, closeSync} from 'node:fs';
import {parseArgs} from 'node:util';
import {PROTOCOL_VERSION, MESSAGE} from '../../../game/protocol.mjs';
const {values:a}=parseArgs({options:Object.fromEntries(['url','room','name','output','seconds','connect-seconds','setup-seconds','max-frames','max-bytes','classification'].map(k=>[k,{type:'string'}]))});
for(const k of ['url','room','name','output']) if(!a[k]) throw Error(`--${k} required`);
const url=new URL(a.url); if(!['ws:','wss:'].includes(url.protocol)||url.username||url.password) throw Error('explicit ws(s) URL without credentials required');
function limit(k,d,max){const n=Number(a[k]??d);if(!Number.isFinite(n)||n<=0||n>max)throw Error(`invalid --${k}`);return n;}
const duration=limit('seconds',120,120), connect=limit('connect-seconds',10,30), setup=limit('setup-seconds',30,60);
const maxFrames=limit('max-frames',10000,20000), maxBytes=limit('max-bytes',8000000,16000000);
const classification=a.classification??'recorded_protocol_only';
if(!['synthetic','recorded_protocol_only'].includes(classification))throw Error('invalid classification');
const fd=openSync(a.output,'wx',0o600); // Never overwrite evidence.
const data={format:'cocs-recording-v1',classification,clock:'unmodified server timing; receive timestamps monotonic milliseconds',redacted_fields:['welcome.token','welcome.progressToken'],frames:[]};
const start=performance.now();let ws,done=false,bytes=0,count=0,opened=false,welcome=false,round;
const timers=[];
function add(r){data.frames.push({client:1,at_ms:Math.round((performance.now()-start)*1000)/1000,...r});}
function marker(kind,extra={}){add({direction:'lifecycle',kind,...extra});}
function finish(reason,complete=false){if(done)return;done=true;for(const t of timers)clearTimeout(t);if(opened)marker('close',{reason:'recorder release requested'});marker('completion',{reason,complete});try{writeFileSync(fd,JSON.stringify(data)+'\n');}finally{closeSync(fd);try{ws?.close();}catch{}}
console.log(JSON.stringify({reason,complete,frames:count,received_bytes:bytes,output:a.output}));process.exitCode=complete?0:1;
// Native WebSocket has no terminate API. Bound its closing handshake/process lifetime.
setTimeout(()=>process.exit(process.exitCode),100).unref();}
process.on('SIGINT',()=>finish('interrupted'));process.on('SIGTERM',()=>finish('interrupted'));
timers.push(setTimeout(()=>finish('recording_window_elapsed',welcome),duration*1000));
timers.push(setTimeout(()=>{if(!opened)finish('connection_timeout');},connect*1000));
timers.push(setTimeout(()=>{if(!welcome)finish('setup_timeout');},setup*1000));
try{ws=new WebSocket(url);ws.addEventListener('open',()=>{if(done)return;opened=true;marker('open');const frame={type:MESSAGE.JOIN,roomId:a.room,name:a.name,v:PROTOCOL_VERSION,delta:0};add({direction:'client',frame});ws.send(JSON.stringify(frame));});
ws.addEventListener('message',e=>{if(done)return;const size=typeof e.data==='string'?Buffer.byteLength(e.data):maxBytes+1;bytes+=size;if(bytes>maxBytes||count>=maxFrames)return finish('limit');
try{if(typeof e.data!=='string')throw Error('non-text');const frame=JSON.parse(e.data);if(!frame||typeof frame.type!=='string')throw Error('untyped');if(frame.type==='welcome'){welcome=true;for(const k of ['token','progressToken'])if(k in frame)frame[k]=null;}
if(['start','lobby'].includes(frame.type)&&Number.isInteger(frame.roundRevision)&&frame.roundRevision!==round){round=frame.roundRevision;marker('round',{roundRevision:round});}
add({direction:'server',frame});count++;if(frame.type==='error')finish('server_error');}catch{finish('malformed_message');}});
ws.addEventListener('close',()=>finish('remote_disconnect'));ws.addEventListener('error',()=>finish('transport_error'));}catch{finish('connection_error');}
