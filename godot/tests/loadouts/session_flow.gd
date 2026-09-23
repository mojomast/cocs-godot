extends SceneTree
# Session wiring: the setup surface and the lobby both hand their selected
# operator/harness to create/join, the authority echo is checked, and restart /
# guest paths stay unchanged. Detached construction mirrors the existing
# protocol tests; no network is touched.
const Session = preload("res://world/session.gd")
const Setup = preload("res://ui/match_setup.gd")
const Network = preload("res://net/client.gd")
var checks := 0
var failures := 0
var session: Node
var probe: Probe

class Probe extends Network:
	var frames: Array[Dictionary] = []
	var connects: Array[String] = []
	func connect_server(endpoint: String, maps: Dictionary, map_id: String) -> Error:
		connects.append(endpoint)
		allowlist = maps
		requested_map = map_id
		if not allowlist.has(map_id):
			fail("Requested map is not allowlisted")
			return ERR_INVALID_PARAMETER
		return OK
	func send_frame(frame: Dictionary) -> Error:
		frames.append(frame.duplicate(true))
		return OK
	func types() -> Array:
		var out: Array = []
		for frame: Dictionary in frames: out.append(frame.type)
		return out

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("LOADOUT_SESSION " + message)

func _initialize() -> void: call_deferred("run")

# Detached session with an offline frame probe, as used by the existing
# guest-session test. Mirrors that construction so nothing here depends on a
# live socket or the running scene.
func build(kind: String) -> void:
	if is_instance_valid(session): session.free()
	session = Session.new()
	session.client.free()
	probe = Probe.new()
	session.client = probe
	for node: Node in [session.camera, session.label, session.selector, session.environment, session.sun, session.client, session.presentation, session.pickups, session.combat, session.combat_label]:
		session.add_child(node)
	# A detached session has no launcher endpoint; the probe records the connect
	# instead of opening a socket (mirrors the existing guest-session fixture).
	session.endpoint = "ws://127.0.0.1:9"
	check(session.catalog.open(), kind + ": locked catalog opens")
	check(session.load_map("meridian-exchange"), kind + ": locked map loads")

func run() -> void:
	# 1. Combat setup: the menu pair reaches the create frame.
	build("setup")
	check(session.selected_character == "chatgpt" and session.selected_harness == "openclaw", "setup default pair on the session")
	session.phase = -2
	var menu := Setup.new()
	menu.configure(session.catalog.entries, "meridian-exchange", "deathmatch", "grok", "cline")
	session.add_child(menu)
	session.setup_menu = menu
	session.start_selected_match("meridian-exchange", "deathmatch")
	check(session.phase == 0, "start_selected_match advances to connect")
	session.begin_room()
	check(probe.frames.size() == 1 and probe.frames[0].type == "create", "setup path sends one create frame")
	check(probe.frames[0].character == "grok" and probe.frames[0].harness == "cline", "setup pair reaches the create frame: " + str(probe.frames[0]))
	check(session.selected_character == "grok" and session.selected_harness == "cline", "session records the setup pair")

	# 2. Lobby host: explicit pair, authority echo verification, restart safety.
	build("lobby-host")
	check(session.selected_character == "chatgpt" and session.selected_harness == "openclaw", "lobby default pair on the session")
	session.lobby_enabled = true
	session.phase = -3
	session.lobby_connect("ws://127.0.0.1:9", "Host", "", "meridian-exchange", "deathmatch", false, "deepseek", "hermes")
	check(session.phase == 0 and probe.connects.size() == 1, "host lobby connect reaches the peer")
	session.phase = 1
	session.client.peer_id = 1
	session.begin_room()
	check(probe.frames[-1].type == "create", "host lobby create queued")
	check(probe.frames[-1].character == "deepseek" and probe.frames[-1].harness == "hermes", "host lobby pair reaches the create frame: " + str(probe.frames[-1]))
	var roster := {"type":"lobby", "roomId":"room-1", "hostId":1, "players":[{"peerId":1, "actorId":0, "character":"deepseek", "harness":"hermes", "connected":true, "spectate":false}]}
	check(session.client.decode_text(JSON.stringify(roster)), "matching authority roster accepted")
	check(session.client.assigned_character == "deepseek" and session.client.assigned_harness == "hermes", "client records the authority identity")
	session.on_lobby(roster)
	check(session.phase == 2, "matching echo advances the host handshake")
	check(session.selected_character == "deepseek" and session.selected_harness == "hermes", "matching echo keeps the pair")
	# Restart never re-sends create/join and never touches identity.
	var before: int = probe.frames.size()
	session.phase = 4
	session.request_restart()
	check(probe.frames.size() == before + 1 and probe.frames[-1].type == "start", "restart sends only the start frame")
	check(probe.types().count("create") == 1 and probe.types().count("join") == 0, "restart re-sends no identity frame")
	# A substitution must fail loudly instead of being silently followed.
	var substituted := {"type":"lobby", "roomId":"room-1", "hostId":1, "players":[{"peerId":1, "actorId":0, "character":"chatgpt", "harness":"openclaw", "connected":true, "spectate":false}]}
	check(session.client.decode_text(JSON.stringify(substituted)), "substituted roster envelope accepted")
	session.on_lobby(substituted)
	check(session.phase == -1, "substituted identity cancels the session")
	check(session.label.text.contains("operator/harness"), "substitution error names the operator/harness contract: " + session.label.text)

	# 3. Lobby guest: own pair; legacy six-argument call keeps the source defaults.
	build("lobby-guest")
	session.lobby_enabled = true
	session.phase = -3
	session.join_room_id = "room-9"
	session.lobby_connect("ws://127.0.0.1:9", "Guest", "room-9", "meridian-exchange", Setup.DEFAULT_MODE, true, "mistral", "codex")
	session.phase = 10
	session.client.peer_id = 2
	session.begin_room()
	check(probe.frames[-1].type == "join" and probe.frames[-1].roomId == "room-9", "guest join queued")
	check(probe.frames[-1].character == "mistral" and probe.frames[-1].harness == "codex", "guest pair reaches the join frame: " + str(probe.frames[-1]))
	check(probe.frames[-1].name == "Guest", "guest name unchanged")
	var guest_roster := {"type":"lobby", "roomId":"room-9", "hostId":1, "players":[{"peerId":2, "actorId":1, "character":"mistral", "harness":"codex", "connected":true, "spectate":false}]}
	session.client.decode_text(JSON.stringify(guest_roster))
	session.on_lobby(guest_roster)
	check(session.phase == 11 and session.selected_mode == Setup.DEFAULT_MODE, "guest waits for the host after the matching echo")
	build("legacy")
	session.lobby_enabled = true
	session.phase = -3
	session.lobby_connect("ws://127.0.0.1:9", "Guest", "", "meridian-exchange", "deathmatch", false)
	session.begin_room()
	check(probe.frames[-1].character == "chatgpt" and probe.frames[-1].harness == "openclaw", "legacy call keeps the source defaults: " + str(probe.frames[-1]))

	# 4. Smoke/solo path: the create frame carries the resolved CLI pair.
	build("solo")
	session.phase = 0
	session.selected_character = "claude"
	session.selected_harness = "hermes"
	session.begin_room()
	check(probe.frames[-1].type == "create" and probe.frames[-1].character == "claude" and probe.frames[-1].harness == "claudecode", "solo create resolves the locked pair: " + str(probe.frames[-1]))
	check(session.can_capture_pointer() == false and session.client.spectating == false, "control gating untouched")

	session.free()
	print("PORT_LOADOUT_SESSION_OK checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
