// The actual source third-person builders and post-pose grip pass, read-only,
// plus the shared world-weapon detail vocabulary.
//
// The source `simpleWeaponModel` stays the object a bot carries: same scale,
// same authored mechanics, same chassis-derived `Muzzle` / `WeaponGripLeft` /
// `WeaponGripRight` fallback contacts that `alignLivingCharacter` (source) and
// `HandGrips.align` (native) solve against. Detail is added *around* those
// mechanics in the source's own vocabulary (`beveledBox`, placed joins,
// mirrored slats): only additive geometry, anchors unchanged.
//
// Detail is grouped exactly like the source: one merged batch per material, so
// the ten weapons stay at 3-4 draws each (dark polymer, accent weapon colour,
// machined steel, and an emissive accent core only where the weapon has an
// energy/optic signature). The six identity channels - receiver massing, feed
// identity, muzzle device, stock/grip treatment, sight family, accent and
// signature greeble - match `port/native-weapon-detail/WEAPON_IDENTITY.md`
// (first-person lane, single source of truth) through the source chassis both
// exports build from.
import * as T from 'three';
import {GLTFExporter} from 'three/addons/exporters/GLTFExporter.js';
import {mergeGeometries,mergeVertices} from 'three/addons/utils/BufferGeometryUtils.js';
import {robotModel,simpleWeaponModel} from '../../game/view.mjs';
import {ModelAssets} from '../../game/effects-fx.mjs';
import {WEAPONS,CHARACTERS} from '../../game/data.mjs';
import {placedGeometry} from '../../game/model-geometry.mjs';
import {chassisFor} from '../../game/weapon-models/chassis.mjs';
import {characterPose} from '../../game/character-anim.mjs';
import {alignLivingCharacter} from '../../game/rig.mjs';
import {mkdir,writeFile,readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
globalThis.FileReader=class {readAsArrayBuffer(blob){blob.arrayBuffer().then(data=>{this.result=data;this.onloadend?.();});}};

// Shared material policy from port/native-weapon-detail/WEAPON_IDENTITY.md: the
// `detail-trim` machined-steel role is reused here (the `detail-cavity` recess
// role is folded into the source dark batch to stay inside four batches, since
// the recesses are geometrically inset instead of separately shaded).
export const DETAIL_STEEL='#c6ced2';
// Emissive core: a dark bezel so the weapon colour reads as light, not paint.
const DETAIL_GLOW_ALBEDO='#0b1114';

const triangles=geometry=>(geometry.index?geometry.index.count:geometry.attributes.position.count)/3;
const moved=(geometry,position,rotation)=>rotation?placedGeometry(geometry,position,rotation):placedGeometry(geometry,position);

// ---------------------------------------------------------------------------
// Identity: six channels per weapon, mirroring the source chassis treatments
// that the first-person viewmodel builds from. `port/native-weapon-detail/
// WEAPON_IDENTITY.md` is the shared authority; this table is the world-side
// transcription and is embedded in the manifest for reconciliation.
//
// `glow` marks the weapons whose emissive element is the shared bore/core
// treatment (used by conditionals below). Weapons marked false still carry an
// emissive part per the identity document; theirs is authored directly on the
// venturi ring (1), the chamber witness (3), the arming indicator (7) and the
// chamber port witness (9) instead of using the generic core.
export const DETAIL_IDENTITY=[
 {id:0,short:'PULSE',receiver:'slender carbine receiver with a low dorsal spine',feed:'slim box magazine with a witness-slot body',muzzle:'slotted flash hider in a long open perforated shroud',stock:'extended skeleton-stock frame and cheek riser',sight:'iron sights, rear notch over a supported front post',accent:'teal energy strip and stepped fins',signature:'open shroud hoops and three stepped fins above the port',glow:true},
 {id:1,short:'ROCKET',receiver:'continuous fat launch tube with a top carry handle',feed:'breech latch with a loaded-cell window',muzzle:'hollow trumpet blast-deflector bell',stock:'flared rear venturi and shoulder rest pad',sight:'iron sights seated on the tube spine',accent:'orange warning chevrons and arming tab',signature:'front trumpet and rear venturi pair',glow:false},
 {id:2,short:'RAIL',receiver:'long sled with full-length separated accelerator rails',feed:'underslung battery slab with a glowing charge window',muzzle:'fork tips projecting past the bore',stock:'slim fixed stock with a cheek riser and counterweight',sight:'scope on a boxy raised plinth',accent:'violet coil windings and charge window',signature:'long twin rails and forward fork',glow:true},
 {id:3,short:'SCATTER',receiver:'wide breech and broad fore-end with a break-action hinge',feed:'extractor block and a side shell carrier',muzzle:'wide twin bores in an upper/lower barrel band',stock:'wide shotgun stock with a recoil pad',sight:'ventilated raised rib and brass bead',accent:'amber shell rims in the carrier and loops',signature:'twin bores beneath a ventilated rib and selector lever',glow:false},
 {id:4,short:'PLASMA',receiver:'two rounded axial bulbs in a slab cradle',feed:'power cell with a glowing plasma window',muzzle:'projecting three-prong focus cage',stock:'vented frame stock with cable runs',sight:'iron sights on a short spine',accent:'sky-blue plasma window and cable runs',signature:'axial paired bulbs and round flank exchangers',glow:true},
 {id:5,short:'GRENADE',receiver:'squat revolver frame with a broad top strap',feed:'flared six-flute revolver drum between support legs',muzzle:'fat bore with a collar stack',stock:'compact stock with a recoil pad',sight:'iron sights with a ladder rear notch',accent:'red-orange charge light and index marks',signature:'flared slatted drum and top strap',glow:true},
 {id:6,short:'SHOCK',receiver:'square dorsal capacitor comb above the casing',feed:'capacitor cell with vent slats',muzzle:'wide projecting fork with discharge tips and tuning bridge',stock:'open frame stock with a rear insulator stack',sight:'iron sights on a short spine',accent:'cyan arc bar between the prongs',signature:'forward fork, bridge and capacitor comb',glow:true},
 {id:7,short:'FLAK',receiver:'boxy reinforced breech with trunnion discs',feed:'ammunition box feed with a belt window',muzzle:'heavy hollow flared bell',stock:'thick shoulder stock with recoil springs',sight:'iron sights beside an outboard carry handle',accent:'amber belt rounds and chevrons',signature:'box breech, flank handle and bell',glow:false},
 {id:8,short:'MARKSMAN',receiver:'long under-receiver precision chassis spine',feed:'low-profile box magazine with a floorplate',muzzle:'precision brake with three baffles',stock:'adjustable cheek riser with a butt monopod',sight:'large connected optic on a long rail',accent:'warm-sand range dial and lens glint',signature:'long spine, folded forward bipod and butt monopod',glow:true},
 {id:9,short:'SMG',receiver:'stubby stamped receiver with a flank rear drum',feed:'oversized quad-stack magazine hanging well below the receiver',muzzle:'short open compensator',stock:'extended twin-rod wire stock with a buttplate',sight:'iron sights on a short spine',accent:'mint charging handle and light module',signature:'stub receiver, huge magazine and wire stock',glow:false},
];

// ---------------------------------------------------------------------------
// Detail kit. Coordinates follow the source chassis exactly: +Z stock, -Z
// muzzle, receiver x in [-w/2,w/2], y in [my-h/2,my+h/2], z in [-len,0]; the
// muzzle sits at (0,my,mz). The source world body's own envelopes are known
// (receiver / barrel / stock / grip / feed) and every added mass sits on the
// outside of the envelope it belongs to, so almost no triangle is spent inside
// an opaque source mesh - the flush mount bases, magazine-side slats, drum hub
// caps and the deliberate open-bore emissive core are the reported exceptions.
// Detail answers the same six channels as the first-person viewmodel: rail and
// sight family on the optic mount, vents at the heat zone, a real port on the
// receiver face, feed furniture on the feed mass, and stock and grip treatment
// outside the source stock block.
export function detailKit(type){
  const spec=DETAIL_IDENTITY[type];
  const [w,h,len,mz,my,r,stockLen]=chassisFor(type);
  const top=my+h/2,bottom=my-h/2,front=-len;
  const railTop=top+.011,rearRail=-len*.94,frontRail=front-.02;
  const portZ=-len*.58,portY=my+h*.06;
  // Forward of the receiver: +Z is stock, -Z is muzzle, so the heat zone is at
  // front minus a fraction of the exposed barrel.
  const exposed=front-mz,heatZ0=front-exposed*.14,heatZ1=front-exposed*.44;
  // Source world-body envelopes (game/view.mjs buildSimpleWeaponBody).
  const stockX=w*.375,stockY=my-.03,stockH=h*.325,stockZ0=-.01,stockZ1=stockLen-.01;
  const feedW=type===3?.23:type===7?.20:.09,feedH=type===1?.07:type===3?.055:type===7?.16:type===9?.27:.16;
  const feedX=type===7?-.07:0,feedY=type===3?my-.04:bottom-.09,feedZ=type===5?-.25:type===3?-.18:-.25;
  const drumR=.125;
  const P={dark:[],accent:[],steel:[],glow:[]},Z={},zoneOf=new Map();
  let zoneName='receiver';
  const zone=name=>{zoneName=name;};
  const push=(material,geometry)=>{P[material].push(geometry);Z[zoneName]=(Z[zoneName]??0)+triangles(geometry);zoneOf.set(geometry,zoneName);};
  const box=(material,bw,bh,bd,x,y,z,rot=null)=>push(material,moved(new T.BoxGeometry(bw,bh,bd),[x,y,z],rot));
  const tube=(material,radius,length,x,y,z,segments=10,axis='z')=>{
    const g=new T.CylinderGeometry(radius,radius,length,segments);
    if(axis==='z')g.rotateX(Math.PI/2);else if(axis==='x')g.rotateZ(Math.PI/2);
    push(material,moved(g,[x,y,z]));};
  const cone=(material,r1,r2,length,x,y,z,segments=10)=>{
    // A turned, hollow shell: neither end caps the authored bore.
    const wall=.009;
    const g=new T.LatheGeometry([new T.Vector2(r1,-length/2),new T.Vector2(r2,length/2),new T.Vector2(r2-wall,length/2),new T.Vector2(r1-wall,-length/2),new T.Vector2(r1,-length/2)],segments);g.rotateX(Math.PI/2);
    push(material,moved(g,[x,y,z]));};
  const bulb=(radius,length,z)=>{
    const g=new T.SphereGeometry(radius,10,6);g.scale(1,1,length/(radius*2));
    push('steel',moved(g,[0,my,z]));};
  const ring=(material,radius,thickness,x,y,z,segments=12,radial=5,axis='z')=>{
    const g=new T.TorusGeometry(radius,thickness,radial,segments);
    if(axis==='x')g.rotateY(Math.PI/2);else if(axis==='y')g.rotateX(Math.PI/2);
    push(material,moved(g,[x,y,z]));};
  const slats=(material,count,slatW,slatH,slatD,x,y,z0,pitch)=>{for(let i=0;i<count;i++)box(material,slatW,slatH,slatD,x,y,z0+i*pitch);};
  const pair=fn=>{for(const s of [-1,1])fn(s);};

  // -- receiver massing: ribbed optic rail on the source sight station --------
  zone('mount');
  if(type===1){
    // Launch tube: carry handle instead of a rail, plus a rear notch block.
    box('dark',.028,.034,.070,0,top+.030,-len*.80);
    box('dark',.028,.034,.070,0,top+.030,-len*.30);
    box('dark',.032,.026,.190,0,top+.046,-len*.55);
    box('accent',.072,.014,.150,0,top+.014,-len*.55);
    // Canted launcher leaf ladder on the left flank (identity channel 5).
    box('steel',.010,.034,.026,-(w/2+.004),my+.030,-len*.62);
    box('steel',.010,.010,.100,-(w/2+.004),my+.046,-len*.62);
  }else if([0,3,4,5,6,7,9].includes(type)){
    // Low, un-toothed spines let the chamber, drum and fork own the outline.
    box('dark',type===3?.032:.040,.014,len*.78,0,top+.009,-len*.50);
  }else{
    const railLen=rearRail-frontRail,railW=Math.min(w*.44,.085);
    box('steel',railW,.012,railLen,0,railTop,(rearRail+frontRail)/2);
    pair(s=>box('steel',.006,.009,railLen,s*(railW/2-.002),railTop+.005,(rearRail+frontRail)/2)); // rail side lips
    const count=type===9?5:type===3?6:type===5?7:type===8?10:9;
    slats('steel',count,.040,.010,.012,0,railTop+.011,rearRail-.012,.022);
    box('dark',Math.min(w*.34,.070),.022,.028,0,top+.022,rearRail-.048);
  }
  // -- sight family ----------------------------------------------------------
  zone('sight');
  if(type===2||type===8){
    // Source scope proportions: open tube above the rail, ringed objective and
    // ocular, clamped to a base plate instead of floating over the receiver.
    const scY=top+.079,scZ=-len*.43,scLen=.30,scR=type===8?.047:.039;
    tube('steel',scR,scLen,0,scY,scZ,16);
    tube('dark',scR+.012,.11,0,scY,scZ-scLen*.5,16);
    tube('dark',scR+.005,.10,0,scY,scZ+scLen*.5-.020,16);
    ring('accent',scR+.012,.012,0,scY,scZ-.075,10,4);
    ring('accent',scR+.012,.012,0,scY,scZ+.075,10,4);
    pair(s=>box('steel',.020,.036,.030,s*(scR+.020),top+.026,scZ-.020));
    box('dark',.050,.020,scLen*.72,0,top+.022,scZ-.010);
    tube('steel',.014,.018,0,scY+scR+.008,scZ+.010,10);    // elevation turret
    tube('steel',.012,.016,scR+.008,scY,scZ+.010,10,'x');   // windage turret
    if(type===8){tube('glow',.040,.006,0,scY,scZ-scLen*.5-.057,12);
      box('glow',.026,.010,.018,0,scY-scR-.006,scZ-scLen*.5-.070);}
  }else{
    // Iron sights: rear notch with ear wings, front post on a real support
    // that spans from the barrel up to the post (source chassis proportions).
    box('dark',Math.min(w*.36,.062),.026,.020,0,top+.030,-len*.16);
    pair(s=>box('steel',.008,.028,.018,s*Math.min(.026,w*.16),top+.032,-len*.16));
    pair(s=>box('steel',.006,.036,.022,s*Math.min(.036,w*.22),top+.030,-len*.16));
    if(type===9)tube('steel',.033,.030,w/2+.015,top+.015,-len*.16,12,'x'); // flank rear drum
    const postZ=front-.030,postBase=my+r-.004,supportH=Math.max(.020,top+.005-postBase);
    box('steel',.010,.034,.014,0,top+.020,postZ);
    box('steel',Math.min(.040,w*.28),supportH,.030,0,(top+.005+postBase)/2,postZ-.012);
    pair(s=>box('steel',.006,.034,.010,s*Math.min(.028,w*.17),top+.020,postZ));
    if(type===5){ // ladder rear sight leaf plus a left-flank quadrant arc
      box('steel',.024,.006,.080,0,top+.048,postZ+.055);
      box('accent',.010,.014,.010,0,top+.056,postZ+.020);
      box('steel',.008,.030,.026,-(w/2+.004),top+.010,-len*.24);
      box('steel',.008,.010,.090,-(w/2+.004),top+.024,-len*.30);
    }
  }
  // -- ejection / vent port on the right receiver face ------------------------
  zone('ejection');
  box('steel',.006,.050,.150,w/2+.004,portY,portZ);
  box('steel',.006,.012,.150,w/2+.004,portY+.038,portZ);
  box('steel',.006,.012,.150,w/2+.004,portY-.038,portZ);
  if(type===9){ // stamped receiver: reciprocating charging handle above the port
    box('accent',.020,.022,.060,w/2+.018,portY+.046,portZ-.070);
    tube('steel',.006,.130,w/2+.016,portY+.046,portZ+.015);
    box('glow',.010,.014,.030,w/2+.006,portY,portZ+.020);  // chamber port witness
  }else if([3,5,7,8].includes(type)){ // kinetic: brass deflector and carrier race
    box('steel',.014,.024,.034,w/2+.012,portY+.030,portZ-.062);
    box('dark',.010,.030,.095,w/2+.008,portY,portZ+.090);
  }else{ // energy: louvred vent instead of an ejection port
    slats('steel',3,.006,.010,.072,w/2+.005,portY-.012,portZ-.048,.030);
    if(spec.glow)box('glow',.004,.010,.100,w/2+.008,portY+.032,portZ+.020);
  }
  // -- feed identity: furniture on the authored feed mass ---------------------
  zone('feed');
  if(type===5){
    cone('dark',.157,.133,.060,0,feedY,-.345,12);
    cone('steel',.133,.157,.060,0,feedY,-.155,12);
    box('steel',.32,.026,.25,0,top+.025,-.25); // broad top strap
    pair(s=>box('dark',.025,.23,.065,s*.148,feedY+.045,-.25));
    // Revolver drum: hub caps on both faces, flutes proud of the drum radius,
    // an index ring and a charge window on the front face.
    tube('steel',.046,.014,0,feedY,-.128,12);
    tube('steel',.046,.014,0,feedY,-.372,12);
    for(let i=0;i<6;i++){const ang=i*Math.PI/3;
      box('steel',.038,.024,.170,Math.sin(ang)*.143,feedY+Math.cos(ang)*.143,-.25,[0,0,-ang]);}
    for(const ang of [Math.PI*0.72,Math.PI,Math.PI*1.28])
      box('accent',.012,.010,.012,Math.sin(ang)*(drumR+.010),feedY+Math.cos(ang)*(drumR+.010),-.372,[0,0,-ang]);
    box('glow',.026,.036,.014,0,feedY+.088,-.128);
    box('dark',.065,.080,.090,0,my-.08,-.25);
  }else if(type===7){
    // Ammunition box: belt window of three rounds on the front face, steel
    // frame, hinge and a latch on the outboard right face.
    pair(s=>box('steel',.012,.024,.150,feedX+s*(feedW/2+.005),feedY,-.25));
    for(let i=0;i<3;i++)tube('accent',.026,.030,feedX-.070+i*.052,feedY,-.335,12);
    box('steel',.180,.012,.026,feedX,feedY+.070,-.335);
    box('steel',.032,.040,.040,feedX+feedW/2+.015,feedY+.040,-.25);
    box('accent',.028,.040,.028,feedX-feedW/2-.012,feedY+.030,-.25);
  }else if(type===3){
    // Breech extractors below the twin bores and a shell carrier on the right.
    box('steel',.100,.020,.150,0,my-.078,-.22);
    for(let i=0;i<3;i++)tube('accent',.022,.070,w/2+.032,my+.010,-.13-i*.042,10);
    box('steel',.016,.066,.150,w/2+.014,my+.006,-.19);
    box('steel',.040,.014,.140,0,my-.098,-.20);
  }else if(type===1){
    // Breech latch below the tube and a loaded-cell window on the front face.
    box('dark',.085,.062,.150,0,my-h/2-.045,-.30);
    box('steel',.072,.016,.120,0,my-h/2-.020,-.30);
    box('accent',.060,.030,.080,0,my-h/2-.055,-.372);
    box('accent',.026,.022,.012,0,my-h/2-.048,-.395);
  }else{
    if(type===4)pair(s=>tube('steel',.020,.060,s*.028,feedY+.020,feedZ+.078,10)); // cell tubes
    if(type===9){
      box('dark',.138,.34,.15,0,feedY-.040,feedZ); // quad-stack mass, forward of trigger hand
      box('steel',.154,.024,.17,0,feedY-.216,feedZ);
      box('steel',.15,.026,.15,0,feedY+feedH/2-.030,feedZ);
    }
    if(type===2)box('dark',.145,.14,.27,0,feedY,-.32); // sled battery slab
    const magFloor=feedY-feedH/2;
    box('steel',feedW+.012,.020,.115,0,magFloor-.012,feedZ);          // floorplate
    pair(s=>slats('steel',3,.006,.060,.012,s*(feedW/2+.005),feedY-.010,feedZ-.030,.040));
    pair(s=>slats('accent',type===9?4:2,.005,.052,.010,s*(feedW/2+.004),feedY+.008,feedZ-.045,.046));
    box('dark',.024,.030,.020,0,feedY+feedH/2-.012,feedZ+.075);       // magazine catch
    if(spec.glow&&type!==8)box('glow',.010,.060,.012,feedW/2+.004,feedY-.030,feedZ+.005);
    if(type===6)pair(s=>box('steel',.010,.040,.090,s*(feedW/2+.003),feedY,feedZ-.060)); // capacitor plates
  }
  // -- heat zone: handguard shroud, vents and collars forward of the receiver -
  zone('heat');
  const guardLen=(front-mz)*.46,guardZ=front-guardLen/2;
  if(type===1){
    cone('dark',.144,.144,.66,0,my,-.29,12); // continuous launch tube
    ring('steel',.147,.012,0,my,front-.08,12,4);
    cone('steel',.136,.185,.15,0,my,.11,12); // rear venturi
    box('steel',.032,.150,.036,0,my-.012,front-.060);
  }else if(type===3){
    box('dark',.35,.042,.23,0,my-.075,front-.105); // wide fore-end
    box('steel',.038,.018,exposed+.12,0,my+r+.048,(mz+front)/2+.04);
    for(let i=0;i<4;i++)box('steel',.025,.035,.025,0,my+r+.026,front-.035-i*.095);
    box('accent',.025,.070,.025,w/2+.02,top+.014,-.13,[.45,0,0]);
    box('steel',.235,.016,.070,0,my+r+.012,heatZ0+.010);
    pair(s=>slats('steel',3,.010,.018,.040,s*.115,my+r+.012,heatZ0,-.058));
    box('glow',.022,.022,.070,0,my-.010,-.150);              // chamber witness ring
    box('accent',.012,.012,.030,0,my+r+.020,heatZ0-.055);    // brass rib bead
    pair(s=>box('steel',.014,.100,guardLen*.72,s*(w*.40),my-r-.040,guardZ));
  }else if(type===4){
    bulb(.125,.23,front-.025);
    bulb(.102,.18,front-.205);
    pair(s=>box('dark',.024,.055,.34,s*.115,my-.045,front-.10));
    pair(s=>tube('steel',.068,.034,s*(w/2+.015),my+.035,-.20,10,'x'));
  }else if(type===7){
    box('dark',.31,.105,.32,0,top-.030,-.30); // squared upper breech, above grip contact
    pair(s=>tube('steel',.070,.022,s*.16,my+.012,-.34,10,'x'));
    pair(s=>slats('steel',4,.010,.020,.030,s*(r+.020),my,heatZ0,-.046));
  }else if(type===8){
    box('dark',.085,.036,.49,0,bottom-.015,-.30); // continuous chassis spine
    pair(s=>{
      box('steel',.020,.032,.25,s*.070,my-r-.052,front-.14,[0,s*.10,0]);
      box('dark',.033,.052,.045,s*.082,my-r-.060,front-.24);
    }); // folded bipod, forward of supporting hand
    for(let i=0;i<3;i++)box('steel',.070,.016,.024,0,my-r*.85,heatZ0-i*.070);
    pair(s=>box('steel',.010,.070,guardLen*.60,s*(r+.008),my,guardZ));
  }else if(type===2||type===6){
    const railZ0=front+.04,railZ1=mz-(type===2?.065:.045);
    pair(s=>box('steel',type===2?.036:.030,type===2?.072:.055,railZ0-railZ1,s*(type===2?.085:.105),my,(railZ0+railZ1)/2));
    if(type===2)for(let i=0;i<3;i++)box('accent',(r+.020)*2,.026,.014,0,my+.006,railZ0-.020-i*.055);
    else {
      box('dark',.24,.035,.07,0,my+.045,mz+.15); // tuning bridge above bore
      for(let i=0;i<4;i++)box('steel',.14,.060,.026,0,top+.036,-.17-i*.065);
      for(let i=0;i<3;i++)box('accent',.14,.09,.024,0,my,.055+i*.040);
    }
  }else if(type===0){
    // Open rectangular perforations between long stringers and spaced hoops.
    pair(s=>box('dark',.014,.014,exposed-.04,s*.051,my+.040,(front+mz)/2));
    pair(s=>box('steel',.012,.014,exposed-.04,s*.051,my-.040,(front+mz)/2));
    for(let i=0;i<6;i++)ring('steel',.051,.007,0,my,front-.025-i*.060,8,4);
  }else{
    // Source handguard: flush side panels and a bottom plate on the barrel,
    // with the heat vents cut into the panels forward of the receiver.
    pair(s=>box('steel',.020,h*.80,guardLen,s*(w/2-.008),my-.004,guardZ));
    box('steel',w*.92,.022,guardLen,0,my-h*.42,guardZ);
    pair(s=>slats('steel',type===9?4:3,.012,.016,.028,s*(w/2+.002),my+.012,heatZ0,-.048));
    box('dark',w*.86,.026,.030,0,my-h*.42-.022,front-.014);
    if(spec.glow)box('glow',.006,.014,.060,0,my+r+.012,heatZ0);
  }
  // -- muzzle device ----------------------------------------------------------
  zone('muzzle');
  if(type===1){
    cone('steel',.198,.137,.15,0,my,mz+.065,12);
    ring('accent',.194,.012,0,my,mz-.010,12,4);
  }else if(type===2){
    pair(s=>{box('steel',.040,.082,.090,s*.085,my,mz-.025);
      box('accent',.042,.086,.020,s*.085,my,mz-.065);});
    box('dark',.15,.040,.27,0,top+.028,-.24); // boxy scope plinth
  }else if(type===3){
    box('steel',.37,.018,.040,0,my+r+.020,mz+.030);
    box('steel',.37,.018,.040,0,my-r-.020,mz+.030);
    pair(s=>ring('steel',r+.012,.010,s*.12,my,mz+.010,12,6));
    pair(s=>box('steel',.020,.020,.060,s*.12,my+r+.010,mz+.045));
  }else if(type===4){
    ring('accent',.105,.012,0,my,mz+.075,10,4);
    for(let i=0;i<3;i++){const a=i*Math.PI*2/3;
      box('steel',.026,.026,.17,Math.sin(a)*.105,my+Math.cos(a)*.105,mz+.025,[0,0,-a]);}
  }else if(type===5){
    ring('steel',r+.020,.014,0,my,mz+.020,14,6);
    ring('steel',r+.014,.012,0,my,mz+.070,14,6);
    cone('steel',r+.012,r+.012,.060,0,my,mz+.105,12);
    pair(s=>box('steel',.026,.012,.026,s*(r+.006),my,mz+.048)); // lateral ports
  }else if(type===6){
    pair(s=>box('accent',.048,.075,.060,s*.105,my,mz-.025));
    box('glow',.18,.012,.014,0,my+.065,mz+.15);
  }else if(type===7){
    cone('steel',.163,.105,.17,0,my,mz+.075,12);
    ring('dark',.158,.014,0,my,mz-.010,12,4);
    pair(s=>box('steel',.014,.040,.100,s*(r+.010),my,mz+.075));
    box('steel',.070,.014,.100,0,my+r+.010,mz+.075);
    box('steel',.070,.014,.100,0,my-r-.010,mz+.075);
  }else if(type===8){
    for(let i=0;i<3;i++)pair(s=>box('steel',.016,.060,.020,s*.038,my,mz+.030+i*.042));
    cone('steel',r+.012,r+.012,.050,0,my,mz+.120,12);
  }else if(type===9){
    cone('steel',r+.014,r+.014,.080,0,my,mz+.048,12);
    pair(s=>box('steel',.008,.020,.030,s*(r+.008),my,mz+.030));
    box('accent',.026,.012,.016,0,my+r+.018,mz+.008);
  }else{
    cone('steel',r+.012,r+.012,.070,0,my,mz+.045,12);
    pair(s=>box('steel',.008,.018,.034,s*(r+.006),my,mz+.040));
    ring('steel',r+.012,.010,0,my,mz+.014,12,6);
    if(spec.glow)box('glow',.012,.008,.040,0,my+r+.023,mz+.032);
  }
  // -- stock treatment, outside the source stock block -----------------------
  zone('stock');
  if(type===9){
    pair(s=>tube('steel',.009,stockLen+.13,s*(stockX+.016),my+.018,(stockLen+.13)/2));
    box('steel',.15,.080,.016,0,my-.014,stockLen+.13);
    pair(s=>box('steel',.024,.034,.022,s*(stockX+.010),my-.010,stockZ0+.030));
    box('accent',.020,.028,.030,stockX+.008,my+.010,stockLen*.55);
  }else if(type===1){
    box('dark',.170,.075,.040,0,my-h/2-.020,stockLen+.010);
    box('steel',.062,.024,.120,0,top+.014,.020);
    box('accent',.030,.020,.060,-.072,my-h/2-.078,stockLen-.030);
    box('steel',.026,.024,.040,-.098,my-h/2-.060,stockLen-.050);
  }else if(type===8){
    box('dark',.060,.030,.150,0,my+.026,stockLen*.42);
    box('steel',.070,.026,.030,0,my-.040,stockLen+.005);
    box('steel',.020,.085,.020,0,my-h/2-.030,stockLen-.015); // butt monopod
    box('accent',.026,.016,.060,.032,my+.032,stockLen*.20);
    box('steel',.020,.022,.020,0,stockY-stockH-.014,stockLen*.62);
  }else if(type===7){
    box('dark',Math.min(.120,w*.60),h*.90,.028,0,my-.040,stockLen+.005);
    pair(s=>tube('steel',.012,.120,s*(stockX+.012),my-.062,stockLen*.45));
    box('accent',.030,.030,.040,0,my-.120,stockLen*.20);
    box('steel',.024,.030,.030,stockX+.006,my+.020,stockLen*.30);
    pair(s=>slats('steel',2,.010,.072,.012,s*(stockX+.006),stockY-.010,stockLen*.34,.052)); // shell loops
    box('steel',.035,.075,.030,-.18,top+.020,-len*.80);
    box('steel',.035,.075,.030,-.18,top+.020,-len*.32);
    box('steel',.035,.024,.28,-.18,top+.065,-len*.56); // outboard carry handle
  }else if(type===4){
    pair(s=>box('steel',.012,.014,.130,s*(stockX+.008),my+.020,stockLen*.45));
    pair(s=>box('steel',.012,.014,.130,s*(stockX+.008),my-.075,stockLen*.45));
    box('dark',.030,.040,.070,0,stockY+stockH+.020,stockLen*.40);
    box('accent',.020,.024,.100,-(stockX+.006),my-.030,stockLen*.62);
  }else if(type===3){
    box('dark',Math.min(.130,w*.72),h*.90,.030,0,my-.030,stockLen+.006);
    pair(s=>tube('accent',.018,.056,s*(stockX+.012),my-.012,stockLen*.45));
    box('steel',.030,.026,.030,-(stockX+.008),my+.010,stockLen*.30);
  }else if(type===0){
    // Extend beyond the immutable source stock to expose a real open frame.
    pair(s=>box('steel',.015,.016,stockLen+.10,s*.075,my+.038,(stockLen+.10)/2));
    pair(s=>box('dark',.015,.016,stockLen+.10,s*.075,my-.092,(stockLen+.10)/2));
    box('dark',.16,.15,.025,0,my-.027,stockLen+.10);
  }else{
    if(type===5)box('steel',.030,.024,.060,-(stockX-.020),my+.012,stockLen*.28); // thumb rest
    box('dark',Math.min(.090,w*.52),.028,.150,0,stockY+stockH+.014,stockLen*.40);
    box('steel',.026,.024,.040,-(stockX+.010),my-.020,stockLen-.025);
    box('accent',.020,.020,.060,.020,stockY-stockH-.010,stockLen*.30);
    box('steel',Math.min(.110,w*.72),h*.34,.024,0,my-.030,stockLen-.004);
    box('steel',.020,.024,.020,-(stockX+.008),stockY-stockH+.006,stockLen*.60);
  }
  // -- grip treatment: the source hand pass presses the palm flat on the
  // receiver and the pistol grip, so added detail sits behind and below them.
  zone('grip');
  box('dark',.070,.022,.086,0,bottom-.186,-.030);          // grip floor cap
  box('steel',.022,.016,.022,.030,bottom-.196,-.030);      // lanyard loop
  const guardZ0=type===5?-.090:-.115,guardZ1=type===5?-.062:-.155;
  box('steel',.014,.020,.030,0,bottom-.090,guardZ0);       // trigger guard posts
  box('steel',.014,.020,.030,0,bottom-.090,guardZ1);
  box('steel',.014,.012,Math.abs(guardZ1-guardZ0)+.020,0,bottom-.108,(guardZ0+guardZ1)/2);
  box('accent',.016,.030,.018,0,bottom-.070,type===5?-.104:-.172); // trigger
  box('steel',.030,.022,.026,-(w*.30),bottom-.030,-.070);  // grip bolt
  // -- signature greeble -----------------------------------------------------
  zone('signature');
  if(type===0){
    for(let i=0;i<3;i++)box('accent',.016,.012+i*.010,.032,-(w/2+.005),my+h*.24+i*.014,-len*.36-i*.038);
    if(spec.glow)box('glow',.004,.014,.120,-(w/2+.004),my+.018,-len*.52);
  }else if(type===1){
    for(let i=0;i<3;i++)box('accent',.008,.030,.040,-(w/2+.004),my+.030,front-.08-i*.070);
    box('steel',.030,.026,.026,-(w/2+.016),my+.030,front-.06);
    // Emissive venturi dot ring on the rear face of the tube (channel 6).
    for(const angle of [0,Math.PI*2/3,Math.PI*4/3])
      box('glow',.014,.014,.006,Math.sin(angle)*(r+.030),my+Math.cos(angle)*(r+.030),.004);
  }else if(type===2){
    for(let i=0;i<3;i++)box('glow',.006,.028,.014,-(w/2+.004),my+.032,-len*.30-i*.050);
    box('accent',.026,.012,.150,w/2+.006,my-h*.10,-len*.40);
  }else if(type===3){
    for(let i=0;i<3;i++)box('accent',.026,.026,.016,-(w/2+.004),my-h*.06,-len*.30-i*.058);
    box('steel',.026,.030,.090,-(w/2+.010),my+.010,-len*.44);
  }else if(type===4){
    box('glow',.030,.036,.100,w/2+.005,my-h*.10,-len*.36);
    box('accent',.020,.014,.120,w/2+.007,my+.022,-len*.46);
  }else if(type===5){
    for(let i=0;i<3;i++)box('accent',.010,.012,.020,-(w/2+.004),my+h*.24,-len*.30-i*.060);
    if(spec.glow)box('glow',.010,.020,.030,-(w/2+.005),my-.030,-len*.62);
  }else if(type===6){
    for(let i=0;i<3;i++)box('steel',.024,.006,.040,w/2+.006,top+.020,-len*.24-i*.050);
    box('glow',.006,.014,.110,0,my+r+.010,front-exposed*.30);
    tube('steel',.030,.140,0,top+.038,-len*.30,12,'x');   // capacitor drum
    pair(s=>box('steel',.010,.030,.040,s*.028,top+.014,-len*.30));
  }else if(type===7){
    for(let i=0;i<2;i++)box('accent',.006,.036,.036,-(w/2+.004),my-h*.06,-len*.40-i*.080);
    box('steel',.030,.040,.100,w/2+.012,my-h*.08,-len*.30);
    tube('steel',.026,.020,w/2+.020,my+.020,-len*.26,12,'x');  // side range drum
    box('glow',.016,.016,.008,w/2+.012,my+.020,-len*.26);      // arming indicator
  }else if(type===8){
    tube('steel',.026,.016,w/2+.014,my+.020,-len*.30,12,'x');
    box('accent',.010,.030,.014,w/2+.030,my+.020,-len*.30);
    pair(s=>box('steel',.014,.040,.024,s*.050,my-r-.020,heatZ0+.060));
  }else{
    box('accent',.030,.024,.070,w/2+.020,my+h*.02,-len*.50);
    box('accent',.006,.012,.030,w/2+.024,my+h*.02,-len*.54);
    box('steel',.024,.030,.080,0,my-r-.024,heatZ0+.090);
  }
  const parts=[];
  for(const material of ['dark','accent','steel','glow'])for(const geometry of P[material])parts.push({material,geometry,zone:zoneOf.get(geometry)});
  return {parts,zones:Z,triangles:parts.reduce((n,p)=>n+triangles(p.geometry),0),identity:spec,
    materials:{dark:P.dark.length>0,accent:P.accent.length>0,steel:P.steel.length>0,glow:P.glow.length>0}};
}
// ---------------------------------------------------------------------------
async function main(){
  const root=new URL('../../',import.meta.url),out=new URL('godot/source_operators/generated/world_weapons/',root);
  await mkdir(out,{recursive:true});
  const sha=data=>createHash('sha256').update(data).digest('hex'),sources={};
  for(const file of ['game/view.mjs','game/rig.mjs','game/character-anim.mjs','game/weapon-models/chassis.mjs','game/model-geometry.mjs','game/data.mjs'])sources[file]=sha(await readFile(new URL(file,root)));
  const manifest={schema:1,sources,
    method:'Actual simpleWeaponModel construction at source scale plus the shared six-channel detail vocabulary (source beveledBox and placed-join vocabulary, merged per material). Grip coordinates are the chassis-derived fallback used verbatim by alignLivingCharacter in game/rig.mjs, unchanged from the pre-detail export.',
    detailVocabulary:{trim:DETAIL_STEEL,cavity:DETAIL_GLOW_ALBEDO,channels:['receiver','feed','muzzle','stock','sight','accent'],roles:{trim:'detail-trim machined steel',glow:'per-weapon emissive accent',dark:'source polymer',accent:'source weapon colour'},signature:'accent identity plus signature greeble motif',targetTriangles:[1200,2500],maxBatches:4,authority:'port/native-weapon-detail/WEAPON_IDENTITY.md'},
    weapons:[]};
  for(let type=0;type<WEAPONS.length;type++){
    const source=simpleWeaponModel(type,new ModelAssets());source.updateMatrixWorld(true);
    const scene=new T.Scene(),weapon=new T.Group();weapon.name='WorldWeapon';scene.add(weapon);
    const buckets=new Map();let triangles=0;
    source.traverseVisible(node=>{
      if(!node.isMesh)return;
      if(!buckets.has(node.material))buckets.set(node.material,[]);
      let geo=node.geometry.clone().applyMatrix4(node.matrixWorld);
      if(geo.index)geo=geo.toNonIndexed();
      for(const attr of Object.keys(geo.attributes))if(!['position','normal','uv'].includes(attr))geo.deleteAttribute(attr);
      triangles+=geo.attributes.position.count/3;buckets.get(node.material).push(geo);
    });
    // The source body is two materials: the dark receiver polymer and the
    // emissive weapon-colour accent. Detail joins those two batches and adds at
    // most a machined steel batch and an emissive core batch.
    const sourceMaterials=[...buckets.keys()];
    const accentMaterial=sourceMaterials.find(m=>m.emissive&&m.emissive.getHex()!==0);
    const darkMaterial=sourceMaterials.find(m=>m!==accentMaterial);
    if(sourceMaterials.length!==2||!accentMaterial||!darkMaterial)throw new Error(`weapon ${type}: unexpected source materials`);
    const kit=detailKit(type);
    triangles+=kit.triangles;
    const steelMaterial=new T.MeshStandardMaterial({name:'WorldDetailTrim',color:DETAIL_STEEL,metalness:.68,roughness:.32});
    const glowMaterial=new T.MeshStandardMaterial({name:'WorldDetailGlow',color:DETAIL_GLOW_ALBEDO,emissive:new T.Color(WEAPONS[type].color),emissiveIntensity:1.8,metalness:.20,roughness:.30});
    const materials={dark:darkMaterial,accent:accentMaterial,steel:steelMaterial,glow:glowMaterial};
    for(const {material,geometry} of kit.parts){
      const owner=materials[material];
      if(!buckets.has(owner))buckets.set(owner,[]);
      buckets.get(owner).push(geometry);
    }
    let serial=0;const bounds=new T.Box3();
    for(const [material,geometries] of buckets){
      const mat=material.clone();mat.userData={};mat.name=`WorldMaterial${serial}`;
      const flat=geometries.map(geometry=>geometry.index?geometry.toNonIndexed():geometry);
      const geometry=mergeVertices(mergeGeometries(flat),1e-7);
      geometry.computeBoundingBox();bounds.union(geometry.boundingBox);
      const mesh=new T.Mesh(geometry,mat);mesh.name=`WorldBatch${serial++}`;weapon.add(mesh);
    }
    const [width,height,length,,y]=chassisFor(type);
    const anchors={Muzzle:source.userData.muzzle.position.toArray(),WeaponGripLeft:[-width/2-.025,y-height/2-.015,-length*.48],WeaponGripRight:[0,y-height/2-.08,-.035]};
    for(const [name,position] of Object.entries(anchors)){const node=new T.Group();node.name=name;node.position.fromArray(position);weapon.add(node);}
    const bytes=Buffer.from(await new GLTFExporter().parseAsync(scene,{binary:true,onlyVisible:true}));
    const file=`weapon-${type}.glb`;await writeFile(new URL(file,out),bytes);
    manifest.weapons.push({id:type,name:WEAPONS[type].name,file,sha256:sha(bytes),bytes:bytes.length,triangles,draws:buckets.size,anchors,bounds:[bounds.min.toArray(),bounds.max.toArray()],
      detail:{triangles:kit.triangles,zones:kit.zones,materials:kit.materials,identity:kit.identity}});
  }
  const states={carry:{time:.4},walk:{time:.4,phase:.8,speedNorm:.65,forward:1},aim:{ads:1,focusYaw:.4,focusPitch:-.3},crouch:{crouch:1,ads:.8,focusYaw:-.3,focusPitch:.3},reload:{reload:1,ads:.4}};
  const fixtures={states,operators:[]};
  for(const {id} of CHARACTERS){
    const model=robotModel(id,new ModelAssets()),d=model.userData,j=d.joints,entries=[];
    for(let type=0;type<WEAPONS.length;type++){
      d.weapon.removeFromParent();d.weapon=simpleWeaponModel(type,new ModelAssets());d.gunAnchor.add(d.weapon);
      for(const [name,state] of Object.entries(states)){
        d.rig.reset();d.rig.apply(characterPose({...state,contactGait:true}));
        d.gunAnchor.rotation.set(-(state.focusPitch??0),state.focusYaw??0,0);
        const result=alignLivingCharacter(model,{grounded:false});model.updateMatrixWorld(true);
        const joints=Object.fromEntries(['armUpperL','armUpperR','forearmL','forearmR','handL','handR'].map(key=>[key,{quaternion:j[key].quaternion.toArray(),world:j[key].matrixWorld.toArray()}]));
        const grips=Object.fromEntries(['L','R'].map(side=>[side,d.characterRefinement[`grip${side}`].getWorldPosition(new T.Vector3()).toArray()]));
        entries.push({type,state:name,joints,grips,hands:result.hands});
      }
    }
    fixtures.operators.push({id,entries});
  }
  await writeFile(new URL('manifest.json',out),JSON.stringify(manifest,null,2)+'\n');
  await writeFile(new URL('catalog.gd',out),'extends RefCounted\n# Actual source simpleWeaponModel plus the shared six-channel world detail kit; source rig chassis contacts, no rescaling.\nconst WEAPONS = '+JSON.stringify(manifest.weapons,null,'\t')+'\n');
  await writeFile(new URL('godot/tests/source_operators/source_grips.json',root),JSON.stringify(fixtures)+'\n');
  console.log(JSON.stringify(manifest.weapons.map(({id,bytes,triangles,draws,detail})=>({id,bytes,triangles,draws,detailTriangles:detail.triangles}))));
  console.log('Source grip cases:',fixtures.operators.reduce((n,o)=>n+o.entries.length,0),'max source contact error:',Math.max(...fixtures.operators.flatMap(o=>o.entries.flatMap(e=>e.hands.map(h=>h.error)))));
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href)await main();
