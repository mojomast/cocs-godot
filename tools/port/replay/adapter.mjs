// Local presentation adapter. Deliberately imports no Match, Room, input or career code.
import {DemoRecorder, DemoPlayer, DemoPlayback, parseDemo, serializeDemo, trimDemo} from '../../../game/demo.mjs';
import {readFileSync, mkdirSync, readdirSync, lstatSync, openSync, readSync, closeSync, writeFileSync, constants} from 'node:fs';
import {join} from 'node:path';
import {createHash, randomUUID} from 'node:crypto';
import {gunzipSync} from 'node:zlib';

export const ADMISSION = JSON.parse(readFileSync(new URL('../../../godot/replay/admission.json', import.meta.url)));
export const LIMIT = Object.freeze({bytes:32*1024*1024, packet:1024*1024, frames:10801, events:32000, seconds:600, actors:64, items:512, files:200});
const fail = message => { throw Error(message); };
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const finite = value => typeof value === 'number' && Number.isFinite(value) && Math.abs(value) <= 1e9;
const integer = value => Number.isSafeInteger(value) && value >= 0 && value <= 1e9;
const banned = /^(?:__proto__|prototype|constructor|password|token|resumeToken|reconnectTicket|credentials|authorization|cookie|secret)$/i;

// Applied before source clonePlain/cloneRounded and before passing any data to Godot.
export function boundedTree(value, maxBytes = LIMIT.bytes) {
  let nodes=0, bytes=0;
  function walk(v, depth) {
    if (++nodes > 3000000 || depth > 24) fail('Replay nesting/count limit exceeded');
    if (v === null || typeof v === 'boolean') { bytes+=5; return; }
    if (typeof v === 'number') { if (!finite(v)) fail('Replay contains a non-finite/out-of-range number'); bytes+=24; return; }
    if (typeof v === 'string') { if(v.length>4096) fail('Replay string too long'); bytes+=Buffer.byteLength(v)+2; return; }
    if (typeof v !== 'object') fail('Replay must contain JSON data only');
    if (!Array.isArray(v) && Object.getPrototypeOf(v)!==Object.prototype && Object.getPrototypeOf(v)!==null) fail('Replay object prototype rejected');
    for (const [k, child] of Object.entries(v)) {
      if (banned.test(k)) fail('Replay credential/prototype field rejected');
      bytes+=k.length+3; walk(child,depth+1);
      if(bytes>maxBytes) fail('Replay size limit exceeded');
    }
  }
  walk(value,0); return value;
}

export function admit(mapId, mode) {
  const entry=ADMISSION.maps[mapId];
  if (!Object.hasOwn(ADMISSION.maps,mapId)) fail(`Unsupported replay map: ${String(mapId)}`);
  if (!entry.modes.includes(mode)) fail(`Unsupported replay mode: ${String(mode)}`);
  return entry;
}
function list(value, cap, name) {
  if(!Array.isArray(value)||value.length>cap) fail(`Invalid replay ${name}`);
  return value;
}
function numericFields(item, keys) {
  for(const k of keys) if(item[k]!==undefined && !finite(item[k])) fail(`Invalid replay numeric field: ${k}`);
}
function entities(items, name, cap, point=true) {
  const ids=new Set();
  for(const item of list(items,cap,name)) {
    if(!object(item)||!integer(item.id)||ids.has(item.id)) fail(`Invalid/duplicate ${name} identity`);
    ids.add(item.id);
    if(point) for(const k of ['x','y','z']) if(!finite(item[k])) fail(`Invalid ${name} position`);
  }
}
export function validateState(state, map, mode) {
  if(!object(state)||!finite(state.time)||state.time<0||!object(state.config)) fail('Invalid replay snapshot');
  if(state.mapId!==map||state.config.mode!==mode) fail('Replay changes map/mode within clip');
  entities(state.actors,'actors',LIMIT.actors);
  for(const actor of state.actors) {
    numericFields(actor,['yaw','bodyYaw','pitch','vx','vy','vz','health','dead','weapon','shots','armor','eyeHeight','speedMultiplier','active','melee','weaponSwitch','spread','punchYaw','punchPitch','reloadTimer','reloadDuration','frags','deaths']);
    if(actor.weapon!==undefined && (!integer(actor.weapon)||actor.weapon>9)) fail('Invalid replay weapon');
    if(actor.character!==undefined&&typeof actor.character!=='string') fail('Invalid replay character');
  }
  // First admission is on-foot combat, not a promise of vehicle/campaign playback.
  if((state.vehicles?.length??0)>0) fail('Vehicle replay is not supported by this player');
  entities(state.pickups??[],'pickups',LIMIT.items);
  for(const item of state.pickups??[]) {
    if(typeof item.kind!=='string') fail('Invalid pickup kind'); numericFields(item,['wait']);
  }
  entities(state.rockets??[],'rockets',LIMIT.items,false);
  for(const rocket of state.rockets??[]) {
    if(!object(rocket.pos)||!['x','y','z'].every(k=>finite(rocket.pos[k]))) fail('Invalid rocket position');
  }
  return state;
}
function validateEvents(events) {
  const ids=new Set();
  for(const event of list(events,LIMIT.events,'events')) {
    if(!object(event)||!finite(event.time)||event.time<0||typeof event.type!=='string') fail('Invalid replay event');
    if(event.id!==undefined) {
      if(!integer(event.id)) fail('Invalid event identity');
      if(ids.has(event.id)) fail('Duplicate replay event identity'); ids.add(event.id);
    }
  }
}
export function validateDemo(demo) {
  boundedTree(demo);
  if(!object(demo)||demo.version!==1||!object(demo.header)||!object(demo.header.config)) fail('Unsupported replay format/version');
  const map=demo.header.mapId, mode=demo.header.config.mode;
  const entry=admit(map,mode);
  const frames=list(demo.keyframes,LIMIT.frames,'keyframes');
  if(!frames.length) fail('Replay has no frames');
  let last=-1;
  for(const f of frames) {
    if(!object(f)||!finite(f.time)||f.time<0||f.time<=last||f.state?.time!==f.time) fail('Invalid/non-monotonic replay frame time');
    validateState(f.state,map,mode); last=f.time;
  }
  if(last-frames[0].time>LIMIT.seconds) fail('Replay exceeds ten minutes');
  validateEvents(demo.events);
  const p=demo.meta?.nativeReplay;
  if(p && (p.version!==1||p.sourceCommit!==ADMISSION.sourceCommit||p.derivativeCommit!==ADMISSION.derivativeCommit||p.sourceContractSha256!==ADMISSION.sourceContractSha256||p.derivativeContractSha256!==ADMISSION.derivativeContractSha256||p.coreSha256!==ADMISSION.coreSha256||p.semanticSha256!==entry.semanticSha256||p.demoSha256!==ADMISSION.demoSha256)) fail('Replay provenance does not match installed catalog');
  return demo;
}
export function decode(bytes) {
  if(Buffer.byteLength(bytes)>LIMIT.bytes) fail('Replay file exceeds 32 MiB');
  let data=Buffer.from(bytes);
  if(data[0]===31&&data[1]===139) data=gunzipSync(data,{maxOutputLength:LIMIT.bytes});
  return validateDemo(parseDemo(data));
}
export function verifySourceModule() {
  const bytes=readFileSync(new URL('../../../game/demo.mjs',import.meta.url));
  if(createHash('sha256').update(bytes).digest('hex')!==ADMISSION.demoSha256) fail('Source demo module hash mismatch');
}
function provenance(map, role) {
  return {version:1,sourceCommit:ADMISSION.sourceCommit,derivativeCommit:ADMISSION.derivativeCommit,sourceContractSha256:ADMISSION.sourceContractSha256,derivativeContractSha256:ADMISSION.derivativeContractSha256,coreSha256:ADMISSION.coreSha256,demoSha256:ADMISSION.demoSha256,semanticSha256:ADMISSION.maps[map].semanticSha256,catalogCompatibilityOnly:true,role,stream:'delivered-client-snapshots'};
}
export class Capture {
  constructor({mapId,mode,role}) {
    admit(mapId,mode);
    if(!['seated','spectator'].includes(role)) fail('Unknown recording role');
    this.map=mapId; this.mode=mode; this.role=role; this.last=-1; this.bytes=0;
    this.recorder=new DemoRecorder({recordHz:18,maxSeconds:LIMIT.seconds,meta:{nativeReplay:provenance(mapId,role)}});
  }
  frame({state,events=[],role}) {
    if(role!==this.role) fail('Recording role changed; save this clip and start a new one');
    boundedTree({state,events},LIMIT.packet);
    validateState(state,this.map,this.mode);
    // Delivered event batches can repeat IDs; source recorder owns deduplication.
    validateEvents(events);
    if(state.time<this.last) fail('Round changed; save this clip and start a new one');
    this.last=state.time;
    const rec=this.recorder;
    const fresh=events.filter(e=>e.id===undefined||!rec.eventIds.has(e.id));
    if(rec.events.length+fresh.length>LIMIT.events) fail('Recording event limit reached; save clip');
    const due=rec.due(state.time);
    const bytes=Buffer.byteLength(JSON.stringify(due?{state,events:fresh}:{events:fresh}));
    if(this.bytes+bytes>LIMIT.bytes/2||rec.frameCount>=LIMIT.frames) fail('Recording limit reached; save clip');
    if(rec.keyframes.length&&state.time-rec.keyframes[0].time>LIMIT.seconds) fail('Ten-minute recording limit reached; save clip');
    this.bytes+=bytes;
    rec.frame(state,events);
    return {frames:rec.frameCount,duration:rec.duration};
  }
  finish(maxSeconds=null) {
    if(maxSeconds===null) {
      const limit=this.recorder.keyframes[0]?.state?.config?.timeLimit;
      maxSeconds=finite(limit)&&limit>0?Math.min(limit,LIMIT.seconds):LIMIT.seconds;
    }
    if(!finite(maxSeconds)||maxSeconds<0||maxSeconds>LIMIT.seconds) fail('Invalid trim duration');
    return validateDemo(trimDemo(this.recorder.finish(),maxSeconds));
  }
}

// Whitelist the data read by native visual actors; never attach a live/private HUD.
const visualNumbers='id x y z vx vy vz yaw bodyYaw pitch health armor dead weapon shots eyeHeight active melee weaponSwitch spread punchYaw punchPitch reloadTimer reloadDuration frags deaths'.split(' ');
export function visualState(state) {
  return {mapId:state.mapId,mapName:state.mapName,time:state.time,over:state.over===true,config:{mode:state.config.mode},
    actors:state.actors.map(a=>Object.fromEntries([...visualNumbers.filter(k=>finite(a[k])).map(k=>[k,a[k]]),...['character','harness','name'].filter(k=>typeof a[k]==='string').map(k=>[k,a[k]]),...['team'].filter(k=>integer(a[k])).map(k=>[k,a[k]]),...['crouching','sprinting','sliding','grounded','ads','reloading'].map(k=>[k,a[k]===true])])),
    pickups:(state.pickups??[]).map(p=>({id:p.id,kind:p.kind,x:p.x,y:p.y,z:p.z,wait:finite(p.wait)?p.wait:0})),
    rockets:(state.rockets??[]).map(r=>({id:r.id,owner:integer(r.owner)?r.owner:0,weapon:integer(r.weapon)?r.weapon:0,pos:{x:r.pos.x,y:r.pos.y,z:r.pos.z},dir:object(r.dir)&&['x','y','z'].every(k=>finite(r.dir[k]))?{x:r.dir.x,y:r.dir.y,z:r.dir.z}:{x:0,y:0,z:-1},alt:r.alt===true,altId:typeof r.altId==='string'?r.altId:'',mine:r.mine===true,bomblets:finite(r.bomblets)?r.bomblets:0,flak:finite(r.flak)?r.flak:0,arm:finite(r.arm)?r.arm:0}))};
}
export function visualEvents(events) {
  return events.filter(e=>['shot','explosion','launch','death'].includes(e.type)).map(e=>{
    const out={type:e.type,time:e.time};
    for(const k of ['id','actor','weapon','killer']) if(integer(e[k])) out[k]=e[k];
    for(const k of ['from','to','pos']) if(object(e[k])&&['x','y','z'].every(a=>finite(e[k][a]))) out[k]={x:e[k].x,y:e[k].y,z:e[k].z};
    return out;
  });
}
export class Playback {
  constructor(demo) {
    this.demo=validateDemo(demo); this.player=new DemoPlayer(demo);
    this.clock=new DemoPlayback(this.player,{paused:true}); this.offset=demo.keyframes[0].time; this.generation=0;
  }
  command({op, time, speed, dt}) {
    let clear=false, events=[];
    if(op==='seek') {if(!finite(time)) fail('Invalid seek');this.clock.seek(time);clear=true;}
    else if(op==='speed') {if(![.25,.5,1,2,4].includes(speed)) fail('Unsupported replay speed');this.clock.setSpeed(speed);clear=true;}
    else if(op==='play') this.clock.play();
    else if(op==='pause') {this.clock.pause();clear=true;}
    else if(op==='tick') {
      if(!finite(dt)||dt<0||dt>.25) fail('Invalid playback tick');
      const before=this.clock.time; this.clock.advance(dt);
      events=this.player.eventsBetween(this.offset+before,this.offset+this.clock.time);
      // At accelerated speed or a long host frame consume time but don't burst cues.
      if(this.clock.speed!==1||dt>.1||events.length>64) {events=[];clear=true;}
      if(this.clock.ended) this.clock.pause();
    } else if(op!=='sample') fail('Unknown playback command');
    if(clear) this.generation++;
    return {time:this.clock.time,duration:this.clock.duration,paused:this.clock.paused,speed:this.clock.speed,generation:this.generation,clear,state:visualState(this.clock.sample()),events:visualEvents(events),phase:this.clock.ended?'ended':this.clock.paused?'paused':'playing'};
  }
}

const fileId = id => {if(typeof id!=='string'||!/^clip-[0-9a-f-]{36}\.json$/.test(id)) fail('Invalid local replay identity');return id;};
export class Library {
  constructor(root) {this.root=root;mkdirSync(root,{recursive:true});}
  read(id) {
    const path=join(this.root,fileId(id));
    if(!lstatSync(path).isFile()||lstatSync(path).isSymbolicLink()) fail('Replay must be a regular local file');
    const fd=openSync(path,constants.O_RDONLY|(constants.O_NOFOLLOW??0));
    try {
      const size=lstatSync(path).size;
      if(size>LIMIT.bytes) fail('Replay file exceeds 32 MiB');
      const buf=Buffer.alloc(size); if(readSync(fd,buf,0,size,0)!==size) fail('Incomplete replay file');return decode(buf);
    } finally {closeSync(fd);}
  }
  save(demo) {
    validateDemo(demo);
    if(this.ids().length>=LIMIT.files) fail('Library limit reached (200 clips); existing clips are preserved');
    const id=`clip-${randomUUID()}.json`, text=serializeDemo(demo);
    if(Buffer.byteLength(text)>LIMIT.bytes) fail('Replay file exceeds 32 MiB');
    writeFileSync(join(this.root,id),text,{flag:'wx',mode:0o600}); return this.summary(id,demo);
  }
  ids() {return readdirSync(this.root).filter(id=>/^clip-[0-9a-f-]{36}\.json$/.test(id)).sort().slice(0,LIMIT.files);}
  summary(id,d) {return {id,map:d.header.mapId,mode:d.header.config.mode,createdAt:typeof d.createdAt==='string'?d.createdAt:'Unknown date',duration:new DemoPlayer(d).duration,frames:d.keyframes.length,role:d.meta?.nativeReplay?.role??'source import (unattested recipient)',bytes:Buffer.byteLength(serializeDemo(d))};}
  list() {return this.ids().map(id=>{try{return this.summary(id,this.read(id));}catch(e){return{id,error:e.message};}});}
}

export class LocalReplay {
  constructor(root) {verifySourceModule();this.library=new Library(root);this.capture=null;this.playback=null;}
  dispatch(request) {
    if(request?.op==='import') {
      if(typeof request.text!=='string'||Buffer.byteLength(request.text)>LIMIT.bytes) fail('Invalid import size');
      return {clip:this.library.save(decode(request.text))};
    }
    boundedTree(request,LIMIT.packet);
    switch(request.op) {
      case 'ping':return {alive:true};
      case 'list':return {clips:this.library.list()};
      case 'record':if(this.capture) fail('A recording is already open');this.capture=new Capture(request);return {recording:true};
      case 'frame':if(!this.capture) fail('No recording');return this.capture.frame(request);
      case 'frames':{
        if(!this.capture) fail('No recording');
        list(request.frames,4,'capture batch');
        let result={frames:this.capture.recorder.frameCount,duration:this.capture.recorder.duration};
        for(const frame of request.frames) result=this.capture.frame(frame);
        return result;
      }
      case 'discard':this.capture=null;return {recording:false};
      case 'save':{if(!this.capture) fail('No recording');const clip=this.library.save(this.capture.finish(request.maxSeconds??null));this.capture=null;return {clip,recording:false};}
      case 'open':this.playback=null;this.playback=new Playback(this.library.read(request.id));return this.playback.command({op:'sample'});
      case 'close':this.playback=null;return {closed:true};
      default:if(!this.playback) fail('No replay open');return this.playback.command(request);
    }
  }
}
