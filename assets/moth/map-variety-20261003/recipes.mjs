// Authored periodic structural seeds. No old asset is sampled.
import { tileFbmXY } from './tool.mjs';
export const recipes = [
  ['aggregate', 'Helix,Vesper', 'noise', [0.22,0.225,0.20], [0.34,0.32,0.27], 0.85, 4, 0.035, 3, 19],
  ['cast-seams', 'Gravemill,Abyssal', 'cast', [0.15,0.17,0.17], [0.25,0.255,0.23], 0.78, 4, 0.045, 2, 9],
  ['terracotta', 'Helix,Vesper', 'brick', [0.24,0.10,0.055], [0.36,0.20,0.115], 0.82, 2, 0.018, 4, 17],
  ['lime-plaster', 'Helix,Vesper', 'plaster', [0.35,0.34,0.28], [0.47,0.455,0.36], 0.86, 3, 0.012, 5, 25],
  ['oxidized-iron', 'Gravemill,Abyssal', 'pits', [0.07,0.085,0.09], [0.22,0.10,0.045], 0.72, 2, 0.014, 3, 29],
  ['copper-patina', 'Helix,Parallax', 'cells', [0.15,0.105,0.065], [0.08,0.23,0.18], 0.56, 2, 0.008, 4, 21],
  ['ceramic-enamel', 'Helix,Parallax', 'ceramic', [0.25,0.30,0.28], [0.38,0.40,0.34], 0.30, 2, 0.014, 4, 24],
  ['anodized-brush', 'Parallax,Vesper', 'brush', [0.105,0.14,0.17], [0.17,0.20,0.23], 0.39, 1, 0.002, 2, 48],
  ['iron-grate', 'Gravemill,Abyssal', 'grate', [0.04,0.05,0.055], [0.115,0.12,0.115], 0.68, 1, 0.018, 8, 31],
  ['wet-soot', 'Gravemill,Abyssal', 'streak', [0.025,0.03,0.032], [0.08,0.09,0.085], 0.36, 3, 0.008, 3, 22],
  ['salt-limestone', 'Stormglass,Vesper', 'salt', [0.29,0.285,0.24], [0.43,0.42,0.35], 0.88, 4, 0.055, 3, 18],
  ['basalt-strata', 'Stormglass,Abyssal', 'strata', [0.065,0.085,0.09], [0.15,0.17,0.17], 0.85, 4, 0.09, 5, 23],
  ['dune-sand', 'Stormglass', 'dune', [0.26,0.22,0.155], [0.39,0.33,0.235], 0.90, 4, 0.05, 6, 36],
  ['deep-silt', 'Abyssal', 'silt', [0.065,0.09,0.085], [0.13,0.15,0.12], 0.79, 4, 0.025, 3, 27],
  ['road-gravel', 'Stormglass,Vesper', 'gravel', [0.08,0.09,0.095], [0.17,0.18,0.17], 0.91, 4, 0.04, 12, 41],
  ['moss-lichen', 'Helix,Stormglass', 'lichen', [0.055,0.085,0.03], [0.17,0.21,0.07], 0.91, 2, 0.025, 7, 26],
  ['bark-fibers', 'Helix', 'bark', [0.085,0.055,0.035], [0.20,0.13,0.075], 0.92, 2, 0.045, 6, 32],
  ['leaf-veins', 'Helix', 'leaf', [0.035,0.085,0.025], [0.115,0.19,0.05], 0.66, 1, 0.004, 4, 16],
  ['frosted-glass', 'Parallax,Stormglass', 'frost', [0.19,0.255,0.28], [0.28,0.34,0.355], 0.45, 2, 0.003, 7, 37],
  ['prismatic-etch', 'Parallax', 'etch', [0.10,0.13,0.17], [0.18,0.23,0.26], 0.34, 2, 0.005, 5, 30],
  ['viaduct-asphalt', 'Vesper,Stormglass', 'asphalt', [0.035,0.04,0.045], [0.09,0.10,0.105], 0.85, 4, 0.013, 8, 47],
  ['ribbed-steel', 'Gravemill,Abyssal', 'ribs', [0.085,0.105,0.11], [0.16,0.18,0.175], 0.56, 2, 0.025, 8, 20],
  ['trim-wear', 'Helix,Gravemill,Parallax,Vesper,Abyssal,Stormglass', 'trim', [0.10,0.12,0.13], [0.22,0.24,0.23], 0.64, 2, 0.014, 4, 28],
  ['decal-stencil', 'Helix,Gravemill,Parallax,Vesper,Abyssal,Stormglass', 'stencil', [0.18,0.19,0.17], [0.34,0.35,0.29], 0.76, 2, 0.002, 4, 15],
  ['slate-shingle', 'Vesper,Stormglass', 'slate', [0.06,0.085,0.105], [0.15,0.175,0.19], 0.78, 2, 0.016, 4, 28],
  ['cobble-sett', 'Vesper,Stormglass', 'cobble', [0.12,0.13,0.12], [0.27,0.26,0.22], 0.84, 2, 0.035, 4, 19],
  ['fern-frond', 'Helix', 'fern', [0.025,0.06,0.018], [0.11,0.19,0.055], 0.65, 1, 0.002, 4, 24],
  ['sea-flow', 'Stormglass,Abyssal', 'wave', [0.025,0.075,0.085], [0.055,0.14,0.15], 0.22, 4, 0.016, 4, 17],
  ['timber-weather', 'Vesper,Stormglass', 'timber', [0.10,0.08,0.055], [0.23,0.195,0.135], 0.83, 2, 0.013, 4, 25],
  ['quay-waterline', 'Vesper,Abyssal,Stormglass', 'waterline', [0.07,0.085,0.07], [0.24,0.25,0.20], 0.60, 4, 0.015, 3, 20],
].map(([id,maps,pattern,low,high,roughness,tileMeters,heightMeters,macro,micro],i)=>({id,maps:maps.split(','),pattern,low,high,roughness,tileMeters,heightMeters,macro,micro,seed:61003+i*101}));
const fract=x=>x-Math.floor(x);
const ridge=x=>Math.abs(Math.sin(Math.PI*x));
const smooth=(a,b,x)=>{const t=Math.max(0,Math.min(1,(x-a)/(b-a)));return t*t*(3-2*t);};
export function seedFields(r,n=128) {
  const height=[],mask=[];
  for(let y=0;y<n;y++){const h=[],m=[];for(let x=0;x<n;x++){
    const u=x/n,v=y/n,k=r.macro;
    const a=tileFbmXY(u,v,r.seed,k,k,3), b=tileFbmXY(u,v,r.seed+31,r.micro,r.micro,2);
    const flow=tileFbmXY(u,v,r.seed+71,12,2,3);
    let shape=a, wear=smooth(.40,.65,a), joint=0;
    switch(r.pattern){
      case 'cast':joint=1-smooth(.025,.07,Math.min(ridge(u*2),ridge(v*2)));shape=.65*a+.35*flow-.40*joint;break;
      case 'brick':joint=1-smooth(.025,.09,Math.min(ridge(v*8),ridge(u*4+(Math.floor(v*8)%2)*.5)));shape=.65+.2*a-.55*joint;break;
      case 'ceramic':joint=1-smooth(.02,.08,Math.min(ridge(u*4),ridge(v*4)));shape=.65+.12*a-.55*joint;break;
      case 'brush':shape=.45*tileFbmXY(u,v,r.seed,2,48,2)+.30*ridge(v*48)+.25*a;break;
      case 'grate':shape=smooth(.6,.9,Math.max(ridge(u*8),ridge(v*8)));wear=shape;break;
      case 'streak':shape=.85*flow+.15*b;wear=smooth(.35,.7,flow);break;
      case 'strata':shape=.7*ridge(v*5+.18*Math.sin(u*Math.PI*2))+.3*a;break;
      case 'dune':shape=.75*ridge(v*6+.22*Math.sin(u*Math.PI*2))+.25*b;break;
      case 'bark':shape=.55*ridge(u*6+.15*Math.sin(v*Math.PI*4))+.45*flow;break;
      case 'leaf':shape=.7*(1-smooth(.06,.3,ridge(u*4-v*8)))+.3*a;break;
      case 'etch':shape=.4*(1-smooth(.02,.08,ridge(u*5+v*5)))+.4*(1-smooth(.02,.08,ridge(u*5-v*5)))+.2*a;break;
      case 'ribs':shape=.75*ridge(u*8)+.25*flow;break;
      case 'trim':shape=.7*smooth(.2,.35,ridge(v*4))+.3*flow;wear=(1-smooth(.15,.45,ridge(v*4)))*(.4+.6*a);break;
      case 'stencil':shape=(smooth(.15,.19,fract(u*4))*(1-smooth(.7,.74,fract(u*4))))*(smooth(.15,.19,fract(v*4))*(1-smooth(.7,.74,fract(v*4))));wear=shape*(.5+.5*a);break;
      case 'slate':joint=1-smooth(.015,.045,Math.min(ridge(v*4),ridge(u*4+(Math.floor(v*4)%2)*.5)));shape=.45+.25*fract(v*4)+.22*flow-.40*joint;break;
      case 'cobble':shape=.7*smooth(.05,.45,Math.min(ridge(v*6),ridge(u*4+(Math.floor(v*6)%2)*.5)))+.3*a;break;
      case 'fern':{const xx=(u-.5), yy=(v-.5); const stem=1-smooth(.008,.025,Math.abs(xx));const leaf=(1-smooth(.035,.065,ridge(v*12-Math.abs(xx)*5)))*(1-smooth(.12,.34,Math.abs(xx)/(1.05-Math.abs(yy)*1.5)));shape=Math.max(stem,leaf)*(1-smooth(.36,.47,Math.abs(yy)));wear=shape;break;}
      case 'wave':shape=.45*ridge(u*3+v*4+.1*Math.sin(v*2*Math.PI))+.35*ridge(v*7-u*2)+.2*a;break;
      case 'timber':joint=1-smooth(.02,.06,ridge(u*4));shape=.5*flow+.35*ridge(u*24+.12*Math.sin(v*2*Math.PI))+.15*a-.3*joint;break;
      case 'waterline':shape=.5*a+.5*smooth(.15,.65,ridge(v*2)+.1*flow);wear=smooth(.35,.65,ridge(v*2)+.25*a);break;
      case 'pits':shape=.8*smooth(.32,.67,a)+.2*b;break;
      case 'cells':shape=.6*a+.4*smooth(.35,.60,b);break;
      case 'salt':shape=.55*a+.45*smooth(.35,.6,b);break;
      case 'gravel':shape=.25*a+.75*smooth(.25,.75,b);break;
      case 'lichen':shape=.6*smooth(.36,.6,a)+.4*b;break;
      case 'frost':shape=.3*a+.7*b;break;
      case 'asphalt':shape=.15*a+.85*b;break;
      case 'silt':shape=.75*a+.25*flow;break;
      case 'plaster':shape=.7*a+.3*b;break;
    }
    h.push(Number(Math.max(.025,Math.min(.975,.12+.70*shape+.12*(b-.5))).toFixed(7)));
    m.push(Number(Math.max(0,Math.min(1,joint?Math.max(wear*.5,joint):wear)).toFixed(7)));
  }height.push(h);mask.push(m);}
  return {height,mask};
}
