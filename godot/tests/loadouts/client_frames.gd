extends SceneTree
# Wire contract for operator/harness on create/join. Defaults must stay backward
# compatible with the pre-loadout frame; explicit selections must be resolved
# with the source normalization before they are queued.
const Client = preload("res://net/client.gd")
const Loadout = preload("res://ui/loadout.gd")
var checks := 0
var failures := 0

class Probe extends Client:
	var frames: Array[Dictionary] = []
	func send_frame(frame: Dictionary) -> Error:
		frames.append(frame.duplicate(true))
		return OK

class GuardProbe extends Client:
	var frames: Array[Dictionary] = []
	func send_frame(frame: Dictionary) -> Error:
		var result: Error = super.send_frame(frame)
		if result == OK: frames.append(frame.duplicate(true))
		return result

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("LOADOUT_CLIENT " + message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var probe := Probe.new()
	# Default API call: unchanged type/name/playerName, plus the source default pair.
	check(probe.create_room("Godot") == OK, "create_room default queues")
	var defaults: Dictionary = probe.frames[-1]
	check(defaults.type == "create" and defaults.name == "Godot port laboratory" and defaults.playerName == "Godot", "create frame keeps legacy fields")
	check(defaults.v == 3 and defaults.delta == 0, "create frame keeps protocol revision and delta advertisement")
	check(defaults.character == "chatgpt" and defaults.harness == "openclaw", "create frame carries source defaults")

	check(probe.join_room("room-1", "Godot guest") == OK, "join_room default queues")
	var join: Dictionary = probe.frames[-1]
	check(join.type == "join" and join.roomId == "room-1" and join.name == "Godot guest", "join frame keeps legacy fields")
	check(join.v == 3 and join.delta == 0, "join frame keeps revision and delta")
	check(join.character == "chatgpt" and join.harness == "openclaw", "join frame carries source defaults")
	check(probe.joined_room_request == "room-1" and probe.spectator_notice_stage == 1, "join handshake bookkeeping unchanged")

	# Explicit selections are passed through after source normalization.
	check(probe.create_room("Host", "grok", "cline") == OK, "create_room explicit pair queues")
	var host: Dictionary = probe.frames[-1]
	check(host.character == "grok" and host.harness == "cline", "host frame carries the chosen pair")
	check(probe.create_room("Host", "claude", "hermes") == OK, "create_room locked pair queues")
	var locked: Dictionary = probe.frames[-1]
	check(locked.character == "claude" and locked.harness == "claudecode", "locked pair is resolved before sending")
	check(probe.join_room("room-2", "Guest", "deepseek", "hermes") == OK, "join_room explicit pair queues")
	var guest: Dictionary = probe.frames[-1]
	check(guest.character == "deepseek" and guest.harness == "hermes", "guest frame carries the chosen pair")
	check(guest.roomId == "room-2" and guest.name == "Guest", "explicit join keeps room and name")
	check(probe.create_room("Host", "bogus", "bogus") == OK, "unknown ids do not break the API")
	var fallback: Dictionary = probe.frames[-1]
	check(fallback.character == "chatgpt" and fallback.harness == "openclaw", "unknown ids fall back to source defaults")
	check(loadout_field(probe, "create_room", ["X", "grok", "roo"]) is String, "harness stays a string on the wire")

	# Invalid room id keeps its existing error and queues nothing.
	var before: int = probe.frames.size()
	check(probe.join_room("") == ERR_INVALID_PARAMETER, "empty room id still rejected")
	check(probe.frames.size() == before, "rejected join queues no frame")

	# The spectating guard still blocks create/join before any frame is built.
	var guarded := GuardProbe.new()
	guarded.spectating = true
	check(guarded.create_room("Host", "grok", "cline") == ERR_UNAUTHORIZED, "spectator cannot create")
	check(guarded.join_room("room-3", "Guest", "grok", "cline") == ERR_UNAUTHORIZED, "spectator cannot join")
	check(guarded.frames.is_empty(), "spectator queues no create/join frame")
	guarded.spectating = false
	guarded.allowlist = {"meridian-exchange":{"modes":["deathmatch"]}}
	guarded.requested_map = "meridian-exchange"
	check(guarded.configure_match("deathmatch", 2) == ERR_CONNECTION_ERROR, "closed peer still refuses host config")

	# Envelope hardening: an authority echo with a non-string identity is malformed.
	var envelope := Client.new()
	envelope.allowlist = {"meridian-exchange":{"modes":["deathmatch"]}}
	envelope.requested_map = "meridian-exchange"
	check(envelope.decode_text('{"type":"lobby","players":[{"peerId":1,"actorId":null,"character":"grok","harness":"cline"}]}'), "string identity accepted")
	check(not envelope.decode_text('{"type":"lobby","players":[{"peerId":2,"actorId":null,"character":7}]}'), "non-string character rejected")
	check(not envelope.decode_text('{"type":"lobby","players":[{"peerId":3,"actorId":null,"harness":["hermes"]}]}'), "non-string harness rejected")
	check(not envelope.decode_text('{"type":"lobby","players":[{"peerId":4,"actorId":null,"character":"grok","harness":null}]}'), "null harness rejected")
	var echo := Client.new()
	echo.allowlist = {"meridian-exchange":{"modes":["deathmatch"]}}
	echo.requested_map = "meridian-exchange"
	echo.peer_id = 1
	check(echo.decode_text('{"type":"lobby","players":[{"peerId":1,"actorId":3,"character":"grok","harness":"cline"}]}'), "self row accepted")
	check(echo.assigned_character == "grok" and echo.assigned_harness == "cline", "authority identity recorded")
	check(echo.decode_text('{"type":"lobby","players":[{"peerId":1,"actorId":3}]}'), "identity-free row still accepted")
	check(echo.assigned_character == "" and echo.assigned_harness == "", "absent identity clears the recorded pair")
	check(echo.decode_text('{"type":"lobby","players":[{"peerId":9,"actorId":4,"character":"deepseek","harness":"hermes"}]}'), "other player row accepted")
	check(echo.assigned_character == "" and echo.assigned_harness == "", "other player never becomes the recorded self identity")

	for client: Node in [probe, guarded, envelope, echo]: client.free()
	print("PORT_LOADOUT_CLIENT_OK checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

func loadout_field(probe: Probe, method: String, arguments: Array) -> Variant:
	probe.callv(method, arguments)
	var frame: Dictionary = probe.frames[-1]
	return frame.get("harness", null)
