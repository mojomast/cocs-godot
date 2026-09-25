#!/usr/bin/env node
// Add verified, source-pinned mode-parity images to the existing LAN gallery.
// Preserve its historical images and Moth comparison pages in place.
import {readFileSync, existsSync, mkdirSync, copyFileSync, renameSync, writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {join, resolve} from 'node:path';

const site = resolve(process.env.GALLERY_SITE ?? '');
if (!process.env.GALLERY_SITE || !existsSync(join(site,'index.html')) || !existsSync(join(site,'moth.html'))) {
  throw Error('Set GALLERY_SITE to the existing gallery root (index.html and moth.html required)');
}
const evidence = join(import.meta.dirname,'evidence');
const manifest = JSON.parse(readFileSync(join(evidence,'captures.json'),'utf8'));
const root = resolve(import.meta.dirname,'../..');
const pin = JSON.parse(readFileSync(join(root,'port/contracts/source-lock.json'),'utf8')).source_commit;
if (manifest.schema !== 1 || manifest.source_commit !== pin || !manifest.scene_runtime_commit || manifest.files.length !== 10) {
  throw Error('Expected ten captures from the pinned source and recorded port runtime');
}
const names = ['menu-native-24','dm-diagnostics','dm-roster','dm-barrel-fire',
  'horde-before','horde-before-detail','horde-impact','horde-impact-detail','horde-death','horde-death-detail'];
if (names.some(name => !manifest.files.some(file => file.name === name)) ||
  manifest.files.some(file => !names.includes(file.name))) throw Error('Unexpected capture names');
const dest = join(site,'mode-parity');
mkdirSync(dest,{recursive:true});
for (const file of manifest.files) {
  if (file.path !== file.name+'.png' || !/^[a-z0-9-]+\.png$/.test(file.path)) throw Error('Unsafe capture path');
  const input = join(evidence,file.path);
  const buffer = readFileSync(input);
  if (buffer.readUInt32BE(0) !== 0x89504e47 || buffer.readUInt32BE(16) !== file.width ||
      buffer.readUInt32BE(20) !== file.height || createHash('sha256').update(buffer).digest('hex') !== file.sha256) {
    throw Error(`Evidence checksum or dimensions differ: ${file.path}`);
  }
  copyFileSync(input,join(dest,file.path+'.new'));
  renameSync(join(dest,file.path+'.new'),join(dest,file.path));
}
copyFileSync(join(evidence,'captures.json'),join(dest,'captures.json.new'));
renameSync(join(dest,'captures.json.new'),join(dest,'captures.json'));

const card = (full, alt, caption, thumbnail=full) =>
  `<figure><a href="mode-parity/${full}.png"><img loading="lazy" src="mode-parity/${thumbnail}.png" alt="${alt}"></a><figcaption>${caption}</figcaption></figure>`;
const section = `<!-- mode-parity-gallery:start -->
  <section id="mode-parity">
    <h2>New: movement, diagnostics, Horde deaths &amp; native bot capacity</h2>
    <p class="note">Fresh 24 September 2026 captures from Godot scenes at port revision
    <code>${manifest.scene_runtime_commit.slice(0,12)}</code>, matching the
    <a href="https://github.com/mojomast/cocs-godot/releases/tag/mode-parity-2026-09-24">mode-parity prerelease</a>.
    Rendered on Linux llvmpipe, OpenGL Compatibility; screenshots are not hardware-GPU FPS or hands-on visual approval.
    The <strong>24-bot image shows menu selection only</strong>; live rendered play frames below use <strong>4 bots + 1 human</strong>.
    Headless live smokes separately exercised 25 actors. Full-size originals and
    <a href="mode-parity/captures.json">dimensions, event readbacks and SHA-256 capture manifest</a> are available.</p>
    <div class="grid">
      ${card('menu-native-24','Native Deathmatch menu showing 24 bots selected and diagnostics enabled','Local Native Deathmatch: 24-bot selection and Diagnostics toggle in the menu (no 24-bot gameplay is pictured).')}
      ${card('dm-diagnostics','Prism Foundry first-person frame with F11 diagnostics: 5 actors, 4 bots','Prism Foundry: live 4-bot first-person frame with F11 readout, five authority actors, viewport and frame diagnostics.')}
      ${card('dm-roster','Prism Foundry five-actor scoreboard','Native Deathmatch: Tab scoreboard for the same live five-actor match.')}
      ${card('dm-barrel-fire','Prism Foundry first-person view with the pulse rifle','Native Deathmatch: four-bot first-person scene after locally submitted, authority-confirmed firing; the short-lived flash may not survive a slow software-rendered frame.')}
      ${card('horde-before','Meridian Exchange wave one with enemy in view','Meridian Exchange Horde: real wave-one NPC before the staged source damage event.','horde-before-detail')}
      ${card('horde-impact','Meridian Exchange after one NPC death','Horde just after the authoritative death: one death burst and a corpse reported by the live scene. Click for the complete un-cropped frame.','horde-impact-detail')}
      ${card('horde-death','Meridian Exchange enemy beginning a fall','Horde a few rendered frames later, with the dying NPC falling. Click for the complete un-cropped frame.','horde-death-detail')}
    </div>
    <p class="note">Horde before/after thumbnails are <strong>labelled nearest-neighbour crops</strong> of the linked, unaltered 1280×800 frames.
    A test harness applied one lethal <code>Match.damage</code> call to a real source NPC; the authority delivered the death,
    and the game created the corpse and blood burst. This is an arranged visual capture, not a natural player kill or blood-quality acceptance.
    Pointer focus and fleeting effects can differ in llvmpipe screenshots; inspect the build on your GPU for movement, muzzle and blood/death feel.</p>
  </section>
  <!-- mode-parity-gallery:end -->`;

const index = join(site,'index.html');
let html = readFileSync(index,'utf8');
const start = '<!-- mode-parity-gallery:start -->';
const end = '<!-- mode-parity-gallery:end -->';
if (html.includes(start) && html.includes(end)) {
  html = html.slice(0,html.indexOf(start)) + section + html.slice(html.indexOf(end)+end.length);
} else {
  if (!html.includes('<main>') || !html.includes('<a class="montage" href="gallery.jpg">')) {
    throw Error('Gallery index layout changed; refusing to overwrite it');
  }
  html = html.replace('<main>','<main>\n  '+section+ '\n  <p class="sub">Earlier combat and asset contact sheet:</p>');
}
html = html.replace(/<title>COCS: DESTINATIONS[^<]*<\/title>/,
  '<title>COCS: DESTINATIONS — Mode Parity Gallery</title>');
html = html.replace(/<h1>COCS: DESTINATIONS[^<]*<\/h1>/,
  '<h1>COCS: DESTINATIONS — Mode Parity Gallery</h1>');
html = html.replace(/<p class="note">Screenshots served read-only[\s\S]*?<\/p>/,
  `<p class="note">Screenshots served read-only from an owned temporary directory.
   <strong>Latest Windows + Linux prerelease:</strong>
   <a href="https://github.com/mojomast/cocs-godot/releases/tag/mode-parity-2026-09-24">mode-parity-2026-09-24</a>
   — 185/185 native gates and 17/17 hosted fresh-extraction checks on each platform.
   Original source pin ${pin.slice(0,12)}; owner hardware playtest is still pending.</p>`);
writeFileSync(index+'.new',html);
renameSync(index+'.new',index);
console.log(`GALLERY_PUBLISHED ${JSON.stringify({site,images:manifest.files.length,release:'mode-parity-2026-09-24',runtime:manifest.scene_runtime_commit})}`);
