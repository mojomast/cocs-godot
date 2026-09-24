// Diagnostic: print the side/top silhouette masks as ASCII art, with an
// overlap view for a chosen pair (A-only / both / B-only).
// Usage: node tools/godot-weapons/silhouette-map.mjs [a] [b] [view]
import {readFileSync} from 'node:fs';
import {decodeMask} from './silhouette.mjs';
const manifest = JSON.parse(readFileSync(process.argv[5] ?? new URL('../../godot/first_person/generated/manifest.json', import.meta.url)));
const view = process.argv[4] ?? 'side';
const a = Number(process.argv[2] ?? 0), b = Number(process.argv[3] ?? -1);
const render = (mask, width, height, other) => {
  const stride = (width + 7) >> 3;
  const rows = [];
  for (let j = height - 1; j >= 0; j--) {
    let line = '';
    for (let i = 0; i < width; i++) {
      const bit = (m) => (m[j * stride + (i >> 3)] >> (i & 7)) & 1;
      const left = bit(mask), right = other ? bit(other) : 0;
      line += left && right ? '#' : left ? 'A' : right ? 'B' : '.';
    }
    rows.push(line.replace(/\s+$/, ''));
  }
  return rows.join('\n');
};
const decoded = manifest.weapons.map(w => decodeMask(w.silhouette[view], view));
const iou = (x, y, width, height) => {
  const stride = (width + 7) >> 3;
  let inter = 0, union = 0;
  for (let j = 0; j < height; j++) for (let i = 0; i < width; i++) {
    const p = (m) => (m[j * stride + (i >> 3)] >> (i & 7)) & 1;
    const l = p(x.mask), r = p(y.mask);
    inter += l & r; union += l | r;
  }
  return (inter / union).toFixed(4);
};
if (b >= 0) {
  console.log(`${manifest.weapons[a].name} (A) vs ${manifest.weapons[b].name} (B) | ${view} | IoU ${iou(decoded[a], decoded[b], decoded[a].width, decoded[a].height)}`);
  console.log(render(decoded[a].mask, decoded[a].width, decoded[a].height, decoded[b].mask));
} else {
  for (const [i, w] of manifest.weapons.entries()) {
    console.log(`--- ${i} ${w.name} | ${view} | filled ${w.silhouette.filled[view === 'top' ? 'top' : 'side']}`);
    console.log(render(decoded[i].mask, decoded[i].width, decoded[i].height));
  }
}
