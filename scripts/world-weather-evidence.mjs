import fs from 'node:fs';
import assert from 'node:assert/strict';
import sharp from 'sharp';
const root = process.argv[2];
if (!root) throw Error('Pass evidence root');
const summaries = [];
for (const [folder, expected] of [['nine-worlds',27],['styles-final',24]]) {
  const rows = JSON.parse(fs.readFileSync(`${root}/${folder}/manifest.json`));
  assert.equal(rows.length, expected);
  const ids=rows.filter(x=>x.phase==='before').map(x=>x.map);
  const perSheet=folder==='nine-worlds'?3:2;
  for(let start=0;start<ids.length;start+=perSheet) {
    const composites=[],count=Math.min(perSheet,ids.length-start);
    for(let r=0;r<count;r++) for(let c=0;c<3;c++) {
      const phase=['before','wet-only','weather'][c],id=ids[start+r];
      composites.push({input:await sharp(`${root}/${folder}/${id}-${phase}.png`).resize(480,300).toBuffer(),left:c*480,top:r*324+24});
      composites.push({input:Buffer.from(`<svg width="480" height="24"><text x="5" y="17" fill="white" font-size="14">${id} ${phase}</text></svg>`),left:c*480,top:r*324});
    }
    await sharp({create:{width:1440,height:count*324,channels:3,background:'#18212a'}}).composite(composites).jpeg().toFile(`${root}/${folder}/review-${start/perSheet+1}.jpg`);
  }
  for (let i=0;i<rows.length;i+=3) {
    const group=rows.slice(i,i+3), first=group[0];
    assert(group.every(x=>!x.capped && x.draw_calls===first.draw_calls));
    const decoded=[];
    for (const row of group) decoded.push(await sharp(`${root}/${folder}/${row.map}-${row.phase}.png`).removeAlpha().raw().toBuffer({resolveWithObject:true}));
    const differences=[];
    for(let j=1;j<3;j++) {
      const a=decoded[0],b=decoded[j]; assert.deepEqual(a.info,b.info);
      let total=0,changed=0,count=0;
      // Exclude diagnostic headings in the nine-map gallery.
      for(let k=100*a.info.width*a.info.channels;k<a.data.length;k++) { const d=Math.abs(a.data[k]-b.data[k]); total+=d;changed+=d>1?1:0;count++; }
      differences.push({phase:group[j].phase,meanAbsoluteChannelDifference:total/count,channelFractionOverOneLevel:changed/count});
    }
    summaries.push({folder,map:first.map,materials:first.materials,bindings:first.bindings,visited:first.visited,
      bindCPUus:first.bind_cpu_us,drawCalls:first.draw_calls,drawDelta:group[2].draw_calls-first.draw_calls,differences});
  }
}
const journeys=[];
for (const directory of ['journey-rainmarket','journey-siltwake-final','journey-emberline-second','journey-thermal','journey-spectator','journey-tidal-accepted']) {
  const j=JSON.parse(fs.readFileSync(`${root}/${directory}/journey.json`));
  assert.deepEqual(j.failures,[]);
  assert(j.records.every(r=>!r.look.capped));
  journeys.push({directory,kind:j.kind,snapshots:j.records.at(-1).snapshots,records:j.records.map(r=>({name:r.name,weather:r.weather.weather,wetness:r.look.wetness,materials:r.look.materials,ack:r.ack,round:r.round,spectating:r.spectating}))});
}
fs.writeFileSync(`${root}/acceptance-summary.json`,JSON.stringify({scope:'Native llvmpipe art review; bind CPU only, not FPS. Image differences are raw RGB levels, not perceptual scores.',summaries,journeys},null,2));
console.log(`WORLD_WEATHER_EVIDENCE_OK matchedMaps=${summaries.length} images=51 journeys=${journeys.length} drawDelta=0 capHits=0`);
