import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../');
const read = name => readFileSync(path.join(root, 'godot/lattice', name), 'utf8');
const source = readFileSync(path.join(root, 'game/cocs.mjs'), 'utf8');
for (const [file, snippets] of Object.entries({
  'world_outcomes.gd': ['func final_result(', 'source_time', 'breakCount', 'waves', 'hq', 'unknown', 'floor(float(winner))'],
  'world_telemetry.gd': ['MAX_RECORDS := 128', 'MAX_EVENTS := 32', 'evidence_class', 'participants', 'attribution_unavailable', 'recipient-event', 'observe_events', 'observe_projection', 'order_matches', 'finish_round', 'begin_round', 'source_sequence'],
  'world_session_panel.gd': ['Requested (not confirmed)', 'Source echo:', 'Roles.from_session(config)', 'start_requested', 'restart_requested'],
  'world_commands.gd': ['topology.model(', 'topology.guidance(', 'card replaced; no capture evidence', 'confirm_spend.set_pressed_no_signal(false)', 'capture_legal'],
})) {
  const text = read(file);
  for (const snippet of snippets) assert.ok(text.includes(snippet), `${file} missing ${snippet}`);
}
for (const snippet of ['export function cocsOutcomeSnapshot', 'export function cocsDominanceView', "match?.emit?.('cocs-capture'", 'participants: participants.map(actor => actor.id)']) assert.ok(source.includes(snippet));
assert.ok(!read('world_telemetry.gd').includes('game/') && !read('world_telemetry.gd').includes('server/'));
assert.ok(source.includes("'cocs-order-complete', {team, node: node.id, label: node.label, verb: orderVerb, peerId: orderTask.peerId ?? null, cardId: orderTask.cardId ?? null, contributors: contributors.map(actor => actor.id)"));
console.log('L3 source/API/static checks PASS (not a GDScript parse or rendered test)');
