// Rendered distinctness: how different do the captured weapon frames actually
// look? Reads two capture directories (each holding `<size>-weapon-<id>-<state>.png`)
// and reports, for every weapon pair, the mean absolute pixel difference inside
// the weapon region of the frame (bottom-centre crop). This is a *rendered*
// companion to the analytic mask IoU in silhouette.mjs: geometry can differ on
// paper and still render the same, and this measures the pixels.
//
// Usage: node tools/godot-weapons/rendered-distinctness.mjs <dirA> [dirB] [--size=1280x800] [--state=hip] [--json]
import sharp from 'sharp';
import {join} from 'node:path';
import {existsSync} from 'node:fs';

const args = process.argv.slice(2);
const positional = args.filter(a => !a.startsWith('--'));
const flag = (name, fallback) => {
  const found = args.find(a => a.startsWith(`--${name}=`));
  return found ? found.slice(name.length + 3) : fallback;
};
const [dirA, dirB] = positional;
if (!dirA) throw new Error('Usage: node tools/godot-weapons/rendered-distinctness.mjs <dirA> [dirB] [--size=1280x800] [--state=hip]');
const size = flag('size', '1280x800'), state = flag('state', 'hip');
const [width, height] = size.split('x').map(Number);
// The viewmodel occupies the bottom-centre of the frame: crop it out so scene
// geometry and HUD text do not dilute the measure.
const crop = {left: Math.round(width * .30), top: Math.round(height * .42), width: Math.round(width * .48), height: Math.round(height * .56)};

async function frame(directory, id) {
  const file = join(directory, `${size}-weapon-${id}-${state}.png`);
  if (!existsSync(file)) throw new Error(`missing capture ${file}`);
  const {data, info} = await sharp(file).extract(crop).removeAlpha().raw().toBuffer({resolveWithObject: true});
  return {data, info};
}

function meanAbsoluteDifference(a, b) {
  let sum = 0;
  for (let i = 0; i < a.length; i++) sum += Math.abs(a[i] - b[i]);
  return sum / a.length;
}

async function pairwise(directory) {
  const frames = [];
  for (let id = 0; id < 10; id++) frames.push((await frame(directory, id)).data);
  const matrix = [];
  let min = Infinity, max = 0, sum = 0, count = 0, closest = null;
  for (let i = 0; i < 10; i++) {
    matrix.push([]);
    for (let j = 0; j < 10; j++) {
      const value = i === j ? 0 : i >= j ? matrix[j][i] : meanAbsoluteDifference(frames[i], frames[j]);
      matrix[i].push(+value.toFixed(2));
      if (i < j) {
        if (value < min) { min = value; closest = [i, j]; }
        max = Math.max(max, value); sum += value; count++;
      }
    }
  }
  return {matrix, min: +min.toFixed(2), max: +max.toFixed(2), mean: +(sum / count).toFixed(2), closestPair: closest,
    crop, size, state};
}

const before = await pairwise(dirA);
const result = {measure: 'mean absolute pixel difference inside the viewmodel crop', crop, [dirA]: before};
if (dirB) result[dirB] = await pairwise(dirB);
if (args.includes('--json')) {
  console.log(JSON.stringify(result, null, 2));
} else {
  for (const [directory, report] of Object.entries(result)) {
    if (typeof report !== 'object' || !report.matrix) continue;
    console.log(`${directory}: min=${report.min} mean=${report.mean} max=${report.max} closest=${report.closestPair}`);
    console.log('      ' + [...Array(10).keys()].map(n => String(n).padStart(3)).join(''));
    report.matrix.forEach((row, i) => console.log(String(i).padStart(3) + '   ' + row.map(v => v.toFixed(0).padStart(3)).join('')));
  }
}
