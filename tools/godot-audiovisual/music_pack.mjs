// Deterministic, offline packaging of existing reviewed assets. Run from repo root:
// node tools/godot-audiovisual/music_pack.mjs
import {readFileSync, writeFileSync, mkdirSync, copyFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
const check = process.argv.includes('--check');

const read = path => JSON.parse(readFileSync(path, 'utf8'));
const hash = path => createHash('sha256').update(readFileSync(path)).digest('hex');
const base = 'godot/audio';
const source = read('public/music/manifest.json');
// Each orchestral family is represented; the engine pitch-shifts nearby notes.
// Two layers and/or round robins remain for melodic strings, brass and drums.
const ids = [
 'strings-pad-cello-c3-p','strings-pad-viola-f3-p','strings-pad-violin-a3-p','strings-pad-violin-a3-mf','strings-pad-viola-c4-p','strings-pad-violin-e4-mf',
 'low-strings-stacc-cello-rr1-d2-p','low-strings-stacc-cello-rr2-d2-mf','low-strings-stacc-viola-rr1-f3-p','low-strings-stacc-violin-rr1-c4-mf',
 'low-brass-tuba-d2-p','low-brass-tuba-f2-mf','low-brass-fhorn-c3-p','low-brass-trombone-f3-mf',
 'brass-stacc-tuba-rr1-d2-mf','brass-stacc-horn-rr1-f2-p','brass-stacc-horn-rr2-f2-mf','brass-stacc-trumpet-rr1-d4-mf',
 'trumpet-pad-trumpet-d4-p','trumpet-pad-trumpet-a4-mf',
 'timpani-timp1-fs2-p','timpani-timp4-e3-mf','timpani-roll-timp1-fs2-p',
 'bells-glock-g4-p','bells-glock-c5-mf','tubular-bells-chimes-c3-mf','gong-gong-c4-mf',
 'cymbal-swell-swell1-c4-p','cymbal-crash-crash3-c4-mf',
 'harp-harp-d2-p','harp-harp-d4-p','harp-harp-a4-p',
 'taiko-bassdrum-c2-p','taiko-bassdrum-c2-mf','taiko-framel-f2-p','taiko-framel-muted-a2-mf','taiko-frames-d3-mf',
];
const samples = ids.map(id => {
 const entry = source.samples.find(s => s.id === id);
 if (!entry) throw Error(`Missing source sample: ${id}`);
 const src = join('public/music', entry.file), dst = join(base, 'music', entry.file);
 if (check) {
  if (hash(dst) !== hash(src)) throw Error(`Native Ogg differs from original: ${id}`);
 } else {
  mkdirSync(join(base, 'music/samples'), {recursive:true});
  copyFileSync(src, dst);
 }
 return {id, instrument:entry.instrument, midi:entry.midi, velocity:entry.velocity,
  file:entry.file, loopStart:entry.loopStart, loopEnd:entry.loopEnd,
  gain:entry.gain, source:entry.source, license:entry.license, url:entry.url, sha256:hash(src)};
});
const musicText = JSON.stringify({schema:1,source:'public/music/manifest.json',sampleRate:source.sampleRate,samples},null,2)+'\n';
if (check) {
 if (readFileSync(join(base,'music/manifest.json'),'utf8') !== musicText) throw Error('Native music manifest differs');
} else writeFileSync(join(base,'music/manifest.json'),musicText);
const announcer = read('public/audio/announcer/manifest.json');
 if (!check) mkdirSync(join(base,'announcer'),{recursive:true});
for (const clip of announcer.clips) {
 const src = join('public/audio/announcer',clip.file);
 if (hash(src) !== clip.sha256) throw Error(`Source WAV hash mismatch: ${clip.file}`);
 if (check) {
  if (hash(join(base,'announcer',clip.file)) !== clip.sha256) throw Error(`Native WAV differs: ${clip.file}`);
 } else copyFileSync(src,join(base,'announcer',clip.file));
}
if (announcer.clips.length !== 36 || new Set(announcer.clips.map(c=>c.cue)).size !== 12) throw Error('Announcer inventory changed');
const voiceText = JSON.stringify({...announcer,source:'public/audio/announcer/manifest.json'},null,2)+'\n';
if (check) {
 if (readFileSync(join(base,'announcer/manifest.json'),'utf8') !== voiceText) throw Error('Native announcer manifest differs');
} else writeFileSync(join(base,'announcer/manifest.json'),voiceText);
console.log(`${check?'Verified':'Packaged'} ${samples.length} Ogg samples and ${announcer.clips.length} reviewed WAV takes`);
