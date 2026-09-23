extends SceneTree
# Loopback authority proof for native operator/harness selection. Drives the real
# lobby surface with real key/mouse events against the actual Node authority, then
# reads both identities back out of the authoritative snapshot state.
# Usage: live.gd -- --lobby-menu --role=host|guest --endpoint=ws://127.0.0.1:PORT
#        --operator=<id> --harness=<id> --peer-operator=<id> --peer-harness=<id>
#        --release-file=<path> [--join-room=<room>]
const Loadout = preload("res://ui/loadout.gd")
# Two-party completion barrier: a client that has proven its own view keeps
# serving the peer's snapshot read-back until the Node harness has validated
# BOTH proofs and released this client.
#
# Bound accounting, compiled in on purpose (no env knob): this client may spend
# up to PROOF_DEADLINE_SECONDS proving its own view, so the peer's proof can
# legally land that far after this one. The hold must cover that whole window
# plus RELEASE_HOP_SECONDS for the harness to validate both payloads and write
# the release file, or a slow-but-legal peer gets misreported as this client
# giving up early. The harness's own proof timer (60s default) is wider, so it
# still owns the overall run, and the hold stays finite: a dead harness can
# never orphan the process. The relationship is pinned by
# godot/tests/loadouts/loopback_lifecycle.test.mjs.
const PROOF_DEADLINE_SECONDS := 45.0
const RELEASE_HOP_SECONDS := 5.0
const HOLD_SECONDS := 50.0
var role := "host"
var endpoint := ""
var room := ""
var release_file := ""
var requested_character := Loadout.DEFAULT_CHARACTER
var requested_harness := Loadout.DEFAULT_HARNESS
var peer_character := ""
var peer_harness := ""
var session: Node
var elapsed := 0.0
var hold_deadline := 0.0
var actions: Array = []
var action_index := 0
var pending_rows: Array = []
var connect_queued := false
var lobby_armed := false
var announced_room := false
var started := false
var finished := false

func fail(message: String) -> void:
	if finished: return
	finished = true
	push_error("PORT_LOADOUT_LIVE_FAIL " + message)
	print("PORT_LOADOUT_LIVE_FAIL ", message)
	if is_instance_valid(session): session.client.disconnect_server()
	quit(1)

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
		if arg.begins_with("--join-room="): room = arg.trim_prefix("--join-room=")
		if arg.begins_with("--release-file="): release_file = arg.trim_prefix("--release-file=")
		if arg.begins_with("--operator="): requested_character = arg.trim_prefix("--operator=")
		if arg.begins_with("--harness="): requested_harness = arg.trim_prefix("--harness=")
		if arg.begins_with("--peer-operator="): peer_character = arg.trim_prefix("--peer-operator=")
		if arg.begins_with("--peer-harness="): peer_harness = arg.trim_prefix("--peer-harness=")
	# The port expects a real window: headless defaults to a 64x64 viewport and the
	# CanvasLayer lobby panel then lays out off-screen, so real mouse clicks on
	# its buttons never land. Pin the harness viewport instead of faking input.
	root.size = Vector2i(1280, 800)
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)

func queue_key(code: int) -> void:
	for pressed: bool in [true, false]:
		actions.append(func() -> void:
			var event := InputEventKey.new()
			event.keycode = code
			event.physical_keycode = code
			event.pressed = pressed
			Input.parse_input_event(event))

func queue_click(control: Control) -> void:
	for pressed: bool in [true, false]:
		actions.append(func() -> void:
			var event := InputEventMouseButton.new()
			event.position = control.get_global_rect().get_center()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			Input.parse_input_event(event))

func row_index(choice: Node, id: String) -> int:
	for index: int in choice.item_count:
		if str(choice.get_item_metadata(index)) == id: return index
	return -1

# Real user path: focus the row, then cycle it with Right presses until it lands
# on the requested entry, exactly as a player would. Rows are stepped one at a
# time from _process (see step_rows): a row's presses must never be delivered
# while another row holds focus, and each press needs a frame to be parsed, so
# focus and presses cannot be queued in one burst.
func queue_row_index(choice: Node, target: int) -> void:
	if target < 0 or target >= choice.item_count:
		fail("row has no entry index " + str(target))
		return
	pending_rows.append({"choice": choice, "target": target, "steps": 0})

func step_rows() -> void:
	if pending_rows.is_empty():
		if not connect_queued:
			connect_queued = true
			var menu: Node = session.lobby_menu
			print("PORT_LOADOUT_LIVE_UI ", role, " role_selected=", menu.role.selected,
				" op=", menu.selected_character(), " harness=", menu.selected_harness(),
				" room=", menu.room.text)
			queue_click(menu.connect_button)
		return
	var row: Dictionary = pending_rows[0]
	var choice: Node = row.choice
	if not choice.has_focus():
		choice.grab_focus()
		if not choice.has_focus():
			fail("row never took focus; keys would land on another control: " + str(row.target))
		return
	if int(choice.selected) == int(row.target):
		pending_rows.pop_front()
		return
	if int(row.steps) >= choice.item_count + 2:
		fail("row never reached its target entry " + str(row.target))
		return
	row.steps = int(row.steps) + 1
	queue_key(KEY_RIGHT)

func seated_players() -> int:
	var count := 0
	for player: Dictionary in session.lobby_roster.get("players", []):
		if bool(player.get("connected", false)) and not bool(player.get("spectate", false)): count += 1
	return count

func peer_row() -> Dictionary:
	for player: Dictionary in session.lobby_roster.get("players", []):
		if int(player.get("peerId", -1)) != session.client.peer_id: return player
	return {}

func actor_of(state: Dictionary, actor_id: int) -> Dictionary:
	for actor: Dictionary in state.get("actors", []):
		if int(actor.get("id", -1)) == actor_id: return actor
	return {}

func start_lobby() -> void:
	lobby_armed = true
	var menu: Node = session.lobby_menu
	var expected := Loadout.resolve(requested_character, requested_harness)
	# The CLI pair reached the session before any UI interaction.
	if session.selected_character != expected.character or session.selected_harness != expected.harness:
		fail("CLI pair not applied: %s/%s expected %s/%s" % [session.selected_character, session.selected_harness, expected.character, expected.harness])
		return
	menu.endpoint.text = endpoint
	menu.player_name.text = "Host" if role == "host" else "Guest"
	if role == "guest":
		if room.is_empty():
			fail("guest needs --join-room")
			return
		menu.room.text = room
		queue_row_index(menu.role, 1)
	# Exercise actual selection, not just the CLI-preselected values: move both
	# rows to the source defaults with keys, then choose the requested pair.
	queue_row_index(menu.operator, row_index(menu.operator, Loadout.DEFAULT_CHARACTER))
	queue_row_index(menu.harness, row_index(menu.harness, Loadout.DEFAULT_HARNESS))
	queue_row_index(menu.operator, row_index(menu.operator, expected.character))
	queue_row_index(menu.harness, row_index(menu.harness, expected.harness))
	# The connect click is queued by step_rows() once every row has settled.

func verify_lobby() -> void:
	var menu: Node = session.lobby_menu
	var expected := Loadout.resolve(requested_character, requested_harness)

	var self_row := {}
	for player: Dictionary in session.lobby_roster.get("players", []):
		if int(player.get("peerId", -1)) == session.client.peer_id: self_row = player
	if self_row.is_empty():
		fail("roster has no self row")
		return
	if str(self_row.get("character", "")) != expected.character or str(self_row.get("harness", "")) != expected.harness:
		fail("authority echo mismatch for self: " + str(self_row))
		return
	if not menu.roster.text.contains(Loadout.label(expected.character, expected.harness)):
		fail("lobby roster text does not show the local authority pair")
		return
	var peer := peer_row()
	if peer.is_empty():
		fail("roster has no peer row")
		return
	var peer_expected := Loadout.resolve(peer_character, peer_harness)
	if str(peer.get("character", "")) != peer_expected.character or str(peer.get("harness", "")) != peer_expected.harness:
		fail("authority echo mismatch for the other player: " + str(peer))
		return
	if not menu.roster.text.contains(Loadout.label(peer_expected.character, peer_expected.harness)):
		fail("lobby roster text does not show the other player's pair")
		return
	if role == "host":
		if not session.lobby_host_allowed():
			fail("host lost host rights before start")
			return
		if not started:
			started = true
			actions.append(func() -> void:
				var button: Button = menu.start_button
				print("PORT_LOADOUT_LIVE_START_UI visible=", button.visible, " disabled=", button.disabled,
					" rect=", button.get_global_rect(), " panel=", menu.panel.get_global_rect(),
					" viewport=", menu.get_viewport().get_visible_rect().size, " phase=", session.phase))
			queue_click(menu.start_button)
			actions.append(func() -> void:
				print("PORT_LOADOUT_LIVE_START_AFTER phase=", session.phase, " label=", session.label.text))

func verify_match() -> void:
	var state: Dictionary = session.client.snapshots[-1].state
	var own_id: int = session.client.actor_id
	if own_id < 0:
		fail("no actor assignment in the round")
		return
	var expected := Loadout.resolve(requested_character, requested_harness)
	var mine := actor_of(state, own_id)
	if mine.is_empty():
		fail("snapshot has no local actor " + str(own_id))
		return
	if str(mine.get("character", "")) != expected.character or str(mine.get("harness", "")) != expected.harness:
		fail("snapshot identity mismatch for the local actor: " + str(mine))
		return
	var peer := peer_row()
	var peer_id: int = int(peer.get("actorId", -1)) if peer.get("actorId") != null else -1
	if peer_id < 0:
		fail("other player has no actor seat in the round")
		return
	var peer_expected := Loadout.resolve(peer_character, peer_harness)
	var other := actor_of(state, peer_id)
	if other.is_empty():
		fail("snapshot has no peer actor " + str(peer_id))
		return
	if str(other.get("character", "")) != peer_expected.character or str(other.get("harness", "")) != peer_expected.harness:
		fail("snapshot identity mismatch for the other actor: " + str(other))
		return
	if expected.character == peer_expected.character and expected.harness == peer_expected.harness:
		fail("proof requires two different pairs")
		return
	finished = true
	hold_deadline = elapsed + HOLD_SECONDS
	print("PORT_LOADOUT_LIVE_OK ", JSON.stringify({
		"role":role, "room":session.client.room_id, "peer_id":session.client.peer_id,
		"actor_id":own_id, "requested":expected, "snapshot_self":str(mine.get("character", "")) + "/" + str(mine.get("harness", "")),
		"peer_peer_id":int(peer.get("peerId", -1)), "peer_actor_id":peer_id, "peer_requested":peer_expected,
		"snapshot_peer":str(other.get("character", "")) + "/" + str(other.get("harness", "")),
		"seated":seated_players(), "health":float(mine.get("health", 0.0))}))
	# Stay connected until BOTH observers have reported and the Node harness has
	# validated both payloads; quitting here races the other client's first
	# snapshot/roster and evicts this actor from the authority.
	print("PORT_LOADOUT_LIVE_HELD ", role, " release_file=", release_file)

func _process(delta: float) -> bool:
	elapsed += delta
	if finished:
		# The harness owns the release, so a released client exits 0 on its own
		# and teardown stays a verified handshake instead of a race.
		if not release_file.is_empty() and FileAccess.file_exists(release_file):
			print("PORT_LOADOUT_LIVE_RELEASED ", role)
			quit(0)
			return true
		if elapsed > hold_deadline:
			push_error("PORT_LOADOUT_LIVE_FAIL release never arrived role=" + role)
			print("PORT_LOADOUT_LIVE_FAIL release never arrived role=" + role)
			quit(1)
			return true
		return false
	if elapsed > PROOF_DEADLINE_SECONDS:
		fail("timeout role=" + role + " phase=" + str(session.phase) + " label=" + str(session.label.text))
		return true
	if not is_instance_valid(session):
		fail("session vanished")
		return true
	if session.phase == -1:
		fail("session error: " + str(session.label.text))
		return true
	if action_index < actions.size():
		var action: Callable = actions[action_index]
		action_index += 1
		action.call()
		return false
	if not is_instance_valid(session.lobby_menu): return false
	if session.phase == -3 and not lobby_armed and session.lobby_menu.connect_button.visible:
		start_lobby()
		return false
	if session.phase == -3:
		step_rows()
		return false
	if not announced_room and not session.client.room_id.is_empty():
		announced_room = true
		print("PORT_LOADOUT_ROOM ", session.client.room_id)
	if session.phase in [11, 12] and seated_players() >= 2:
		verify_lobby()
		return false
	if session.phase == 3 and session.client.snapshots.size() > 0:
		verify_match()
		return false
	return false
