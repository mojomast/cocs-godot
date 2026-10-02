import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile, mkdir, writeFile} from 'node:fs/promises';
import path from 'node:path';
import {root, moves, families, roles, catalog, pcm, hash, build, content} from './build.mjs';

test('committed geometry and 54 PCM assets reproduce byte-for-byte', async () => {
  assert.equal((await build(true)).assets,54);
});
test('all 135 attack IDs and movement/defence cues resolve bounded geometry', () => {
  const data = catalog();
  assert.equal(Object.keys(data.families).length,9);
  const fingerprints = new Set();
  for (const [id,family] of Object.entries(data.families)) {
    // Exclude palette, labels, pitch: geometry/motion must carry identity alone.
    fingerprints.add(hash(JSON.stringify(family.segments)));
    const motions = new Set(family.segments.map(x=>x.motion));
    assert.ok(motions.size >= 2,`${id} motion vocabulary`);
    for (const segment of family.segments) {
      assert.ok(segment.points.length >= 2);
      assert.ok(segment.width > 0 && segment.width <= .08);
      assert.ok(segment.delay >= 0 && segment.delay < 1);
      for (const p of segment.points) assert.ok(p.length === 2 && p.every(n=>Number.isFinite(n)&&Math.abs(n)<=1));
    }
    for (const move of moves) {
      const effect = data.effects[`${id}:${move}`];
      assert.equal(effect.move,move);
      assert.ok(effect.scale > 0 && effect.scale <= 1.45);
      assert.ok(effect.lifetime > 0 && effect.lifetime <= .72);
    }
  }
  assert.equal(fingerprints.size,9,'no tint-only duplicate families');
  for (const b of Object.values(data.budgets)) {
    assert.ok(b.slots <= 48 && b.segments <= 32 && b.voices <= 8);
    assert.ok(b.slots * b.segments * 6 <= 9216);
  }
});
test('all 138 actual content effect IDs and declared windows resolve without substitution', async () => {
  const data = catalog();
  let count = 0;
  for (const [operator,operatorMoves] of Object.entries(content.operators)) {
    for (const [key,move] of Object.entries(operatorMoves)) {
      const effect = data.effects[move.effect];
      assert.ok(effect,move.effect);
      assert.equal(effect.operator,operator);
      assert.equal(effect.move,key);
      assert.equal(effect.level,move.level);
      assert.equal(effect.startup_frames,move.startup);
      for (const field of ['movement','throw','counter','stance']) if (field in move) assert.deepEqual(effect.declared_windows[field],move[field]);
      count++;
    }
  }
  assert.equal(count,138);
  for (const key of ['palm_l','palm_m','palm_h']) {
    assert.equal(data.effects[`gemini:${key}`].shape_variant,'palm');
    assert.notDeepEqual(data.effects[`gemini:${key}`],data.effects[`gemini:stand_${key.at(-1)}`]);
  }
  // On an integrated candidate (or explicit content path), compare against live roster.
  const candidate = process.env.EFFECTS_ROSTER ?? path.join(root,'godot/fighting/data/roster.json');
  let bytes;
  try {bytes = await readFile(candidate);} catch (error) {if (process.env.EFFECTS_ROSTER || error.code !== 'ENOENT') throw error;}
  if (bytes) {
    assert.equal(hash(bytes),content.roster_sha256,'refresh effects contract after content changes');
    const roster = JSON.parse(bytes);
    for (const operator of roster.operators) for (const move of Object.values(operator.moves)) assert.ok(data.effects[move.effect],move.effect);
  }
});
test('PCM headers, starts/ends, identities and worst-case voice mix do not clip', async () => {
  const report = {status:'source PCM numeric verification; human/native listening UNRUN', motifs:[], worst_case_eight_voice_peak:0};
  const voiceGain = 10 ** (-24/20);
  const fingerprints = new Set();
  for (const operator of Object.keys(families)) for (const role of roles) {
    const file = path.join(root,`godot/fighting/assets/effects/audio/${operator}_${role}.wav`);
    const wav = await readFile(file);
    const expected = pcm(operator,role);
    assert.ok(wav.equals(expected.data));
    assert.equal(wav.toString('ascii',0,4),'RIFF');
    assert.equal(wav.readUInt32LE(24),22050);
    assert.equal(wav.readUInt16LE(22),1);
    assert.equal(wav.readInt16LE(44),0);
    assert.equal(wav.readInt16LE(wav.length-2),0);
    assert.ok(expected.peak < .33);
    const bound = 8 * voiceGain * expected.peak;
    assert.ok(bound < 1);
    report.worst_case_eight_voice_peak = Math.max(report.worst_case_eight_voice_peak,bound);
    report.motifs.push({operator,role,peak:expected.peak,rms:expected.rms,duration:expected.duration,sha256:hash(wav)});
    fingerprints.add(hash(wav));
  }
  assert.equal(fingerprints.size,54);
  // Actual aligned mixed samples of eight distinct motifs, separate from the bound.
  const waveforms = Object.keys(families).slice(0,8).map(id=>pcm(id,'super').data);
  let peak = 0;
  for (let i=44;i<waveforms[0].length;i+=2) {
    const mixed = waveforms.reduce((n,w)=>n+w.readInt16LE(i)/32768*voiceGain,0);
    peak = Math.max(peak,Math.abs(mixed));
  }
  assert.ok(peak < 1);
  report.aligned_eight_operator_super_mix_peak = peak;
  if (process.env.EFFECTS_EVIDENCE) {
    await mkdir(process.env.EFFECTS_EVIDENCE,{recursive:true});
    await writeFile(path.join(process.env.EFFECTS_EVIDENCE,'pcm-verification.json'),JSON.stringify(report,null,2)+'\n');
  }
});
test('director exposes stable API and is isolated from clocks, input and authority', async () => {
  const source = await readFile(path.join(root,'godot/fighting/effects/director.gd'),'utf8');
  for (const signature of ['configure(options: Dictionary) -> void','consume(events: Array, fighters: Array) -> void','advance(delta: float) -> void','reset() -> void']) assert.ok(source.includes(signature));
  assert.doesNotMatch(source,/func _(process|physics_process)|Input\.|Engine\.time_scale|AudioServer\.|PhysicsServer|fighting\/core|game\/|server\/|randf\(/);
  assert.ok(source.includes('_highest_id - 4096'));
  assert.ok(source.includes('frame < int(old.frame)'));
  assert.ok(source.includes('old.facing != facing'));
});
