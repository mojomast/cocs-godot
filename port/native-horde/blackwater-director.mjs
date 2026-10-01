// Local-authority mission overlay. No protocol frame can set phase or progress;
// server proximity + a real input pulse arm each station. Source owns waves,
// combat, lives, victory, upgrade offers and map gates.
import {resupplyHorde} from '../../game/singleplayer.mjs';
const STATIONS=Object.freeze([
 {id:'north-feeder',x:-170,z:78,seconds:5,wave:1,caption:'NORTH FEEDER · HOLD POSITION'},
 {id:'south-feeder',x:-82,z:-78,seconds:5,wave:1,caption:'SOUTH FEEDER · HOLD POSITION'},
 {id:'switch-pump',x:0,z:78,seconds:12,wave:4,caption:'SWITCH PUMP · DEFEND THE REPAIR'},
 {id:'relief-valve',x:170,z:-82,seconds:7,wave:7,caption:'RELIEF VALVE · VENT THE SPILLWAY'},
]);
export const BLACKWATER_STATIONS=STATIONS;
export class BlackwaterDirector{
 constructor(){this.tick=0;this.progress=Object.fromEntries(STATIONS.map(s=>[s.id,0]));this.active=null;this.done=[];this.serial=0;}
 step(match,input={},dt=1/60){
  if(match.over||match.modeState?.kind!=='horde')return;
  this.tick++;
  const player=match.actors[0],wave=match.modeState.wave;
  if(!player||player.health<=0||!player.grounded){this.active=null;return;}
  const eligible=STATIONS.filter(s=>!this.done.includes(s.id)&&wave>=s.wave&&
   (s.id!=='switch-pump'||this.done.includes('north-feeder')&&this.done.includes('south-feeder'))&&
   (s.id!=='relief-valve'||this.done.includes('switch-pump')));
  if(input.interact===true){
   const station=eligible.find(s=>Math.hypot(player.x-s.x,player.z-s.z)<=5);
   if(station){this.active={id:station.id,until:this.tick+900};match.emit('blackwater-station-armed',{station:station.id,x:station.x,z:station.z});}
  }
  const station=eligible.find(s=>s.id===this.active?.id);
  if(!station||this.tick>this.active.until){this.active=null;return;}
  if(Math.hypot(player.x-station.x,player.z-station.z)>6.5)return;
  this.progress[station.id]=Math.min(station.seconds,this.progress[station.id]+dt);
  if(this.progress[station.id]<station.seconds)return;
  this.done.push(station.id);this.active=null;this.serial++;
  // Public pickup state is the source pickup instance. Completing the longer
  // hold/valve also invokes the source's real resupply (including upgrade
  // reapplication), rather than painting a cosmetic HUD success.
  const pickup=match.pickups.find(p=>Math.hypot(p.x-station.x,p.z-station.z)<48);
  if(pickup)pickup.wait=0;
  if(station.id==='switch-pump'||station.id==='relief-valve')resupplyHorde(match,match.modeState);
  match.emit('blackwater-station-restored',{station:station.id,serial:this.serial,x:station.x,z:station.z,pickupId:pickup?.id??null});
 }
 snapshot(match){
  const wave=match.modeState?.wave??0;
  return {version:1,tick:this.tick,serial:this.serial,wave,active:this.active?.id??null,
   completed:[...this.done],stations:STATIONS.map(s=>({id:s.id,x:s.x,z:s.z,caption:s.caption,
    available:wave>=s.wave&&(s.id!=='switch-pump'||this.done.includes('north-feeder')&&this.done.includes('south-feeder'))&&
      (s.id!=='relief-valve'||this.done.includes('switch-pump')),
    progress:this.progress[s.id],required:s.seconds}))};
 }
}
