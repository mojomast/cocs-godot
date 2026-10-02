// Original fighting-mode art and PCM. No downloaded inputs, engine or encoder.
import {mkdir, writeFile, readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
// A committed minimal projection permits reproducible builds without sibling worktrees.
// sync_content.mjs refreshes it from the authoritative roster, preserving exact IDs/windows.
export const content = JSON.parse(await readFile(path.join(root,'tools/fighting/effects/content_contract.json'),'utf8'));
export const moves = ['stand_l','stand_m','stand_h','crouch_l','crouch_m','crouch_h','air_l','air_m','air_h','throw_f','throw_b','special1','special2','special3','super'];
export const roles = ['attack','guard','impact','throw','super','tech'];
// Each polyline is independently authored. Coordinates are metres at scale 1.
const line = (points, motion, width = .025, delay = 0) => ({points, motion, width, delay});
export const families = {
  chatgpt: {color:'#57e6cd', language:'survey brackets / articulated tracking cable', tone:[620,930,1240], wave:'sine', segments:[
    line([[-.48,.18],[-.48,.42],[-.24,.42]],'track'), line([[.24,.42],[.48,.42],[.48,.18]],'track'),
    line([[-.48,-.18],[-.48,-.42],[-.24,-.42]],'track'), line([[.24,-.42],[.48,-.42],[.48,-.18]],'track'),
    line([[-.8,0],[-.6,.08],[-.4,-.08],[-.2,.04],[0,0]],'reel',.018,.12)]},
  claude: {color:'#f29d71', language:'salmon ceramic chevrons / plate ward', tone:[440,660,880], wave:'triangle', segments:[
    line([[-.46,-.48],[-.12,0],[-.46,.48]],'ward',.06),
    line([[-.18,-.4],[.14,0],[-.18,.4]],'ward',.045,.16),
    line([[.1,-.32],[.38,0],[.1,.32]],'ward',.03,.32),
    line([[-.55,-.52],[-.55,.52]],'settle',.04)]},
  grok: {color:'#ff8b4d', language:'asymmetric piston / ballistic embers', tone:[110,173,257], wave:'pulse', segments:[
    line([[-.58,-.3],[-.2,-.3],[.18,.12],[.62,.12]],'piston',.08),
    line([[-.52,.28],[-.16,.28],[.3,.46]],'piston',.035,.18),
    line([[.16,-.1],[.26,-.14]],'ember',.04,.1), line([[.35,.18],[.42,.23]],'ember',.025,.26),
    line([[.04,.34],[.11,.43]],'ember',.025,.34)]},
  meta: {color:'#57b9ff', language:'paired turbine sectors / inward implosion', tone:[82,123,164], wave:'sine', segments:[
    line([[-.66,0],[-.57,.23],[-.35,.31],[-.18,.23]],'implode',.075),
    line([[-.18,-.23],[-.35,-.31],[-.57,-.23],[-.66,0]],'implode',.055,.14),
    line([[.18,.23],[.35,.31],[.57,.23],[.66,0]],'implode',.075,.07),
    line([[.66,0],[.57,-.23],[.35,-.31],[.18,-.23]],'implode',.055,.21),
    line([[-.27,0],[0,.14],[.27,0]],'brace',.08,.34)]},
  gemini: {color:'#fff0c3', language:'split petals / interleaved two bands', tone:[523,784,1046], wave:'triangle', segments:[
    line([[0,0],[-.26,.34],[-.55,.42],[-.36,.12],[0,0]],'petal_a',.026),
    line([[0,0],[.26,-.34],[.55,-.42],[.36,-.12],[0,0]],'petal_b',.026,.18),
    line([[0,0],[.28,.18],[.54,.05],[.32,-.06],[0,0]],'petal_b',.038,.08),
    line([[0,0],[-.28,-.18],[-.54,-.05],[-.32,.06],[0,0]],'petal_a',.038,.26)]},
  deepseek: {color:'#56c5f2', language:'concentrating pressure channels / buoyant bubbles', tone:[147,294,588], wave:'sine', segments:[
    line([[-.75,.38],[-.4,.18],[0,.08],[.24,0]],'compress',.045),
    line([[-.75,-.38],[-.4,-.18],[0,-.08],[.24,0]],'compress',.045,.08),
    line([[-.8,0],[-.3,0],[.32,0]],'compress',.07,.18),
    line([[-.38,.15],[-.43,.2],[-.38,.25],[-.33,.2],[-.38,.15]],'bubble',.018,.22),
    line([[-.62,-.12],[-.66,-.08],[-.62,-.04],[-.58,-.08],[-.62,-.12]],'bubble',.018,.36)]},
  mistral: {color:'#ffbd59', language:'swept aerofoil slivers / shear ribbons', tone:[740,1110,1480], wave:'triangle', segments:[
    line([[-.85,-.22],[-.2,.1],[.65,.18],[.1,.04],[-.85,-.22]],'sweep',.02),
    line([[-.7,.16],[-.16,.4],[.52,.36]],'shear',.028,.12),
    line([[-.92,-.36],[-.36,-.14],[.28,-.12]],'shear',.015,.26),
    line([[-.45,.34],[-.14,.5],[.08,.46]],'sweep',.018,.34)]},
  kimi: {color:'#ff82b2', language:'broken orbital arcs / afterimage trace', tone:[659,831,988], wave:'sine', segments:[
    line([[.5,0],[.46,.23],[.28,.4],[.06,.46]],'orbit',.025),
    line([[-.28,.4],[-.46,.23],[-.5,0]],'orbit',.025,.12),
    line([[-.46,-.23],[-.28,-.4],[-.06,-.46]],'orbit',.025,.24),
    line([[.28,-.4],[.46,-.23],[.5,0]],'orbit',.025,.36),
    line([[-.7,-.06],[-.4,.05],[-.14,-.04],[.1,0]],'echo',.012,.18)]},
  qwen: {color:'#b797ff', language:'segmented tether / locking lamellar sigils', tone:[220,330,495], wave:'pulse', segments:[
    line([[-.74,0],[-.55,0]],'lock',.025), line([[-.48,0],[-.29,0]],'lock',.025,.08),
    line([[-.22,0],[-.03,0]],'lock',.025,.16),
    line([[.12,-.32],[.36,-.32],[.48,-.12],[.48,.12],[.36,.32],[.12,.32]],'lamella',.04,.24),
    line([[.04,-.2],[.28,-.2],[.38,0],[.28,.2],[.04,.2]],'lamella',.025,.36),
    line([[.22,-.08],[.3,0],[.22,.08]],'lock',.04,.44)]}
};
export function catalog() {
  const effects = {};
  for (const operator of Object.keys(families)) {
    for (const [index, move] of moves.entries()) {
      const weight = move.endsWith('_h') ? 1.2 : move.endsWith('_m') ? .92 : .68;
      effects[`${operator}:${move}`] = {operator, move, scale: move === 'super' ? 1.45 : move.startsWith('throw') || move === 'special3' ? 1.05 : move.startsWith('special') ? 1.12 : weight,
        lifetime: move === 'super' ? .72 : move.startsWith('throw') ? .42 : .25 + index % 3 * .04,
        beat: index % 3, socket: move.startsWith('crouch') || move.startsWith('air') ? 'Socket_FootR' : 'Socket_HandR'};
    }
    for (const move of ['guard_hi','guard_lo','throw_tech','dash_f','dash_b','land','jump_rise','counter','reflect','clash','release'])
      effects[`${operator}:${move}`] = {operator,move,scale:.72,lifetime:.32,beat:0,socket:'Socket_HandR'};
    for (const [move,contract] of Object.entries(content.operators[operator] ?? {})) {
      const key = contract.effect;
      if (!effects[key]) {
        if (operator !== 'gemini' || !['palm_l','palm_m','palm_h'].includes(move)) throw Error(`Unauthored effect ${key}`);
        effects[key] = {...effects[`gemini:stand_${move.at(-1)}`],move,shape_variant:'palm',beat:2};
      }
      Object.assign(effects[key],{level:contract.level,startup_frames:contract.startup,kind:contract.kind,
        declared_windows:Object.fromEntries(['movement','throw','counter','stance'].filter(f=>f in contract).map(f=>[f,contract[f]]))});
    }
  }
  return {version:1, units_per_meter:1000, content_roster_sha256:content.roster_sha256, families,effects, budgets:{low:{slots:12,segments:12,voices:4},high:{slots:32,segments:24,voices:6},detail:{slots:48,segments:32,voices:8}},dedup_window:4096};
}
const RATE = 22050;
export function pcm(operator, role) {
  const f = families[operator];
  const duration = {attack:.11,guard:.085,impact:.12,throw:.22,super:.36,tech:.14}[role];
  const count = Math.round(duration * RATE);
  const data = Buffer.alloc(count * 2 + 44);
  data.write('RIFF'); data.writeUInt32LE(data.length - 8,4); data.write('WAVEfmt ',8); data.writeUInt32LE(16,16);
  data.writeUInt16LE(1,20); data.writeUInt16LE(1,22); data.writeUInt32LE(RATE,24); data.writeUInt32LE(RATE * 2,28);
  data.writeUInt16LE(2,32); data.writeUInt16LE(16,34); data.write('data',36); data.writeUInt32LE(count * 2,40);
  let phase = 0, peak = 0, sum = 0;
  for (let i = 0; i < count; i++) {
    const t = i / RATE, u = i / (count - 1);
    const beat = Math.min(2,Math.floor(u * 3));
    const shift = {attack:1,guard:1.55,impact:.68,throw:.82,super:.5,tech:1.8}[role];
    const freq = f.tone[beat] * shift * (role === 'throw' ? 1.3 - .6 * u : role === 'impact' ? 1 - .35 * u : 1);
    phase += 2 * Math.PI * freq / RATE;
    const fundamental = Math.sin(phase);
    // Band-limited additive approximation, never discontinuous square edges.
    const carrier = f.wave === 'pulse' ? (fundamental + .25 * Math.sin(3 * phase) + .1 * Math.sin(5 * phase)) / 1.35 : f.wave === 'triangle' ? (fundamental - Math.sin(3 * phase) / 9) / 1.12 : fundamental;
    const envelope = Math.min(1,t / .006,(duration-t)/.009) * Math.pow(1-u,role === 'super' ? .7 : 1.5);
    const accent = role === 'guard' ? .7 + .3 * Math.cos(2 * Math.PI * 70 * t) : role === 'tech' ? Math.pow(Math.sin(Math.PI * u * 2),2) : 1;
    const sample = Math.round(.32 * carrier * envelope * accent * 32767);
    data.writeInt16LE(sample,44+i*2); peak = Math.max(peak,Math.abs(sample)/32768); sum += (sample/32768)**2;
  }
  return {data, duration:count/RATE, peak, rms:Math.sqrt(sum/count)};
}
export const hash = data => createHash('sha256').update(data).digest('hex');
export async function build(check = false) {
  const dir = path.join(root,'godot/fighting/assets/effects');
  const entries = [];
  const outputs = new Map([['catalog.json',Buffer.from(JSON.stringify(catalog(),null,2)+'\n')]]);
  for (const operator of Object.keys(families)) for (const role of roles) {
    const {data,...stats} = pcm(operator,role), file = `audio/${operator}_${role}.wav`;
    outputs.set(file,data); entries.push({file,sha256:hash(data),bytes:data.length,...stats});
  }
  outputs.set('manifest.json',Buffer.from(JSON.stringify({version:1, provenance:'New original deterministic additive PCM motifs; build.mjs, no external inputs',sample_rate:RATE,channels:1,bits:16,files:entries},null,2)+'\n'));
  for (const [file,data] of outputs) {
    const target = path.join(dir,file);
    if (check) {if (!data.equals(await readFile(target))) throw Error(`Non-deterministic asset ${file}`);}
    else {await mkdir(path.dirname(target),{recursive:true}); await writeFile(target,data);}
  }
  return {assets:entries.length,bytes:entries.reduce((n,x)=>n+x.bytes,0),catalog_sha256:hash(outputs.get('catalog.json'))};
}
if (process.argv[1] === fileURLToPath(import.meta.url)) console.log(JSON.stringify(await build(process.argv.includes('--check')),null,2));
