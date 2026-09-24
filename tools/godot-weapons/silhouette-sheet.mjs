// Silhouette comparison sheet: draws the analytic weapon masks (tools/godot-
// weapons/silhouette.mjs) as an image so the identity work can be reviewed as
// shapes, not just numbers. One row per weapon: side profile, top profile and
// the authored detail-only side profile, all on the same weapon-space grid.
//
// Usage: node tools/godot-weapons/silhouette-sheet.mjs <manifest.json> <output.png>
import sharp from 'sharp';
import {readFileSync} from 'node:fs';
import {decodeMask} from './silhouette.mjs';

const [manifestPath, outputPath] = process.argv.slice(2);
if (!manifestPath || !outputPath) throw new Error('Usage: node tools/godot-weapons/silhouette-sheet.mjs <manifest.json> <output.png>');
const manifest = JSON.parse(readFileSync(manifestPath));
const SCALE = 5, PAD = 8, LABEL = 22, ROW_GAP = 6;
const views = ['side', 'top', 'detailSide'];

// Nearest-neighbour upscale so mask cells stay crisp squares.
function render(mask, width, height, colour, other) {
  const stride = (width + 7) >> 3;
  const outWidth = width * SCALE, outHeight = height * SCALE;
  const pixels = Buffer.alloc(outWidth * outHeight * 3);
  const bit = (m, x, y) => (m[y * stride + (x >> 3)] >> (x & 7)) & 1;
  for (let y = 0; y < outHeight; y++) {
    for (let x = 0; x < outWidth; x++) {
      const i = Math.floor(x / SCALE), j = Math.floor(y / SCALE);
      const mine = bit(mask, i, j), theirs = other ? bit(other, i, j) : 0;
      const [r, g, b] = mine && theirs ? [225, 235, 240] : theirs ? [70, 92, 104] : mine ? colour : [16, 26, 34];
      const at = ((outHeight - 1 - y) * outWidth + x) * 3;
      pixels[at] = r; pixels[at + 1] = g; pixels[at + 2] = b;
    }
  }
  return {pixels, width: outWidth, height: outHeight};
}

const rows = manifest.weapons.map(weapon => {
  const parts = [];
  for (const view of views) {
    const {mask, width, height} = decodeMask(weapon.silhouette[view], view);
    const other = view === 'detailSide'
      ? decodeMask(weapon.silhouette.side, 'side')
      : null;
    parts.push({...render(mask, width, height, view === 'detailSide' ? [98, 222, 255] : [98, 222, 255], other?.mask), view});
  }
  return parts;
});
const cellHeight = Math.max(...rows.flat().map(p => p.height));
const cellWidth = Math.max(...rows.flat().map(p => p.width));
const composites = [];
const label = (text, width) => Buffer.from(`<svg width="${width}" height="${LABEL}"><text x="6" y="16" font-family="sans-serif" font-size="14" fill="#7fe0d0">${text}</text></svg>`);
rows.forEach((parts, row) => {
  const top = row * (cellHeight + PAD + LABEL + ROW_GAP);
  parts.forEach((part, column) => {
    const left = column * (cellWidth + PAD);
    composites.push({input: label(`${manifest.weapons[row].id}: ${manifest.weapons[row].name} | ${part.view}`, cellWidth), top, left});
    composites.push({input: Buffer.from(part.pixels), raw: {width: part.width, height: part.height, channels: 3},
      top: top + LABEL, left});
  });
});
// Nearest-neighbour upscale of each mask happens by compositing at 1x then
// resizing the whole sheet up; keep the masks crisp with kernel 'nearest'.
const width = (cellWidth + PAD) * views.length;
const height = rows.length * (cellHeight + PAD + LABEL + ROW_GAP);
await sharp({create: {width, height, channels: 3, background: '#101a22'}})
  .composite(composites)
  .png()
  .toFile(outputPath);
console.log(JSON.stringify({output: outputPath, views, weapons: rows.length, grid: [width, height]}));
