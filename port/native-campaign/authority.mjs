import http from 'node:http';
import {WebSocketServer, WebSocket} from 'ws';
import {parseInputEnvelope} from '../../game/protocol.mjs';
import {InputBuffer} from '../native-arenas/input-buffer.mjs';
import {EventCursor} from '../native-arenas/event-cursor.mjs';
import {loadCampaignMap} from './maps.mjs';
import {missionForCampaign} from './missions.mjs';
import {createCampaignMatch} from './match.mjs';
import {attachSoloCheats, parseSoloCheat, soloCheatPreferences} from '../native-debug/solo_cheats.mjs';

export const LIMITS=Object.freeze({payload:16384,frame:1048576,outbound:2097152,messagesPerSecond:120,burst:128});
const loopback = address => ['127.0.0.1','::1','::ffff:127.0.0.1'].includes(address);
const record = value => value !== null && typeof value==='object' && !Array.isArray(value);
const integer = value => Number.isSafeInteger(value) && value>=1;
function keys(value, allowed) {
  if (!record(value) || Object.keys(value).some(key=>!allowed.includes(key))) throw new TypeError('Unsupported frame fields');
}
const numbers=['x','z','yaw','pitch','weapon'];
const buttons=['fire','jump','power','interact','sprint','crouch','ads','reload','melee','grenade','mobility','altFire'];
export function validateCampaignInput(frame) {
  keys(frame,['type','seq','input','inputEpoch','cancel']);
  if (!integer(frame.seq)) throw new TypeError('Invalid input sequence');
  if (frame.inputEpoch!==undefined && !integer(frame.inputEpoch)) throw new TypeError('Invalid input epoch');
  if (frame.cancel!==undefined && typeof frame.cancel!=='boolean') throw new TypeError('Invalid cancellation');
  keys(frame.input,[...numbers,...buttons]);
  for (const key of numbers) if (frame.input[key]!==undefined && !Number.isFinite(frame.input[key])) throw new TypeError('Non-finite controls');
  for (const key of buttons) if (frame.input[key]!==undefined && typeof frame.input[key]!=='boolean') throw new TypeError('Invalid button');
  return parseInputEnvelope(frame);
}

/** Unbound local authority. mapLoader is a trusted in-process deterministic-test seam. */
export function createAuthority(options={}) {
  keys(options,['mapId','difficulty','random','observe','mapLoader','matchFactory']);
  const {mapId='rootfall-verge',difficulty='normal',random=Math.random,observe=()=>{},mapLoader=loadCampaignMap,matchFactory=createCampaignMatch}=options;
  missionForCampaign(mapId);
  if (!['easy','normal','hard'].includes(difficulty)) throw new TypeError('Unsupported difficulty');
  if ([random,observe,mapLoader,matchFactory].some(fn=>typeof fn!=='function')) throw new TypeError('Invalid authority callbacks');
  let data=mapLoader(mapId), socket=null, match=null, created=false, selected=false, epochRequired=false;
   let epoch=0,seq=0,round=0,cursor=null,closing=false,closePromise,finished=false,playerName='Operator',chapterKills=0,storyCarry={};
  let wall=performance.now(),accumulator=0,tokens=LIMITS.burst,tokenAt=wall;
  const inputs=new InputBuffer();
  let cheats=null, cheatPreferences=soloCheatPreferences();
  const report=value=>observe({...value,round,observedMs:performance.now()});
  function detach(ws) {if(socket===ws){socket=null;match=null;created=false;selected=false;finished=false;inputs.reset();accumulator=0;}}
  function terminate(reason) {report({direction:'transport-error',reason});const ws=socket;if(ws){detach(ws);ws.terminate();}}
  function send(frame) {
    if(socket?.readyState!==WebSocket.OPEN)return;
    const text=JSON.stringify(frame),bytes=Buffer.byteLength(text);
    if(bytes>LIMITS.frame || bytes+socket.bufferedAmount>LIMITS.outbound){terminate('Outbound limit');return;}
    report({direction:'out',frame:JSON.parse(text)});
    const ws=socket;ws.send(text,error=>{if(error&&socket===ws)terminate('Send failed');});
  }
  const server=http.createServer({maxHeaderSize:8192},(req,res)=>{
    if(!loopback(req.socket.remoteAddress)){res.writeHead(403);res.end();return;}
    if(!['GET','HEAD'].includes(req.method)){res.writeHead(405);res.end();return;}
    if(req.url!=='/'){res.writeHead(404);res.end();return;}
    res.writeHead(200,{'Content-Type':'application/json'});
    res.end(JSON.stringify({service:'cocs-native-campaign',v:3,localOnly:true,humanCount:1,
      mapId:data.id,geometryHash:data.geometryHash,port:server.address()?.port}));
  });
  server.maxConnections=8;server.requestTimeout=5000;server.headersTimeout=5000;server.keepAliveTimeout=1000;
  const wss=new WebSocketServer({noServer:true,maxPayload:LIMITS.payload,perMessageDeflate:false});
  const config=()=>({mode:'campaign',difficulty,botCount:0,timeLimit:900,fragLimit:5});
  const lobby=()=>send({type:'lobby',roomId:'local-quiet-relay',hostId:0,mapId:selected?data.id:null,
    config:selected?config():null,started:!!match&&!finished,roundRevision:round,
    players:[{peerId:0,actorId:0,name:playerName,connected:true,spectate:false}]});
  function reset(reason) {inputs.cancel();epoch++;send({type:'native-arena-input-reset',inputEpoch:epoch,reason});}
  function snapshot(type='snapshot') {send({type,seq:++seq,acks:{0:inputs.applied},inputEpoch:epoch,
    nativeArenaInput:inputs.status(),state:match.snapshot()});}
  function start(resume={}) {
    match=matchFactory({...resume,mapId:data.id,difficulty,random,mapData:data});
    cheats=attachSoloCheats(match,cheatPreferences);
    match.actors[0].name=playerName;
    inputs.reset();epoch++;seq=0;round++;finished=false;cursor=new EventCursor();
    wall=performance.now();accumulator=0;
    send({type:'start',mapId:data.id,geometryHash:data.geometryHash,inputEpoch:epoch,roundRevision:round});
    const events=cursor.take(match);if(events.length)send({type:'events',items:events});snapshot();
  }
  server.on('upgrade',(req,stream,head)=>{
    if(closing||socket||!loopback(req.socket.remoteAddress)||Object.hasOwn(req.headers,'origin')||!['/','/native-campaign'].includes(req.url)){stream.destroy();return;}
    wss.handleUpgrade(req,stream,head,ws=>wss.emit('connection',ws,req));
  });
  server.on('clientError',(_error,stream)=>stream.destroy());
  wss.on('error',()=>terminate('WebSocket server error'));
  wss.on('connection',ws=>{
     socket=ws;tokens=LIMITS.burst;tokenAt=performance.now();data=mapLoader(mapId);chapterKills=0;storyCarry={};cheatPreferences=soloCheatPreferences();cheats=null;
    ws.on('error',()=>{detach(ws);ws.terminate();});ws.on('close',()=>detach(ws));
    ws.on('message',(bytes,binary)=>{
      if(socket!==ws||closing)return;
      const now=performance.now();tokens=Math.min(LIMITS.burst,tokens+(now-tokenAt)*LIMITS.messagesPerSecond/1000);tokenAt=now;
      if(binary||--tokens<0){terminate('Input transport limit');return;}
      try {
        const f=JSON.parse(String(bytes));if(!record(f))throw new TypeError('Object required');
        report({direction:'in',frame:structuredClone(f)});
        if(f.type==='create'&&!created){
          keys(f,['type','v','name','playerName','delta','nativeArenaInput']);
          if(f.v!==3||(f.delta!==undefined&&f.delta!==0)||(f.nativeArenaInput!==undefined&&f.nativeArenaInput!==1))throw new TypeError('Protocol 3 required');
          for(const key of ['name','playerName'])if(f[key]!==undefined&&(typeof f[key]!=='string'||f[key].length>128))throw new TypeError('Invalid name');
          playerName=(f.playerName??'Operator').replace(/[\u0000-\u001f\u007f]/g,'').trim().slice(0,20)||'Operator';
          created=true;epochRequired=f.nativeArenaInput===1;
          send({type:'welcome',v:3,roomId:'local-quiet-relay',peerId:0,host:true,nativeArenaInput:1,humanCount:1,geometryHash:data.geometryHash});lobby();
        }else if(f.type==='host'&&created&&!match){
          keys(f,['type','mapId','config']);keys(f.config,['mode','difficulty','botCount','timeLimit','fragLimit','mission']);
          if(f.mapId!==mapId||f.config.mode!=='campaign')throw new TypeError('Launch campaign is fixed');
          selected=true;lobby();
        }else if(f.type==='start'&&created&&!match){keys(f,['type']);selected=true;start();
        }else if(f.type==='input'&&match){
          const parsed=validateCampaignInput(f);
          if((epochRequired||f.inputEpoch!==undefined)&&f.inputEpoch!==epoch)return;
          if(match.over)return;
          inputs.receive(f.seq,parsed,now,f.cancel===true);
        }else if(f.type==='solo-cheat'&&match&&cheats){
          const command=parseSoloCheat(f);
          if(command.inputEpoch!==epoch)return;
          if(cheats.apply(command)){
            if(command.action==='pause')reset('cheat-menu');
            snapshot();
          }
        }else if(f.type==='campaign-action'&&match){
          keys(f,['type','action','inputEpoch']);
          if(!integer(f.inputEpoch)||!['retry','restart','continue'].includes(f.action))throw new TypeError('Invalid campaign action');
          if(f.inputEpoch!==epoch)return;
          const status=match.snapshot().campaign;
          if(f.action==='retry'){
            if(status.phase!=='dead')return;
             start(match.campaignCheckpoint());
           }else if(f.action==='restart'){
             const previous=match.campaignStoryContinuity?.()??storyCarry;
             storyCarry={chapters:{...previous.chapters}};delete storyCarry.chapters[data.id];
             start({totalElapsed:Math.max(0,status.totalElapsed-status.elapsed),kills:chapterKills,storyCarry});
           }
          else if(status.phase==='level-complete'){
             if(status.nextMapId){chapterKills=status.kills;storyCarry=match.campaignStoryContinuity?.()??storyCarry;
               data=mapLoader(status.nextMapId);start({totalElapsed:status.totalElapsed,kills:status.kills,storyCarry});}
            else{
              // A terminal chapter already latched all client result guards.
              // Reopen the same completed match as a fresh transport round,
              // without rebuilding actors, objectives, elapsed time or kills.
              inputs.reset();epoch++;seq=0;round++;finished=true;accumulator=0;
              match.completeCampaign();
              send({type:'start',mapId:data.id,geometryHash:data.geometryHash,inputEpoch:epoch,roundRevision:round});
              snapshot('results');
            }
          }
        }else if(f.type==='ping'&&created){keys(f,['type','t']);send({type:'pong',...(Number.isFinite(f.t)?{t:f.t}:{})});
        }else throw new TypeError('Invalid campaign lifecycle command');
      }catch(error){send({type:'error',message:error.message});terminate(error.message);}
    });
  });
  const timer=setInterval(()=>{
    const now=performance.now(),elapsed=Math.max(0,(now-wall)/1000);wall=now;
    if(!match||finished){accumulator=0;return;}
    accumulator=Math.min(accumulator+elapsed,5/60);
    try{
      for(let ticks=0;accumulator>=1/60&&ticks<5&&!finished;ticks++){
        accumulator-=1/60;if(!cheats?.state.paused&&inputs.expired(now))reset('stale-input');
        const sample=inputs.take();match.step(1/60,{inputs:{0:sample.input}});inputs.stepped(sample.seq);
        report({direction:'step',inputEpoch:epoch,inputSeq:sample.seq,controls:{...sample.input},sourceTime:match.time,...inputs.status()});
        const events=cursor.take(match);if(events.length)send({type:'events',items:events});
        if(match.over){finished=true;reset(match.snapshot().campaign.phase);snapshot('results');}
        else snapshot();
      }
    }catch(error){terminate(`Authority step failed: ${error.message}`);}
  },1000/60);
  return {server,wss,close(){
    if(closePromise)return closePromise;closing=true;clearInterval(timer);inputs.cancel();
    closePromise=(async()=>{for(const ws of wss.clients)ws.terminate();await new Promise(resolve=>wss.close(resolve));
      server.closeAllConnections();if(server.listening)await new Promise(resolve=>server.close(resolve));socket=null;match=null;})();
    return closePromise;
  }};
}
export const createCampaignAuthority=createAuthority;
