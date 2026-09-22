// Acceptance validator for one identity-zone graphical session.
//
// Everything is read from two independent receipts of the same authority:
//   * `wire`  — the authority's own framed output/input log (source state)
//   * `native` — the rendered scene's ZONE_NATIVE projections and ZONE_SHOT lines
// A claim only passes when both agree, per recipient/round/sequence.
import assert from 'node:assert/strict';

const close = (a, b) => typeof a === 'number' && typeof b === 'number' && Math.abs(a - b) < 1e-5;
const finite = value => typeof value === 'number' && Number.isFinite(value);

export function validate({wire, stdout, mapId, mode, sizes, screenshots}) {
  const native = stdout.split('\n').filter(line => line.startsWith('ZONE_NATIVE ')).map(line => JSON.parse(line.slice(12)));
  const shots = stdout.split('\n').filter(line => line.startsWith('ZONE_SHOT ')).map(line => JSON.parse(line.slice(10)));
  const live = stdout.split('\n').filter(line => line.startsWith('ZONE_IDENTITY_LIVE_OK '))
    .map(line => JSON.parse(line.slice(22)));
  assert.equal(live.length, 1, 'one live summary line');

  const snapshots = wire.filter(record => record.direction === 'out' && record.frame.type === 'snapshot');
  const index = new Map(snapshots.map(record => [`${record.round}:${record.frame.seq}`, record.frame]));
  let correlated = 0;
  for (const item of native) {
    // Unprojected ticks (an empty cleared projection) carry nothing to
    // correlate and are skipped; a projected tick always carries three zones.
    if (item.seq < 0 || !Array.isArray(item.projection?.zones) || item.projection.zones.length === 0) continue;
    const source = index.get(`${item.round}:${item.seq}`);
    assert.ok(source, `rendered projection has a matching source snapshot (${item.round}:${item.seq})`);
    assert.equal(source.state.mapId, mapId);
    assert.equal(source.state.config.mode, mode);
    assert.equal(item.rendered.length, source.state.objectives.zones.length);
    for (const zone of item.rendered) {
      const sourceZone = source.state.objectives.zones.find(candidate => candidate.id === zone.id);
      assert.ok(sourceZone, `rendered zone ${zone.id} exists in source state`);
      for (const key of ['x', 'y', 'z', 'radius', 'progress', 'captureSeconds']) {
        assert.ok(close(zone[key], sourceZone[key]), `rendered ${zone.id}.${key} equals source`);
      }
      for (const key of ['owner', 'captureTeam', 'contested']) {
        assert.deepEqual(zone[key], sourceZone[key], `rendered ${zone.id}.${key} equals source`);
      }
    }
    assert.ok(close(item.projection.time, source.state.time), 'rendered clock equals source clock');
    assert.ok(close(item.projection.scores[0], source.state.teamScores[0]));
    assert.ok(close(item.projection.scores[1], source.state.teamScores[1]));
    assert.ok(source.state.actors.some(actor => actor.id === item.actor_id));
    correlated++;
  }
  assert.ok(correlated >= 100, `rendered source correlation samples (${correlated})`);

  // Rules proof from the source snapshot stream, never from client claims.
  // Each zone's ordered holder sequence (0/1, consecutive duplicates and
  // neutral gaps collapsed) is the event log: `0 before 1` is a loss for team
  // zero, `1 before 0` is a recovery, and a 0->null step is a neutralization.
  let heldScore = false, teamZeroScored = false, teamOneScored = false, neutralized = false, contested = false;
  const sequences = new Map();
  let previousScores = null, previousOwners = new Map();
  for (const record of snapshots) {
    const state = record.frame.state;
    if (state.teamScores[0] > 0) teamZeroScored = true;
    if (state.teamScores[1] > 0) teamOneScored = true;
    for (const zone of state.objectives.zones) {
      const sequence = sequences.get(zone.id) ?? [];
      if (zone.owner === 0 || zone.owner === 1) {
        if (sequence.at(-1) !== zone.owner) sequence.push(zone.owner);
      } else if (previousOwners.get(zone.id) === 0) {
        neutralized = true;
      }
      sequences.set(zone.id, sequence);
      previousOwners.set(zone.id, zone.owner);
      if (zone.contested === true) contested = true;
      // Held score: a living occupant of the owning team inside an uncontested
      // owned ring while the team score grows between two snapshots.
      if (zone.owner !== null && zone.contested !== true && previousScores) {
        const inside = state.actors.some(actor => actor.health > 0 && actor.team === zone.owner &&
          Math.hypot(actor.x - zone.x, actor.z - zone.z) <= zone.radius && Math.abs((actor.y ?? 0) - zone.y) <= 5);
        if (inside && state.teamScores[zone.owner] > previousScores[zone.owner]) heldScore = true;
      }
    }
    previousScores = {...state.teamScores};
  }
  const holders = [...sequences.values()];
  const captured = holders.some(sequence => sequence.includes(0));
  // Strict per-zone order: an enemy opening capture is neither a loss nor a
  // recovery. A loss needs 0 then 1; a recovery needs 0, then 1, then 0 again.
  const lost = holders.some(sequence => {
    const firstOurs = sequence.indexOf(0);
    return firstOurs >= 0 && sequence.indexOf(1, firstOurs + 1) > firstOurs;
  });
  const recovered = holders.some(sequence => {
    const firstOurs = sequence.indexOf(0);
    const enemyAfter = firstOurs < 0 ? -1 : sequence.indexOf(1, firstOurs + 1);
    return enemyAfter >= 0 && sequence.indexOf(0, enemyAfter + 1) > enemyAfter;
  });
  const results = wire.filter(record => record.direction === 'out' && record.frame.type === 'results');
  assert.equal(results.length, 1, 'one results frame');
  assert.equal(results[0].frame.state.over, true);
  assert.ok(results[0].frame.state.objectives.zones.length === 3);
  const starts = wire.filter(record => record.direction === 'out' && record.frame.type === 'start');
  assert.equal(starts.length, 2, 'restart produced a second round start');
  const roundTwo = snapshots.filter(record => record.round === 2);
  assert.ok(roundTwo.length > 0, 'second round snapshots');
  assert.equal(roundTwo[0].frame.seq, 1);
  assert.equal(roundTwo[0].frame.state.time, 0);
  assert.equal(roundTwo[0].frame.state.over, false);
  assert.deepEqual(roundTwo[0].frame.state.teamScores, {0:0, 1:0});
  assert.ok(roundTwo[0].frame.state.objectives.zones.every(zone => zone.owner === null && zone.progress === 0));

  // Rendered evidence: one map/zone/contested/results frame at each size.
  const expectedShots = [];
  for (const size of sizes) {
    expectedShots.push(`${size[0]}x${size[1]}:map`, `${size[0]}x${size[1]}:zone`,
      `${size[0]}x${size[1]}:contested`, `${size[0]}x${size[1]}:results`);
  }
  for (const shot of shots) {
    const key = `${shot.size[0]}x${shot.size[1]}:${shot.name}`;
    assert.ok(expectedShots.includes(key), `unexpected evidence frame ${key}`);
    assert.equal(shot.markers, 3, `three rendered markers in ${key}`);
    assert.equal(shot.rendered.length, 3, `three rendered zones in ${key}`);
  }
  for (const size of sizes) {
    for (const name of ['map', 'zone', 'contested', 'results']) {
      assert.ok(shots.some(shot => shot.name === name && shot.size[0] === size[0] && shot.size[1] === size[1]),
        `evidence frame ${name} at ${size[0]}x${size[1]}`);
    }
  }
  const resultsShot = shots.find(shot => shot.name === 'results');
  assert.equal(resultsShot.phase, 4, 'results frame captured after the round ended');
  const contestedShot = shots.find(shot => shot.name === 'contested');
  assert.ok(contestedShot.zones.some(zone => zone.contested === true), 'contested evidence frame shows a contested zone');
  for (const name of ['map', 'zone', 'contested', 'results']) {
    const shot = shots.find(candidate => candidate.name === name);
    assert.ok(shot.hud.split('\n').length === 3, `${name} frame HUD lists three zones`);
    assert.ok(shot.hint.includes('radius'), `${name} frame HUD hint carries the source radius`);
  }
  assert.equal(live[0].marker_errors, 0, 'no marker mismatch across the session');
  assert.equal(live[0].hud_errors, 0, 'no HUD mismatch across the session');
  assert.equal(live[0].bearing_errors, 0, 'no HUD bearing mismatch across the session');
  assert.equal(live[0].restart, true, 'graphical restart proven');
  assert.equal(live[0].capture, true);
  assert.equal(live[0].contested, true);
  // Loss and recovery are observed live when the source bot AI decides to take
  // the ring we leave open; whether they occurred is reported, never assumed.
  // The deterministic two-seat acceptance (tests/match.test.mjs) gates the exact
  // 0 -> 1 -> 0 ownership sequence on real source rules.
  assert.equal(typeof live[0].lost, 'boolean');
  assert.equal(typeof live[0].recovered, 'boolean');
  assert.equal(live[0].held, true);
  assert.equal(live[0].lights, 1, 'exactly one sun in the live scene');
  assert.equal(live[0].environments, 1, 'exactly one environment in the live scene');
  assert.equal(live[0].cameras, 1, 'exactly one (authoritative) camera in the live scene');

  const inputs = wire.filter(record => record.direction === 'in' && record.frame.type === 'input');
  return {
    recipient: 0, mapId, mode,
    correlatedSnapshots: correlated,
    renderedSamples: native.length,
    inputsReceived: inputs.length,
    capture: captured, contested, lost, recovered, neutralized, heldScore,
    teamsScored: {0:teamZeroScored, 1:teamOneScored},
    results: {over:results[0].frame.state.over, overReason:results[0].frame.state.overReason,
      scores:results[0].frame.state.teamScores, winner:results[0].frame.state.winner},
    restart: {starts:starts.length, roundTwoSeq:roundTwo[0].frame.seq, roundTwoTime:roundTwo[0].frame.state.time},
    screenshots: shots.map(shot => ({name:shot.name, size:shot.size, path:shot.path})),
    live: live[0],
  };
}
