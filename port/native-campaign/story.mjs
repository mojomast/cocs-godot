import {floorAt, obstructed, visible} from './core.generated.mjs';
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
// Reviewed maps are immutable. Separate arena identities, replaced terrain
// surfaces, or replaced authored route/anchors each require a fresh placement.
// The WeakMap bounds retained geometry to the lifetime of its arena.
const placementCache=new WeakMap();

/** Resolve a nearby reviewed critical-path point, retaining a walkable route to
 * each character. Source collision and adjacent terrain clearance validate it. */
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

function storyPositions(data) {
  const arena=data.arena,surfaces=arena.terrain.surfaces,path=data.campaign.criticalPath,a=data.campaign.anchors;
  const cached=placementCache.get(arena);
  if(cached?.surfaces===surfaces&&cached.path===path&&cached.anchors===a)return cached.positions;
  const operators={arrival:place(data,a.start,6),archive:place(data,a['encounter-1'],-7),
    repeater:place(data,a['encounter-3'],-7),departure:place(data,a.exit,-9),
    pump:place(data,a['encounter-2'],-7),bridge:place(data,a['encounter-4'],-7),
    bus:place(data,a['encounter-2'],-7),uplink:place(data,a['encounter-4'],-7),
    feeder:place(data,a['encounter-2'],-7),cradle:place(data,a['encounter-3'],-7),
    reunion:place(data,a.exit,-12)};
  const puppies={arrival:place(data,a.start,9),reunion:place(data,a.exit,-15)};
  for(const p of [...Object.values(operators),...Object.values(puppies)])Object.freeze(p);
  const positions=Object.freeze({operators:Object.freeze(operators),puppies:Object.freeze(puppies)});
  placementCache.set(arena,{surfaces,path,anchors:a,positions});
  return positions;
}
export function storyPlacement(data) {return storyPositions(data).operators;}

export function createCampaignStory(data,carry={}) {
  const chapter=data.id,{operators:placements,puppies:puppyPlaces}=storyPositions(data),beats=scripts[chapter];
  if(!beats)throw new TypeError('Unknown story chapter');
  const previous=structuredClone(carry.chapters??{}),saved=previous[chapter]??{};
  const completed=new Set(saved.completed??[]),petIds=new Set(saved.petIds??[]);
  let petCount=saved.petCount??0;
  const previousPets=Object.entries(previous).reduce((n,[id,v])=>n+(id===chapter?0:v.petCount??0),0);
  let reactionSerial=saved.reactionSerial??0,caption=null,captionUntil=0,nextCaptionAt=0,held=false,lastPetAt=saved.lastPetAt??-Infinity;
  const puppyPositions=chapter==='crown-array'?['arrival','reunion']:['arrival'];
  const puppyId=key=>key==='arrival'?'patch':`patch-${key}`;
  const puppyAt=(step)=>puppyPositions.find(key=>key==='arrival'?step<=1:step>=5);
  const mandatory=(state,player)=>{
    const e=state.encounter,marker=state.marker;
    return e&&['interact','restore'].includes(e.mechanic)&&state.deployed&&state.enemiesRemaining===0&&
      near(player,marker)<=marker.radius&&Math.abs(player.y-marker.y)<3;
  };
  const activeBeat=step=>beats.findLast(([,required])=>step>=required);
  function entities(step) {
    const beat=activeBeat(step),out=beat?[{...OPERATORS[beat[2]],...placements[beat[0]],yaw:0,pose:beat[3],active:true,reactionSerial:0}]:[];
    const puppy=puppyAt(step);
    if(puppy){const p=puppyPlaces[puppy];out.push({...PATCH,...p,yaw:0,pose:petIds.has(puppyId(puppy))?'happy':'sit',active:true,reactionSerial});}
    return out;
  }
  function update(state,player,interact,arena) {
    const step=state.stepIndex,now=state.totalElapsed,active=entities(step),pup=active.find(e=>e.kind==='puppy');
    const eligible=pup&&near(player,pup)<=2.6&&Math.abs(player.y-pup.y)<=1.4&&
      visible({x:player.x,y:player.y+1.15,z:player.z},{x:pup.x,y:pup.y+.55,z:pup.z},arena);
    const prompt=eligible&&!mandatory(state,player)?{entityId:pup.id,action:'pet',text:'E  Pet Patch'}:null;
    if(interact&&!held&&prompt&&now-lastPetAt>=1){
      reactionSerial++;petCount++;petIds.add(puppyId(puppyAt(step)));
      lastPetAt=now;
      caption={id:`${chapter}-pet-${reactionSerial}`,speaker:'Patch',text:previousPets+petCount===1?'Patch leans into your hand and wags his tail.':'Patch recognizes you and bounds over for another scratch.'};
      captionUntil=now+4;nextCaptionAt=captionUntil+.4;
    }
    held=interact;
    if(now>=nextCaptionAt){
      const beat=activeBeat(step),key=beat?.[0];
      if(beat&&!completed.has(key)&&near(player,placements[key])<13&&Math.abs(player.y-placements[key].y)<3){completed.add(key);caption={id:`${chapter}-${key}`,speaker:beat[4],text:beat[5]};captionUntil=now+5;nextCaptionAt=captionUntil+.5;}
    }
    if(caption&&now>=captionUntil)caption=null;
    return {version:1,entities:entities(step),prompt,caption,completed:[...completed].map(id=>`${chapter}-${id}`),
      pets:previousPets+petCount};
  }
  function continuity(){return {chapters:{...previous,[chapter]:{completed:[...completed],petIds:[...petIds],petCount,reactionSerial,lastPetAt}}};}
  return {update,continuity};
}
