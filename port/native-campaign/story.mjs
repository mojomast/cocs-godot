import {floorAt, obstructed} from './core.generated.mjs';
import {campaignSupportAt} from './maps.mjs';

// The same two rescued maintenance operators return throughout the corridor.
// Character identifiers select existing playable operator meshes on the client.
const OPERATORS={mara:{id:'mara',kind:'operator',name:'Mara',character:'claude'},
  ivo:{id:'ivo',kind:'operator',name:'Ivo',character:'gemini'}};
const PATCH={id:'patch',kind:'puppy',name:'Patch'};
const scripts={
  'rootfall-verge':[
    ['arrival',0,'mara','wave','Mara','Over here! The forest repeater is still breathing. I will mark a safe approach.'],
    ['archive',1,'ivo','work','Ivo','I found ECHO in the archive fragments. Someone locked a rescue call inside the quarantine.'],
    ['repeater',3,'mara','work','Mara','The repeater is back. I can route ECHO across the canyon now.'],
    ['departure',5,'ivo','point','Ivo','Take the riverworks path. Mara and I will bring the repair kit behind you.']],
  'siltwake-crossing':[
    ['arrival',0,'ivo','wave','Ivo','We made it to the intake. Patch found the dry stones before we did.'],
    ['pump',2,'mara','work','Mara','West pump is running. I will hold the pressure while you clear the bridge.'],
    ['bridge',4,'ivo','point','Ivo','The bridge crew can hear ECHO now. Cross while Mara holds the line.'],
    ['departure',5,'mara','wave','Mara','Everyone is across. We are climbing after you.']],
  'emberline-ascent':[
    ['arrival',0,'mara','point','Mara','The cooling terrace is ahead. I will guide the others around the hot vents.'],
    ['bus',2,'ivo','work','Ivo','I have the repair key. Mara, keep the bus steady while I copy it.'],
    ['uplink',4,'mara','work','Mara','Isolation is holding. ECHO can speak without that quarantine order drowning her out.'],
    ['departure',5,'ivo','wave','Ivo','The lift is clear. I promised Patch we would all meet at the Crown.']],
  'crown-array':[
    ['arrival',0,'ivo','wave','Ivo','We are here together. The receiver is just beyond the ridge.'],
    ['feeder',2,'mara','work','Mara','Feeder is live. I can keep the transmitter powered through the upload.'],
    ['cradle',3,'ivo','point','Ivo','ECHO has the whole archive now. Let the checksum settle before the guardian arrives.'],
    ['reunion',5,'mara','wave','Mara','ECHO got through. Ivo, Patch, everyone made it. The corridor is ours again.']]
};
const near=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z);

/** Resolve a point on the reviewed critical path, rather than depending on generated
 * world coordinates. Lateral offsets are accepted only with source collision and
 * sampled terrain support/gradient clearance. The centre-line is the fallback. */
function place(data,anchor,offset) {
  const path=data.campaign.criticalPath,arena=data.arena;
  let index=0,best=Infinity;
  path.forEach((p,i)=>{const d=near(p,anchor);if(d<best){best=d;index=i;}});
  index=Math.max(0,Math.min(path.length-1,index+offset));
  for(const i of [index,...Array.from({length:9},(_,k)=>index+(k%2?-(k+1)/2:(k+2)/2))]) {
    const p=path[i];if(!p)continue;
    const y=campaignSupportAt(arena,p.x,p.z)?.y;
    if(!Number.isFinite(y)||Math.abs(y-floorAt(p.x,p.z,arena))>.08||obstructed(p.x,y,p.z,.65,arena))continue;
    let clear=true;
    for(const [dx,dz] of [[1,0],[-1,0],[0,1],[0,-1]]) {
      const s=campaignSupportAt(arena,p.x+dx,p.z+dz);
      if(!s||Math.abs(s.y-y)>.65||obstructed(p.x+dx,s.y,p.z+dz,.45,arena)){clear=false;break;}
    }
    if(clear)return {x:p.x,y,z:p.z};
  }
  throw new Error(`No supported story position near ${anchor.x},${anchor.z}`);
}

export function storyPlacement(data) {
  const a=data.campaign.anchors;
  return {arrival:place(data,a.start,6),archive:place(data,a['encounter-1'],-7),
    repeater:place(data,a['encounter-3'],-7),departure:place(data,a.exit,-9),
    pump:place(data,a['encounter-2'],-7),bridge:place(data,a['encounter-4'],-7),
    bus:place(data,a['encounter-2'],-7),uplink:place(data,a['encounter-4'],-7),
    feeder:place(data,a['encounter-2'],-7),cradle:place(data,a['encounter-3'],-7),
    reunion:place(data,a.exit,-12)};
}

function sight(arena,player,target) {
  const d=near(player,target),fromY=player.y+1.15,toY=target.y+.55;
  for(let i=1,n=Math.ceil(d/.3);i<n;i++){
    const t=i/n,x=player.x+(target.x-player.x)*t,z=player.z+(target.z-player.z)*t,y=fromY+(toY-fromY)*t;
    const floor=campaignSupportAt(arena,x,z);
    if(!floor||floor.y>y-.12||arena.blocks.some(b=>Math.abs(x-b.x)<b.w/2&&Math.abs(z-b.z)<b.d/2&&b.baseY+b.h>y))return false;
  }
  return true;
}

export function createCampaignStory(data,carry={}) {
  const chapter=data.id,placements=storyPlacement(data),beats=scripts[chapter];
  if(!beats)throw new TypeError('Unknown story chapter');
  const previous=structuredClone(carry.chapters??{}),saved=previous[chapter]??{};
  const completed=new Set(saved.completed??[]),petIds=new Set(saved.petIds??[]);
  let petCount=saved.petCount??0;
  let reactionSerial=saved.reactionSerial??0,caption=null,captionUntil=0,nextCaptionAt=0,held=false;
  const puppyPositions=chapter==='crown-array'?['arrival','reunion']:['arrival'];
  const puppyId=key=>key==='arrival'?'patch':`patch-${key}`;
  const puppyPlaces={arrival:place(data,data.campaign.anchors.start,9),
    reunion:place(data,data.campaign.anchors.exit,-15)};
  const puppyAt=(step)=>puppyPositions.find(key=>key==='arrival'?step<=1:step>=5);
  const mandatory=(state,player)=>{
    const e=state.encounter,marker=state.marker;
    return e&&['interact','restore'].includes(e.mechanic)&&state.deployed&&state.enemiesRemaining===0&&
      near(player,marker)<=marker.radius&&Math.abs(player.y-marker.y)<3;
  };
  function entities(step) {
    const active=beats.filter(([,required],i)=>step>=required&&(i===beats.length-1||step<beats[i+1][1]));
    const out=active.map(([key,,who,pose])=>({...OPERATORS[who],...placements[key],yaw:0,pose,active:true,reactionSerial:0}));
    const puppy=puppyAt(step);
    if(puppy){const p=puppyPlaces[puppy];out.push({...PATCH,...p,yaw:0,pose:petIds.has(puppyId(puppy))?'happy':'sit',active:true,reactionSerial});}
    return out;
  }
  function update(state,player,interact,arena) {
    const step=state.stepIndex,now=state.totalElapsed,active=entities(step),pup=active.find(e=>e.kind==='puppy');
    const eligible=pup&&near(player,pup)<=2.6&&Math.abs(player.y-pup.y)<=1.4&&sight(arena,player,pup);
    const prompt=eligible&&!mandatory(state,player)?{entityId:pup.id,action:'pet',text:'E  Pet Patch'}:null;
    if(interact&&!held&&prompt){
      reactionSerial++;petCount++;petIds.add(puppyId(puppyAt(step)));
      caption={id:`${chapter}-pet-${reactionSerial}`,speaker:'Patch',text:reactionSerial===1?'Patch leans into your hand and wags his tail.':'Patch recognizes you and bounds over for another scratch.'};
      captionUntil=now+4;nextCaptionAt=captionUntil+.4;
    }
    held=interact;
    if(now>=nextCaptionAt){
      const beat=beats.find(([key],i)=>active.some(e=>e.id===beats[i][2])&&!completed.has(key)&&near(player,placements[key])<13&&Math.abs(player.y-placements[key].y)<3);
      if(beat){completed.add(beat[0]);caption={id:`${chapter}-${beat[0]}`,speaker:beat[4],text:beat[5]};captionUntil=now+5;nextCaptionAt=captionUntil+.5;}
    }
    if(caption&&now>=captionUntil)caption=null;
    return {version:1,entities:entities(step),prompt,caption,completed:[...completed].map(id=>`${chapter}-${id}`),
      pets:Object.entries(previous).reduce((n,[id,v])=>n+(id===chapter?0:v.petCount??0),0)+petCount};
  }
  function continuity(){return {chapters:{...previous,[chapter]:{completed:[...completed],petIds:[...petIds],petCount,reactionSerial}}};}
  return {update,continuity};
}
