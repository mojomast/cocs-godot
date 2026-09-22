// Identity-family Horde acceptance validator.
//
// Reuses the delivered Horde correlation/hygiene checks (recipient snapshot
// correlation, HUD projection, rendered identity, layout, source trace
// completion) and adds the identity-family claims: Nacre Engine composition
// through identity_maps/map.gd, one sun and one environment, genuine multi-wave
// progression, natural defeat, clean restart and the measured capsule corridor.
import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, existsSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {dirname, resolve, basename} from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {validate, validateHygiene, validateRun} from '../native-horde/validate.mjs';
import {SOURCE_CAPSULE, NAV_PROBE_WIDTH, verdictFor} from './measure.mjs';

export const EXPECTED_PRODUCT = Object.freeze({
  scene: 'res://native_arenas/identity_horde_demo.tscn',
  script: 'res://native_arenas/identity_horde_demo.gd',
});

const lines = (stdout, prefix) => stdout.split('\n').filter(line => line.startsWith(prefix))
  .map(line => JSON.parse(line.slice(prefix.length)));

function assertEnemiesApproach(states, label) {
  // A wave is a genuine approach when at least one living NPC closed distance to
  // the player across consecutive accepted snapshots of that wave.
  const perWave = new Map();
  for (const state of states) {
    const wave = state.singleplayer?.wave ?? 0;
    const local = (state.actors ?? []).find(actor => actor.id === 0);
    if (!local || local.health <= 0) continue;
    const enemies = (state.actors ?? []).filter(actor => actor.isNpc === true && actor.health > 0);
    if (!enemies.length) continue;
    const nearest = Math.min(...enemies.map(actor => Math.hypot(actor.x - local.x, actor.z - local.z)));
    if (!perWave.has(wave)) perWave.set(wave, []);
    perWave.get(wave).push(nearest);
  }
  const closed = [];
  for (const [wave, distances] of perWave) {
    if (distances.length < 3) continue;
    if (distances.at(-1) < distances[0] - 1) closed.push({wave, from: distances[0], to: distances.at(-1), samples: distances.length});
  }
  assert(closed.length > 0, `${label}: no wave showed living NPCs closing distance to the player`);
  return closed;
}

export function validateIdentityRun({wire, stdout, stderr, summary, launch, corridors}) {
  assert.equal(summary.scenario, launch.scenario, 'summary/launch scenario mismatch');
  assert.equal(launch.map, 'nacre-engine', 'identity launch map');
  assert.equal(launch.localOnly, true, 'identity launch must be local-only');
  // The delivered Horde hygiene and correlation checks, unchanged.
  assert.equal(summary.exit, 0, 'identity harness failed');
  assert.equal(summary.serverClosed, true, 'listener leaked');
  assert.equal(summary.sockets, 0, 'sockets leaked');
  assert.equal(summary.temporaryTreeRemoved, true, 'private XDG leaked');
  validateHygiene(summary, stdout, stderr);
  const base = validateRun({wire, stdout, stderr, summary, launch, expected: EXPECTED_PRODUCT});

  const product = lines(stdout, 'IDENTITY_PRODUCT ');
  assert.equal(product.length, 1, 'identity product census missing/duplicated');
  const census = product[0];
  assert.equal(census.scene, EXPECTED_PRODUCT.scene, 'identity composition scene');
  assert.equal(census.script, EXPECTED_PRODUCT.script, 'identity composition script');
  assert.equal(census.map, 'nacre-engine', 'identity composition map');
  assert.equal(census.mode, 'horde', 'identity composition mode');
  assert.equal(census.suns, 1, 'identity composition must expose exactly one sun');
  assert.equal(census.environments, 1, 'identity composition must expose exactly one WorldEnvironment');
  assert.equal(census.horde_label_passive, true, 'Horde strip must stay passive');

  const snapshots = wire.filter(record => record.direction === 'out' && record.frame.type === 'snapshot').map(record => record.frame.state);
  const waveTelemetry = lines(stdout, 'IDENTITY_WAVE ');
  const clearedTelemetry = lines(stdout, 'IDENTITY_CLEARED ');
  const upgradeTelemetry = lines(stdout, 'IDENTITY_UPGRADE ');
  const waveSummary = lines(stdout, 'IDENTITY_WAVES ').at(-1);
  const cadence = lines(stdout, 'IDENTITY_CADENCE ').at(-1);
  const restart = lines(stdout, 'IDENTITY_RESTART ').at(-1);
  const layouts = lines(stdout, 'HORDE_LAYOUT ');
  const sizes = [[960, 640], [1280, 800]];
  // Capture sizes are part of the evidence: each tag is captured at the launch
  // resolution and its -alternate sibling at the other product size.
  const [launchWidth, launchHeight] = launch.resolution.split('x').map(Number);
  const baseSize = [launchWidth, launchHeight], otherSize = launchWidth < 1000 ? [1280, 800] : [960, 640];
  const byTag = new Map(layouts.map(entry => [entry.tag, entry.viewport]));
  for (const [tag, viewport] of byTag) {
    if (tag.endsWith('-alternate')) {
      assert(byTag.has(tag.slice(0, -'-alternate'.length)), `alternate capture ${tag} has no primary capture`);
      assert.deepEqual(viewport, otherSize, `alternate capture ${tag} at ${viewport}, expected ${otherSize}`);
    } else if (byTag.has(`${tag}-alternate`)) {
      assert.deepEqual(viewport, baseSize, `primary capture ${tag} at ${viewport}, expected ${baseSize}`);
    }
  }

  assert(snapshots.some(state => state.singleplayer.wave >= 1 && state.singleplayer.enemiesAlive > 0), 'no real wave with enemies');
  const approaches = assertEnemiesApproach(snapshots, summary.scenario);

  // Corridor measurement: the enemy capsule the source actually moves, the
  // static graph width, and the minimum width live NPCs actually traversed.
  assert(corridors?.static, 'static corridor measurement missing');
  assert.equal(corridors.static.capsule.radius, SOURCE_CAPSULE.radius, 'capsule radius drift');
  assert.equal(corridors.static.capsule.neededWidth, 0.84, 'capsule width drift');
  assert.equal(corridors.static.nav.edgesBelowCapsule, 0, 'an accepted nav edge is narrower than the enemy capsule');
  assert(corridors.static.nav.narrowestEdgeWidth >= NAV_PROBE_WIDTH - 1e-6, 'nav edge below the bake probe width');
  assert(corridors.static.capsule.source.includes('identical for humans and NPCs'), 'capsule source note');
  const traversed = corridors.traversed;
  assert(traversed && traversed.npcCount > 0, 'no NPC traversal measured');
  // Clearance: the closest any living NPC's capsule came to geometry. It can
  // never be below its own radius, and contact (0.42) is recorded as such.
  assert(traversed.minimumTraversed && traversed.minimumTraversed.clearance >= SOURCE_CAPSULE.radius - 1e-3,
    `traversed clearance below the enemy capsule: ${traversed.minimumTraversed?.clearance}`);
  // Corridor: the narrowest channel the NPCs actually moved through.
  assert(traversed.tightestChannel && traversed.tightestChannel.channelWidth >= SOURCE_CAPSULE.neededWidth,
    `traversed corridor narrower than the enemy capsule: ${traversed.tightestChannel?.channelWidth}`);
  const open = [];
  if (summary.scenario === 'startup') {
    assert(!snapshots.some(state => state.over), 'startup must not claim a completed match');
    assert(layouts.some(entry => JSON.stringify(entry.viewport) === JSON.stringify(sizes[0])), 'wave picture missing');
  }
  if (summary.scenario === 'waves') {
    const finished = wire.find(record => record.direction === 'out' && record.frame.type === 'results');
    assert(finished, 'no results frame');
    assert.equal(finished.frame.state.over, true, 'results must finish the round');
    assert.equal(finished.frame.state.singleplayer.phase, 'won', `wave-target run must win (got ${finished.frame.state.singleplayer.phase})`);
    assert.equal(finished.frame.state.singleplayer.winner, 0, 'winner zero is a valid win');
    assert.equal(finished.frame.state.singleplayer.wave, launch.waves, 'victory must land on the configured wave target');
    assert(clearedTelemetry.length >= Math.max(1, launch.waves - 1), 'cleared waves not observed');
    assert(waveTelemetry.length >= launch.waves, 'wave telemetry incomplete');
    // The source publishes a pending upgrade choice from the wave-3 clear
    // onward. Bounded targets of four or more waves therefore must project one;
    // a three-wave win supersedes it, which is reported rather than hidden.
    if (launch.waves >= 4) {
      assert(upgradeTelemetry.length >= 1, 'no wave-clear upgrade offer projected');
    } else {
      open.push('no wave-clear upgrade offer at this target (the win supersedes the wave-3 offer)');
    }
    assert(upgradeTelemetry.every(entry => entry.selection_supported === false), 'identity adapter must not claim upgrade selection');
    const scores = clearedTelemetry.map(entry => entry.score);
    for (let index = 1; index < scores.length; index++) assert(scores[index] > scores[index - 1], 'wave-clear score must increase');
    assert(restart && restart.results === 1 && restart.rounds === 2 && restart.captured === false, 'clean restart after victory');
    for (const size of sizes) {
      assert(layouts.some(entry => JSON.stringify(entry.viewport) === JSON.stringify(size)), `missing picture at ${size}`);
    }
    assert(layouts.filter(entry => entry.tag.startsWith('results') && entry.scoreboard_visible).length >= 2, 'results scoreboard not seen at both sizes');
  }
  if (summary.scenario === 'defeat') {
    const finished = wire.find(record => record.direction === 'out' && record.frame.type === 'results');
    assert(finished, 'no results frame');
    assert.equal(finished.frame.state.over, true, 'results must finish the round');
    assert.equal(finished.frame.state.singleplayer.phase, 'lost', `defeat run must lose (got ${finished.frame.state.singleplayer.phase})`);
    assert.notEqual(finished.frame.state.singleplayer.winner, 0, 'defeat must not report winner zero');
    assert.equal(finished.frame.state.singleplayer.lives, 0, 'defeat must end with zero lives');
    // Authoritative death accounting: the source's own counters and events.
    assert.equal(finished.frame.state.singleplayer.deaths, 3, 'three source deaths required');
    assert.equal((finished.frame.state.actors.find(actor => actor.id === 0) ?? {}).deaths, 3, 'local actor death count drift');
    const deaths = lines(stdout, 'IDENTITY_LIFE ');
    const events = wire.filter(record => record.direction === 'out' && record.frame.type === 'events').flatMap(record => record.frame.items);
    const kills = events.filter(event => event.type === 'death' && event.actor === 0 && event.killer !== 0 && event.self !== true);
    assert.equal(kills.length, 3, `three genuine source deaths of the local actor required, saw ${kills.length}`);
    assert(new Set(kills.map(event => event.killer)).size >= 2, 'expected more than one distinct enemy killer');
    const lifeEvents = events.filter(event => event.type === 'singleplayer-life').map(event => event.lives);
    assert.deepEqual(lifeEvents, [2, 1, 0], `source life sequence ${JSON.stringify(lifeEvents)}`);
    assert(deaths.length >= 2, `respawn/life telemetry too thin: ${deaths.length}`);
    assert(restart && restart.lives === 3 && restart.rounds === 2 && restart.captured === false, 'fresh round after defeat');
    for (const size of sizes) {
      assert(layouts.some(entry => JSON.stringify(entry.viewport) === JSON.stringify(size)), `missing picture at ${size}`);
    }
    assert(layouts.some(entry => entry.tag === 'defeat' || entry.tag === 'defeat-alternate'), 'no defeat picture');
    assert(layouts.filter(entry => entry.tag.startsWith('results') && entry.scoreboard_visible).length >= 2, 'results scoreboard not seen at both sizes');
  }
  if (summary.scenario === 'peak') {
    assert(cadence, 'missing cadence report');
    assert(cadence.samples >= 100, `cadence samples too few: ${cadence.samples}`);
    assert(cadence.peak_alive >= 4, `peak simultaneous NPCs too low: ${cadence.peak_alive}`);
    assert(cadence.fps_min > 0 && cadence.fps_median > 0, 'cadence must be measured, not assumed');
    assert(cadence.snapshots_applied_high_water > 0 && cadence.snapshots_received > 0, 'no source frames were applied');
    // Peak load must not collapse cadence below the run's own baseline. The
    // absolute number belongs to the software-Xvfb environment and is reported,
    // never asserted as a hardware claim.
    if (cadence.fps_at_peak_samples >= 5 && cadence.fps_avg > 0) {
      const ratio = cadence.fps_at_peak_avg / cadence.fps_avg;
      assert(ratio >= 0.5, `cadence collapsed under peak load: ${ratio}`);
      open.push(`peak-load cadence ${cadence.fps_at_peak_avg.toFixed(1)} fps at ${cadence.peak_alive} simultaneous NPCs vs ${cadence.fps_avg.toFixed(1)} fps overall (software Xvfb, no GPU)`);
    }
    assert(clearedTelemetry.length >= 1, 'peak run must clear at least one wave');
    for (const size of [[cadence.resolution[0], cadence.resolution[1]]]) assert(size[0] >= 960, 'peak resolution');
    open.push(...['endless (no adapter contract)', 'boss wave (not reached inside the bound)', 'ten-wave completion (not reached inside the bound)']);
  }
  return {
    status: 'PASS', scenario: summary.scenario, map: launch.map, waves: launch.waves,
    correlated: base.correlated, receipts: base.receipts, ackHighWater: base.ackHighWater,
    steppedSamples: base.steppedSamples, clockDiagnostic: base.clockDiagnostic,
    wavesSeen: waveTelemetry.length, cleared: clearedTelemetry.length,
    upgradeOffers: upgradeTelemetry.length, approaches,
    capsule: corridors.static.capsule, navNarrowestEdgeWidth: corridors.static.nav.narrowestEdgeWidth,
    approachMinWidth: corridors.static.narrowestApproach?.minWidth ?? null,
    traversedMinimum: traversed.minimumTraversed, traversedChannel: traversed.tightestChannel, cadence,
    waveSummary, open, nativeTraceCompletionProven: true, productComposition: true,
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const directory = resolve(process.argv[2] ?? dirname(fileURLToPath(import.meta.url)));
  const read = name => gunzipSync(readFileSync(resolve(directory, `${name}.gz`))).toString();
  const corridorsPath = resolve(directory, 'corridors.json');
  const result = validateIdentityRun({
    wire: read('wire.jsonl').trim().split('\n').filter(Boolean).map(JSON.parse),
    stdout: read('native.stdout.log'), stderr: read('native.stderr.log'),
    summary: JSON.parse(readFileSync(resolve(directory, 'summary.json'), 'utf8')),
    launch: JSON.parse(readFileSync(resolve(directory, 'launch.json'), 'utf8')),
    corridors: existsSync(corridorsPath) ? JSON.parse(readFileSync(corridorsPath, 'utf8')) : null,
  });
  writeFileSync(resolve(directory, 'validation.json'), `${JSON.stringify(result, null, 2)}\n`);
  console.log(JSON.stringify({status: result.status, scenario: result.scenario, cleared: result.cleared,
    traversedMinimum: result.traversedMinimum, open: result.open}));
}
