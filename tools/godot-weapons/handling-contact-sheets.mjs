// Review sheets for the first-person handling fixtures. Read-only over the
// captured PNGs; never modifies an individual capture.
import sharp from 'sharp';
import {join} from 'node:path';
import {existsSync, mkdirSync} from 'node:fs';
const directory = process.argv[2];
if (!directory) throw new Error('Usage: node tools/godot-weapons/handling-contact-sheets.mjs <capture-directory> [output-directory] [jpeg-quality]');
const output = process.argv[3] ?? directory;
const quality = Number(process.argv[4] ?? 92);
mkdirSync(output, {recursive:true});
const NAMES = ['Pulse Rifle','Rocket Launcher','Rail Lance','Scattergun','Plasma Driver','Grenade Launcher','Shock Beam','Flak Cannon','Marksman Rifle','SMG'];
const STATES = ['hip','ads','fire','reload','heat','heat-hold','hot-ads'];
const label = (width, text) => Buffer.from(`<svg width="${width}" height="22"><text x="7" y="16" font-family="sans-serif" font-size="13" fill="#62deca">${text}</text></svg>`);
async function tile(file, width, height) {
  return sharp(join(directory, file)).resize(width, height, {fit:'contain', background:'#101a22'}).png().toBuffer();
}
// One sheet per pose: all ten weapons side by side.
for (const size of ['960x640','1280x800']) {
  for (const state of STATES) {
    const [w,h] = size.split('x').map(Number);
    const tileWidth = 480, tileHeight = Math.round(tileWidth * h / w);
    const composite = [];
    for (const [weapon,name] of NAMES.entries()) {
      const file = `handling-${size}-w${weapon}-${state}.png`;
      if (!existsSync(join(directory,file))) continue;
      const row = Math.floor(weapon/5), column = weapon%5;
      composite.push({input: label(tileWidth, `${weapon}: ${name} | ${state}`), top: row*(tileHeight+22), left: column*tileWidth});
      composite.push({input: await tile(file, tileWidth, tileHeight), top: row*(tileHeight+22)+22, left: column*tileWidth});
    }
    await sharp({create:{width:tileWidth*5, height:(tileHeight+22)*2, channels:3, background:'#101a22'}})
      .composite(composite).jpeg({quality}).toFile(join(output, `sheet-${size}-${state}.jpg`));
  }
}
// One strip per weapon: every pose in capture order.
for (const size of ['960x640','1280x800']) {
  const [w,h] = size.split('x').map(Number);
  const tileWidth = 420, tileHeight = Math.round(tileWidth * h / w);
  for (const [weapon,name] of NAMES.entries()) {
    const composite = [];
    for (const [index,state] of STATES.entries()) {
      const file = `handling-${size}-w${weapon}-${state}.png`;
      if (!existsSync(join(directory,file))) continue;
      composite.push({input: label(tileWidth, `${state.toUpperCase()}`), top: index*(tileHeight+22), left: 0});
      composite.push({input: await tile(file, tileWidth, tileHeight), top: index*(tileHeight+22)+22, left: 0});
    }
    await sharp({create:{width:tileWidth, height:(tileHeight+22)*STATES.length, channels:3, background:'#101a22'}})
      .composite(composite).jpeg({quality}).toFile(join(output, `strip-${size}-w${weapon}.jpg`));
  }
}
console.log(JSON.stringify({sheets: STATES.length*2, strips: NAMES.length*2}));
