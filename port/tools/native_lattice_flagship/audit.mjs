/** Recipient-only evidence audit. No private Room/Match access or inferred success. */
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';

const finite = n => typeof n === 'number' && Number.isFinite(n);
const record = (rows, kind) => rows.filter(r => r.kind === kind);
const same = (a, b) => a !== undefined && a !== null && a === b;

export function audit({manifest, wire, native = [], cleanup = {}}) {
 const failures = [], checks = {};
 const requireFact = (name, value, reason) => { checks[name] = !!value; if (!value) failures.push(`${name}: ${reason}`); };
 requireFact('provenance', !!manifest?.source_commit && !!manifest?.input_sha256 && manifest.evidence_class === 'ordinary-wire', 'pin/hash/class missing');
 requireFact('cleanup', cleanup.children_waited === true && cleanup.server_closed === true && cleanup.temp_removed === true, 'owned resources not proven closed');
 requireFact('recipient', Array.isArray(wire) && wire.some(r => r.direction === 'recipient') && wire.every(r => ['recipient','client'].includes(r.direction) && finite(r.elapsed_ms) && r.frame && typeof r.frame.type === 'string'), 'unbounded/private or malformed record');
 if (!Array.isArray(wire)) wire = [];
 const outgoing=wire.filter(r=>r.direction==='client');
  requireFact('ordinary_outgoing', outgoing.every(r=>['input','host','start','join','create','order','economy'].includes(r.frame.type)), 'privileged state mutation on observed socket');
 wire=wire.filter(r=>r.direction==='recipient');
 const starts = record(wire, 'start'), snapshots = record(wire, 'snapshot'), events = record(wire, 'events'), results = record(wire, 'results');
 const start = starts[0]?.frame, final = results.at(-1)?.frame;
 const rev = start?.roundRevision;
 const welcome=record(wire,'welcome')[0]?.frame;
 const assigned=record(wire,'lobby').filter(r=>r.elapsed_ms<=starts[0]?.elapsed_ms).at(-1)?.frame?.players?.find(p=>same(p.peerId,welcome?.peerId));
 requireFact('local_identity', Number.isInteger(welcome?.peerId) && Number.isInteger(assigned?.actorId), 'local peer-to-actor assignment not recipient-published');
 requireFact('source_config', !!start && Number.isInteger(rev) && rev > 0 && ['cocs','cocs-coop'].includes(start.config?.mode) && ['asterion-relay','monsoon-foundry'].includes(start.mapId) && finite(start.config?.timeLimit) && start.config.timeLimit >= 60 && start.config.timeLimit <= 900 && start.mapId === manifest?.map && start.config.mode === manifest?.mode, 'no validated source start/map/mode/limit/revision');
 const live = snapshots.filter(r => r.frame?.state?.cocs?.roundRevision === rev && r.frame.state.mapId === start?.mapId);
 requireFact('live_snapshots', live.length >= 2 && live.some(r => finite(r.frame.state.time) && r.frame.state.time > 0), 'no active authoritative progression');
 const end = final?.state;
  const naturalResult = !!end && end.over === true && end.mapId === start?.mapId && finite(end.time) && end.time > 0 && (end.winner === null || end.winner === 0 || end.winner === 1) && typeof end.overReason === 'string' && end.overReason.length > 0 && results.at(-1).elapsed_ms > starts[0].elapsed_ms;
  requireFact('natural_result', naturalResult, 'ACK/timeout is not a source result');
   const localTeam = snapshots.flatMap(r => r.frame?.state?.actors ?? []).find(a => a.id === assigned?.actorId)?.team;
   const defeat = naturalResult && (localTeam === 0 || localTeam === 1) && end.winner !== null && end.winner !== localTeam;
   checks.natural_defeat = defeat;
   checks.local_team_published = localTeam === 0 || localTeam === 1;
  const ownership = new Map(),changedNodes=new Set(); let changed = false;
 for (const r of live) for (const node of r.frame.state.cocs.nodes ?? []) {
  if (!node || typeof node.id !== 'string') continue;
   if (ownership.has(node.id) && ownership.get(node.id) !== node.owner) {changed = true;changedNodes.add(node.id)}
  ownership.set(node.id, node.owner);
 }
 const captures = events.filter(r=>r.elapsed_ms>=starts[0]?.elapsed_ms && r.elapsed_ms<=results.at(-1)?.elapsed_ms).flatMap(r => r.frame.items ?? []).filter(e => e?.type === 'cocs-capture');
  const captured = changed && captures.length > 0;
  const actors = new Set(live.flatMap(r => (r.frame.state.actors ?? []).map(a => a.id)));
   const attributedCapture = actors.has(assigned?.actorId) && captures.some(e => Array.isArray(e.participants) && e.participants.includes(assigned?.actorId));
  const issuedOrders=outgoing.filter(r=>r.frame.type==='order'&&r.elapsed_ms>=starts[0]?.elapsed_ms&&r.elapsed_ms<=results.at(-1)?.elapsed_ms&&r.frame.roundRev===rev&&typeof r.frame.cardId==='string');
  const completions=events.filter(r=>r.elapsed_ms>=starts[0]?.elapsed_ms&&r.elapsed_ms<=results.at(-1)?.elapsed_ms).flatMap(r=>r.frame.items??[]).filter(e=>e?.type==='cocs-order-complete');
  const attributedOrder=actors.has(assigned?.actorId)&&completions.some(e=>String(e.peerId)===String(assigned.actorId)&&changedNodes.has(e.node)&&captures.some(c=>c.node===e.node&&c.team===e.team)&&issuedOrders.some(o=>o.frame.cardId===e.cardId&&o.frame.target===e.node));
  const useful=attributedCapture||attributedOrder;
 const ordinaryNative = Array.isArray(native) ? native.filter(n => n?.event === 'input_queue' && n.method === 'engine' && n.source_revision === rev && Number.isInteger(n.actor_id) && n.queued === true) : [];
 requireFact('native_input', ordinaryNative.some(n=>n.actor_id===assigned?.actorId), 'no versioned local engine-input trace on this revision');
  const ui = Array.isArray(native) ? native.filter(n => n?.kind === 'ui' && n.source_revision === rev && n.observed === true) : [];
  requireFact('native_ui', ui.some(n => typeof n.reviewer === 'string' && n.reviewer.trim() && typeof n.screenshot === 'string' && n.screenshot.trim() && Number.isInteger(n.actor_id) && n.actor_id === assigned?.actorId && n.round_revision === rev), 'UI evidence needs reviewer, screenshot provenance, exact local actor and round');
 if (start?.config?.rung) requireFact('human_rung', manifest?.participants?.every(p => p.kind === 'human' && p.consent === true) && manifest.participants.length >= 8, 'socket seats cannot prove a human rung');
  if (manifest?.mode === 'cocs-coop') requireFact('fifth_wave', !!end?.cocs?.outcome && end.cocs.outcome.waves?.cleared === 5, 'wave-one/ACK/timeout is not a five-wave clear');
  requireFact('restart', starts.some((r,i) => i > 0 && r.frame.roundRevision > rev) && snapshots.some(r => r.frame.state?.cocs?.roundRevision > rev), 'new source round revision and active snapshot required');
   const sharedFailures=failures.filter(f=>!f.startsWith('fifth_wave:'));
   const commonBlocked = sharedFailures.length > 0;
   const positiveBlocked = commonBlocked || checks.fifth_wave === false || !captured || !useful;
    return {schema_version: 2, claim: positiveBlocked ? 'BLOCKED' : 'PASS',
     claims: {positive_capture: positiveBlocked ? 'BLOCKED' : 'PASS', natural_defeat: commonBlocked || !defeat ? 'BLOCKED' : 'PASS'},
    checks: {...checks, capture: captured, attributed_capture: attributedCapture, attributed_order_effect:attributedOrder, local_useful_contribution:useful}, failures: [...failures, ...(!captured ? ['capture: source capture event AND owner transition required'] : []), ...(!useful ? ['local_useful_contribution: no matched capture participant or exact source order completion/card/actor/round/node'] : [])],
  counts: {starts:starts.length, snapshots:snapshots.length, events:events.length, results:results.length, native_inputs:ordinaryNative.length}};
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
 const dir = process.argv[2];
 if (!dir) {console.error('Usage: node audit.mjs ATTEMPT_DIRECTORY'); process.exitCode = 2;}
 else {
  const json = name => JSON.parse(readFileSync(`${dir}/${name}.json`, 'utf8'));
  const jsonl = name => readFileSync(`${dir}/${name}.jsonl`, 'utf8').trim().split('\n').filter(Boolean).map(JSON.parse);
  const result = audit({manifest:json('manifest'), wire:jsonl('wire'), native:jsonl('native'), cleanup:json('cleanup')});
  console.log(JSON.stringify(result,null,2));
  if (result.claim !== 'PASS') process.exitCode = 1;
 }
}
