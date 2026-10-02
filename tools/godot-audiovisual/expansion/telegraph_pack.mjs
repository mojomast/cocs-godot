// Original deterministic PCM realization of the repository's procedural cues.
// No recordings, external assets, normalization, or source modifications.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
export const source = fs.readFileSync(path.join(root, 'game/feedback.mjs'), 'utf8');
function table(name) {
  const text = source.match(new RegExp(`export const ${name}=Object.freeze\\(\\{[\\s\\S]*?\\n\\}\\);`))?.[0];
  if (!text) throw Error(`Missing source table ${name}`);
  return JSON.parse(JSON.stringify(vm.runInNewContext(`const objective=(notes,step,length,gain,shimmer=false)=>({notes,step,length,gain,shimmer});${text.replace('export ', '')};${name}`)));
}
export const cues = table('TELEGRAPH_CUES');
export const themes = table('MODE_THEMES');
export const rate = 22050;
export function envelope(t, duration, gain, attack=.003) {
  if (t < 0 || t >= duration+.03) return 0;
  if (t < attack) return .0001+(gain-.0001)*t/attack;
  if (t >= duration) return .0001;
  return gain*Math.pow(.0001/gain,(t-attack)/(duration-attack));
}
export function render(cue, hz) {
  const length=cue.length+(cue.notes.length-1)*cue.step+.12;
  const pcm=new Float64Array(Math.ceil(length*rate));
  for (let n=0;n<cue.notes.length;n++) {
    const f=Math.max(20,hz*2**(cue.notes[n]/12)), end=Math.max(20,hz*2**(cue.notes[n]/12)*1.42);
    const k=Math.log(end/f)/cue.length;
    for(let i=Math.ceil(n*cue.step*rate);i<pcm.length;i++) {
      const t=i/rate-n*cue.step;
      const phase=t<=cue.length ? f*Math.expm1(k*t)/k : f*Math.expm1(k*cue.length)/k+end*(t-cue.length);
      pcm[i]+=2/Math.PI*Math.asin(Math.sin(2*Math.PI*phase))*envelope(t,cue.length,cue.gain);
    }
  }
  if(cue.shimmer) {
    // Source _noise: highpass 3000 -> 1400 Hz, Q=.6, .24s, .015s attack.
    // Fixed LCG replaces the browser's random noise buffer for reproducibility.
    let seed=0x54454c45,x1=0,x2=0,y1=0,y2=0;
    for(let i=Math.ceil(.01*rate);i<pcm.length;i++) {
      const t=i/rate-.01;
      if(t>=.27) break;
      seed=(Math.imul(seed,1664525)+1013904223)>>>0;
      const x=seed/2147483648-1;
      const f=3000*(1400/3000)**Math.min(1,t/.24), w=2*Math.PI*f/rate;
      const c=Math.cos(w), a=Math.sin(w)/(2*.6), a0=1+a;
      const y=((1+c)/2*x-(1+c)*x1+(1+c)/2*x2+2*c*y1-(1-a)*y2)/a0;
      x2=x1;x1=x;y2=y1;y1=y;
      pcm[i]+=y*envelope(t,.24,.05,.015);
    }
  }
  return pcm;
}
export function wave(pcm) {
  const b=Buffer.alloc(44+pcm.length*2);
  b.write('RIFF');b.writeUInt32LE(b.length-8,4);b.write('WAVEfmt ',8);b.writeUInt32LE(16,16);
  b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);b.writeUInt32LE(rate,24);b.writeUInt32LE(rate*2,28);
  b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(pcm.length*2,40);
  for(let i=0;i<pcm.length;i++) {
    if(!Number.isFinite(pcm[i])||Math.abs(pcm[i])>=1) throw Error('Invalid/clipping PCM');
    b.writeInt16LE(Math.trunc(pcm[i]*32767),44+i*2);
  }
  return b;
}
export function generate(check=false) {
  const dir=path.join(root,'godot/audio/telegraphs');
  if(!check) fs.mkdirSync(dir,{recursive:true});
  const inventory=[];
  for(const hz of [...new Set(Object.values(themes).map(x=>x.root))].sort((a,b)=>a-b)) {
    for(const [kind,cue] of Object.entries(cues)) {
      const pcm=render(cue,hz), data=wave(pcm), file=`${hz}-${kind}.wav`;
      if(check) { if(!fs.readFileSync(path.join(dir,file)).equals(data)) throw Error(`PCM drift ${file}`); }
      else fs.writeFileSync(path.join(dir,file),data);
      inventory.push({file,frames:pcm.length,peak:Math.max(...pcm.map(Math.abs)),sha256:crypto.createHash('sha256').update(data).digest('hex')});
    }
  }
  const manifest=JSON.stringify({source:'game/feedback.mjs TELEGRAPH_CUES, MODE_THEMES, _beat, _tone, _noise',rate,cues,roots:Object.fromEntries(Object.entries(themes).map(([k,v])=>[k,v.root])),inventory},null,2)+'\n';
  if(check) {if(fs.readFileSync(path.join(dir,'manifest.json'),'utf8')!==manifest) throw Error('Manifest drift');}
  else fs.writeFileSync(path.join(dir,'manifest.json'),manifest);
  return {files:inventory.length,bytes:inventory.reduce((n,x)=>n+44+x.frames*2,0),peak:Math.max(...inventory.map(x=>x.peak))};
}
if(process.argv[1]===fileURLToPath(import.meta.url)) console.log(generate(process.argv.includes('--check')));
