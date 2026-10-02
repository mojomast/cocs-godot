// Metrics for an ACTUALLY captured native PCM WAV, never listening acceptance.
import fs from 'node:fs';
const file=process.argv[2];
if(!file) throw Error('Usage: node pcm_metrics.mjs recorded.wav');
const bytes=fs.readFileSync(file);
if(bytes.toString('ascii',0,4)!=='RIFF'||bytes.toString('ascii',8,12)!=='WAVE') throw Error('Not WAV');
let format,data;
for(let at=12;at+8<=bytes.length;) {
 const id=bytes.toString('ascii',at,at+4),n=bytes.readUInt32LE(at+4);
 const chunk=bytes.subarray(at+8,at+8+n);
 if(chunk.length!==n)throw Error('Truncated chunk');
 if(id==='fmt ')format=chunk;if(id==='data')data=chunk;
 at+=8+n+(n%2);
}
if(!format||!data||format.readUInt16LE(0)!==1||format.readUInt16LE(14)!==16)throw Error('Expected PCM16');
const channels=format.readUInt16LE(2),rate=format.readUInt32LE(4);
let peak=0,energy=0,clipped=0,nonzero=0;
for(let i=0;i<data.length;i+=2) {
 const v=data.readInt16LE(i);peak=Math.max(peak,Math.abs(v));energy+=(v/32768)**2;
 if(Math.abs(v)>=32767)clipped++;if(v)nonzero++;
}
console.log(JSON.stringify({file,channels,rate,seconds:data.length/(2*channels*rate),peak:peak/32768,rms:Math.sqrt(energy/(data.length/2)),clipped,nonzero,humanListening:'OPEN'},null,2));
if(!nonzero||clipped)process.exitCode=1;
