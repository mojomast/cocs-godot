import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const board=readFileSync(new URL('../../lattice/board.gd',import.meta.url),'utf8');
test('board uses one configured host frame, explicit start, source echo and bounded handshake',()=>{
 for(const symbol of ['SessionOptions.parse(OS.get_cmdline_user_args())','SessionOptions.validate(requested)',
  'session_flow.request_configuration(requested, client)','session_flow.start(client, last_lobby)',
  'session_flow.restart(client, last_lobby)','session_flow.observe_roster(frame, client)',
  'session_flow.observe_start(frame, requested.map, requested.mode)']) assert.ok(board.includes(symbol),symbol);
 assert.ok(!board.includes('client.configure_match('));
 assert.ok(!board.includes('client.send_frame({"type":"start"})'));
 assert.match(board,/if phase in \["connecting", "creating", "configuring", "starting", "joining"\]/);
 assert.ok(!board.includes('"waiting for host"] and Time.get_ticks_msec()'));
 assert.match(board,/start_button.disabled = joining or/);
 assert.match(board,/if phase == "results":\s*var final: Dictionary = client.result_projection/);
});
