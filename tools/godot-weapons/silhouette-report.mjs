// Silhouette distinctness report. Reads an exported manifest (default: the
// current first-person export) and prints the pairwise IoU matrices plus the
// max/mean off-diagonal values that tools/godot-weapons/verify.mjs gates.
//
// Usage: node tools/godot-weapons/silhouette-report.mjs [manifest.json] [--json]
import {readFileSync} from 'node:fs';
import {pairwise} from './silhouette.mjs';

const argument = process.argv[2] && !process.argv[2].startsWith('--')
  ? process.argv[2]
  : new URL('../../godot/first_person/generated/manifest.json', import.meta.url).pathname;
const manifest = JSON.parse(readFileSync(argument));
const names = manifest.weapons.map(w => `${w.id}:${w.name}`);
const views = ['side', 'top', 'detailSide'];
const report = {};
for (const view of views) {
  const masks = manifest.weapons.map(w => {
    if (!w.silhouette?.[view]) throw new Error(`manifest weapon ${w.id} has no ${view} mask; re-run tools/godot-weapons/export.mjs`);
    return w.silhouette[view];
  });
  report[view] = pairwise(masks);
}
if (process.argv.includes('--json')) {
  console.log(JSON.stringify({manifest: argument, names, report}, null, 2));
} else {
  console.log(`manifest: ${argument}`);
  for (const view of views) {
    const {matrix, max, mean, worstPair} = report[view];
    console.log(`\n${view}: maxIoU=${max} meanIoU=${mean} worstPair=${worstPair} (${names[worstPair[0]]} vs ${names[worstPair[1]]})`);
    console.log('      ' + names.map(n => n.split(':')[0].padStart(3)).join(''));
    matrix.forEach((row, i) => console.log(String(i).padStart(3) + '   ' + row.map(v => v.toFixed(2).slice(1)).join('')));
  }
  console.log(JSON.stringify({max: Object.fromEntries(views.map(v => [v, report[v].max])),
    mean: Object.fromEntries(views.map(v => [v, report[v].mean]))}));
}
