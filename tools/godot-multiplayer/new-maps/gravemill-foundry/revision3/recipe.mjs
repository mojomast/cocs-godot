// Staged authority. Never written into the accepted runtime by this module.
import {recipe as checkpoint,height,ID,SEED} from '../recipe.mjs';
export {ID,SEED};
export function recipe(){
 const m=checkpoint();
 const v=(x,q,y)=>[x,y,q+.14*x];
 const face=(id,p,material='soot')=>{for(let i=1;i<p.length-1;i++)m.terrain.walls.push({id,material,vertices:[p[0],p[i],p[i+1]]});};
 const roof=(id,p,material='copper')=>m.terrain.surfaces.push({id,material,walkable:false,vertices:p,triangles:Array.from({length:p.length-2},(_,i)=>[0,i+1,i+2])});
 const box=(id,x,q,w,d,b,t,material='soot')=>{const p=[v(x-w/2,q-d/2,b),v(x+w/2,q-d/2,b),v(x+w/2,q+d/2,b),v(x-w/2,q+d/2,b)];for(let i=0;i<4;i++)face(id,[p[i],p[(i+1)%4],[p[(i+1)%4][0],t,p[(i+1)%4][2]],[p[i][0],t,p[i][2]]],material);roof(id+'-cap',p.map(p=>[p[0],t,p[2]]),material);};
 const wall=(id,a,b,low,high,material='soot')=>face(id,[v(...a,low),v(...b,low),v(...b,high),v(...a,high)],material);
 // Crusher HOUSE: drums live inside deep bays, with an east-west covered
 // freight threshold and two full-height maintenance aisles around the beds.
 for(const x of [-100,-38]){
  wall('crusher-house-end-north',[x,-25],[x,23],0,26);
  wall('crusher-house-end-south',[x,-52],[x,-49],0,16);
  wall('crusher-house-truck-lintel',[x,-49],[x,-25],12,22);
 }
 wall('crusher-house-back',[-100,23],[-38,23],0,27);
 wall('crusher-house-front',[-100,-52],[-38,-52],0,14);
 const saw=[[-52,17],[-25,25],[-15,22],[2,32],[9,28],[23,30]];
 for(let i=1;i<saw.length;i++)roof('crusher-process-roof-'+i,[v(-100,...saw[i-1]),v(-38,...saw[i-1]),v(-38,...saw[i]),v(-100,...saw[i])]);
 // Receiving throat / chute volumes descend into the drum islands, never aisles.
 for(const [x,q] of [[-72,-7],[-48,0]]){
  roof('receiving-hopper-'+x,[v(x-7,q-5,24),v(x+7,q-5,24),v(x+4,q-3,19),v(x-4,q-3,19)],'brass');
  roof('receiving-chute-'+x,[v(x-4,q-3,19),v(x+4,q-3,19),v(x+4,q+3,16),v(x-4,q+3,16)],'ore');
 }
 // Middle checkpoint becomes a covered transfer passage, with broad diagonal
 // entries and a separate uphill flank instead of an exposed central pad.
 roof('transfer-fold-west',[v(-25,-83,13),v(28,-72,19),v(28,-43,19),v(-25,-38,13)]);
 wall('transfer-south-cut',[-25,-83],[28,-72],0,9);
 wall('transfer-north-cut',[-25,-38],[28,-43],0,8);
 // Cooling: close the nave's shell, retaining the tested windows and central
 // north/south openings. Deep internal machinery alcoves face side aisles.
 for(const side of [-1,1]){
  const q=36+side*10;
  for(const [a,b] of [[-92,-90.5],[-76.3,-70],[-62,-55.7],[-41.5,-40]])wall('cooling-enclosure',[a,q],[b,q],12,20);
  for(const x of [-84,-48])box('cooling-recess-bank',x,36+side*5.5,6,2.2,12,16,'soot');
 }
 // Assay is now a steep asymmetric roof/control block, not the second vault.
 m.terrain.surfaces=m.terrain.surfaces.filter(s=>!s.id.startsWith('assay-vault-vault'));
 roof('assay-long-slate-roof',[v(40,26,20),v(92,26,20),v(92,40,31),v(40,40,31)],'soot');
 roof('assay-short-rust-roof',[v(40,40,31),v(92,40,31),v(92,46,21),v(40,46,21)],'brass');
 for(const x of [40,92])face('assay-gable',[v(x,26,20),v(x,40,31),v(x,46,21)],'mineral');
 for(const side of [-1,1])for(const [a,b] of [[40,41.5],[55.7,62],[70,76.3],[90.5,92]])wall('assay-outer-wall',[a,36+side*10],[b,36+side*10],12,21,'mineral');
 for(const x of [57,77])for(const [a,b] of [[26,32],[40,46]])wall('assay-room-divider',[x,a],[x,b],12,21,'mineral');
 // Public inspection glazing apertures are empty geometry, with real sills
 // and lintels. Continuous central corridor retains both end portals.
 for(const q of [32,40])for(const [a,b] of [[42,55],[59,75],[79,90]]){
  wall('assay-inspection-sill',[a,q],[b,q],12,13,'mineral');
  wall('assay-inspection-lintel',[a,q],[b,q],16,21,'soot');
 }
 // Furnace DISTRICT: massed brick kiln arcade and shed frame surrounding the
 // existing towers, with large openings aligned to the service apron.
 for(const x of [44,80,104])box('kiln-buttress',x,-19,3,5,0,18,'ore');
 for(const [a,b] of [[44,80],[80,104]]){
  for(let i=0;i<8;i++){const t=i/8,u=(i+1)/8,ya=8+7*Math.sin(t*Math.PI),yb=8+7*Math.sin(u*Math.PI);face('kiln-arch',[v(a+(b-a)*t,-19,ya),v(a+(b-a)*u,-19,yb),v(a+(b-a)*u,-19,21),v(a+(b-a)*t,-19,21)],'ore');}
 }
 roof('kiln-loading-canopy',[v(42,-29,14),v(105,-29,14),v(105,-17,23),v(42,-17,23)],'soot');
 for(const x of [48,74,100])box('loading-shed-column',x,-27,1.2,1.2,0,14,'ore');
 wall('kiln-service-back',[43,22],[104,22],0,23,'ore');
 for(const x of [43,104])wall('kiln-service-side',[x,-16],[x,22],0,23,'ore');
 // Unequal stratified foundation masses, embedded around existing rock islands;
 // no repetitive perimeter triangle-fence additions.
 for(const [x,q,w,d,h] of [[-138,0,10,17,14],[132,4,10,17,17],[-14,5,10,17,15],[14,77,10,15,13]])for(let j=0;j<3;j++){
  const y=height(x,q+.14*x);box('foundation-bed-'+x+'-'+j,x+j*.4,q,w-j*2,d-j*2,y+j*h/3,y+(j+1)*h/3,j===1?'ore':'mineral');
 }
 const addRoute=(id,points)=>{const p=points.map(([x,q])=>[x,q+.14*x]);m.routes.push({id,width:3,points:p});for(let i=1;i<p.length;i++){const a=p[i-1],b=p[i],n=Math.ceil(Math.hypot(a[0]-b[0],a[1]-b[1])/2);for(let j=0;j<=n;j++)m.navNodes.push({x:a[0]+(b[0]-a[0])*j/n,z:a[1]+(b[1]-a[1])*j/n});}};
 addRoute('crusher-covered-aisle',[[-112,-38],[-94,-38],[-88,-20],[-88,17],[-94,17],[-94,-38]]);
 addRoute('diagonal-service-cut',[[-34,-38],[-8,-30],[20,-26],[34,-38]]);
 m.art.revision3={status:'staged-source-only',districts:['crusher house','closed cooling works','asymmetric assay control rooms','brick kiln district'],noOverlappingWalkableDecks:true};
 return m;
}
