extends SceneTree
## Explicit synthetic-public-frame integration, not a source gameplay acceptance.
const Demo = preload("res://native_arenas/demo.gd")
const NativeCatalog = preload("res://native_arenas/catalog.gd")
const FixtureSession = preload("res://tests/native_arenas/session/fixture_session.gd")
const FixtureClient = preload("res://tests/native_arenas/session/fixture_client.gd")
var failures := 0
var checks := 0
var directory := "user://native-arena-session-fixtures/"

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func write_fixture(id: String, replacement: String = "") -> void:
	var envelope := {"schemaVersion":1, "id":id, "name":NativeCatalog.TITLES[id],
		"geometryHash":"synthetic-test-only", "arena":{"id":id, "name":NativeCatalog.TITLES[id],
		"bounds":{"minX":-10,"maxX":10,"minZ":-10,"maxZ":10}, "spawns":[[0,0]],
		"pickups":[], "navNodes":[[0,0]], "blocks":[]},
		"spawnPoints":[{"x":0,"y":0,"z":0}], "routes":[]}
	var file := FileAccess.open(directory + id + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope) if replacement.is_empty() else replacement)

func actor(id: int, x: float = 2) -> Dictionary:
	return {"id":id, "name":"Fixture Operator" if id == 0 else "Fixture Rival",
		"x":x,"y":3,"z":4,"yaw":0.25,"pitch":-0.1,"health":100,"maxHealth":100,
		"dead":0,"eyeHeight":1.45,"weapon":0,"ammo":[30],"armor":25,"frags":0,"deaths":0,"shots":0}

func decode(d: Node, frame: Dictionary) -> bool:
	return d.client.decode_text(JSON.stringify(frame))

func snapshot(d: Node, seq: int, actors: Array, over: bool = false) -> Dictionary:
	var state := {"mapId":"prism-foundry", "mapName":"Prism Foundry", "modeName":"Deathmatch",
		"config":{"mode":"deathmatch","timeLimit":60},"time":10,"over":over,
		"actors":actors,"pickups":[{"id":0,"kind":"health","x":0,"y":1,"z":0,"wait":0}],
		"leaders":["Fixture Operator"]}
	check(decode(d, {"type":"results" if over else "snapshot", "seq":seq, "acks":{"0":seq},
		"inputEpoch":d.client.input_epoch, "nativeArenaInput":{"receivedSeq":seq,"appliedSeq":seq,"cancelledThrough":0,"queueDepth":0}, "state":state}), "fixture frame accepted")
	return state

func key(code: int, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event

func run() -> void:
	var base: PackedStringArray = ["--endpoint=ws://127.0.0.1:9876/native-arenas"]
	check(Demo.parse_options(base).error.is_empty(), "valid native defaults")
	check(Demo.parse_options(base).bots == 2, "smoke defaults to two bots")
	for value: String in ["--map=meridian-exchange", "--map=../prism-foundry", "--mode=horde", "--bots=-1", "--bots=0", "--bots=8", "--bots=9", "--bots=two", "--bots=+1", "--bots= 1", "--round-seconds=59", "--round-seconds=301"]:
		var args := base.duplicate()
		args.append(value)
		check(not Demo.parse_options(args).error.is_empty(), "reject invalid option " + value)
	check(not Demo.parse_options([]).error.is_empty(), "explicit endpoint required")
	check(not Demo.parse_options(["--endpoint=ws://user:secret@host"]).error.is_empty(), "embedded credentials rejected")
	for bots: int in [1, 7]:
		check(Demo.parse_options(base + PackedStringArray(["--bots=" + str(bots), "--round-seconds=300"])).error.is_empty(), "authoritative bot bounds and max duration allowed")
	for suffix: String in ["", "/", "/native-arenas"]:
		check(Demo.parse_options(["--endpoint=ws://127.0.0.1:9876" + suffix]).error.is_empty(), "exact owned endpoint route " + suffix)
	for url: String in ["ws://localhost:9876", "ws://127.0.0.1:0", "ws://127.0.0.1:65536", "wss://127.0.0.1:9876/native-arenas", "ws://127.0.0.1:9876/other", "ws://127.0.0.1:9876/native-arenas/", "ws://127.0.0.1:9876/other/../native-arenas", "ws://127.0.0.1:9876/native-arenas?x=1", "ws://127.0.0.1:9876/native-arenas#fragment", "ws://127.0.0.1:9876/native-arenas\n"]:
		check(not Demo.parse_options(["--endpoint=" + url]).error.is_empty(), "reject endpoint " + url)
	DirAccess.make_dir_recursive_absolute(directory)
	for id: String in NativeCatalog.MAP_IDS: write_fixture(id)
	var c := NativeCatalog.new()
	c.asset_root = directory
	check(c.open() and c.entries.size() == 3, "native-only source-shaped allowlist")
	check(c is PortCatalog and c.entries["prism-foundry"].modes == ["deathmatch"], "catalog preserves inherited type and DM-only mode")
	check(c.resolve_map("meridian-exchange").is_empty(), "source map not accepted by native catalog")
	check(c.resolve_map("prism-foundry").id == "prism-foundry", "resolve returns arena, not envelope")
	write_fixture("prism-foundry", "{}")
	check(c.resolve_map("prism-foundry").is_empty(), "changed geometry refused after open")
	check(not c.open() and c.entries.is_empty(), "invalid schema fails atomically")
	write_fixture("prism-foundry")
	check(c.open(), "valid fixture restored")
	var d := FixtureSession.new()
	root.add_child(d)
	d.catalog = c
	d.ids = NativeCatalog.MAP_IDS.duplicate()
	d.endpoint = "ws://fixture.invalid"
	d.native_hud.configure(d)
	check(d.native_hud.bots.min_value == 1 and d.native_hud.bots.max_value == 7 and d.native_hud.bots.value == 2, "UI bot slider follows authority bounds and launcher default")
	check(d.native_hud.duration.min_value == 60 and d.native_hud.duration.max_value == 300, "UI round duration bounds")
	await process_frame
	check(d.load_map("prism-foundry"), "fixture renderer instantiated")
	check(d.camera.position == Vector3.ZERO, "renderer spawn cannot move gameplay camera")
	check(d.world.get_node("StaticPickupMarkers").get_child_count() == 0 and not d.world.get_node("StaticPickupMarkers").visible, "no static pickup duplicates")
	check(not d.load_map("aurora-basin") and d.current_id == "prism-foundry", "renderer ID substitution rejected without replacing world")
	d.missing_renderer = true
	check(not d.load_map("prism-foundry"), "missing dynamic renderer rejected")
	d.missing_renderer = false
	d.native_hud.select_map("cinder-array")
	check(d.native_hud.selected == "cinder-array" and d.current_id == "prism-foundry", "setup choice does not move player camera")
	d.launch_match("prism-foundry", "Fixture Operator", 1, 60)
	d.begin_room()
	check(d.client.writes.back().type == "create" and d.client.writes.back().playerName == "Fixture Operator" and d.client.writes.back().nativeArenaInput == 1, "explicit start creates named player and negotiates native input epochs")
	check(decode(d, {"type":"welcome","v":3,"roomId":"fixture","peerId":7}), "v3 welcome")
	var roster := {"type":"lobby","players":[{"peerId":7,"actorId":0}], "config":null}
	check(decode(d, roster), "unconfigured lobby")
	check(d.phase == 2 and d.client.writes.back().config.botCount == 1 and d.client.writes.back().config.timeLimit == 60 and d.client.writes.back().config.fragLimit == 50, "selected host config queued within authoritative bounds")
	roster.mapId = "prism-foundry"
	roster.config = d.client.writes.back().config.duplicate()
	check(decode(d, roster) and d.phase == 20 and d.client.writes.back().type == "start", "configured lobby queues start")
	check(decode(d, {"type":"start","mapId":"prism-foundry","geometryHash":"synthetic-test-only","inputEpoch":1}), "authoritative start")
	check(d.authority_geometry_hash == c.entries["prism-foundry"].geometryHash, "authority geometry identity matches native renderer asset")
	var a := actor(0)
	snapshot(d, 1, [a, actor(1, 8)])
	check(d.phase == 3 and d.received_pose and d.pose_actor_id == 0, "public actor zero enables pose")
	check(d.camera.position.is_equal_approx(Vector3(2, 4.45, 4)), "camera follows only public feet plus eye height")
	check(is_equal_approx(d.yaw, 0.25) and is_equal_approx(d.pitch, -0.1), "spawn look reseeded from public actor")
	check(d.presentation.actors.size() == 2 and d.presentation.actors[1].visible and not d.presentation.actors[0].visible, "remote actor visible and local body hidden")
	check(d.pickups.markers.size() == 1 and is_instance_valid(d.first_person), "public pickups and shared first-person binding attached")
	d.combat_actions.record(key(KEY_W, true), true, a)
	d.combat_actions.record(key(KEY_Q, true), true, a)
	check(d.combat_actions.sample(0,0,true).power, "fresh fixture action queued")
	check(d.client.send_input({"fire":true,"z":1}) == OK and d.client.writes.back().inputEpoch == 1 and not d.client.writes.back().cancel, "shared send_input routes through epoch-aware client")
	check(decode(d, {"type":"native-arena-input-reset","inputEpoch":2,"reason":"death"}), "authority death epoch accepted")
	check(d.client.input_epoch == 2 and not d.combat_actions.sample(0,0,true).power and d.combat_actions.sample(0,0,true).z == 0, "epoch boundary releases held controls before the next snapshot")
	check(d.client.send_controls({"fire":true}, true) == OK and d.client.writes.back().inputEpoch == 2 and d.client.writes.back().cancel and d.client.writes.back().input.is_empty(), "FIFO cancellation uses current epoch and empty controls")
	a.health = 0
	a.dead = 2
	snapshot(d, 2, [a, actor(1, 8)])
	check(d.presentation.lifecycle.status == "dead" and not d.can_capture_pointer(), "death disables capture")
	check(not d.combat_actions.sample(0,0,true).power and d.combat_actions.sample(0,0,true).z == 0, "death clears held movement and action")
	a = actor(0, 12)
	a.yaw = 1.0
	snapshot(d, 3, [a, actor(1, 8)])
	d.combat_actions.record(key(KEY_W,true), true, a)
	check(d.presentation.lifecycle.respawn_transitions == 1 and is_equal_approx(d.yaw,1.0), "respawn is public and look reseeded")
	check(d.combat_actions.sample(0,0,true).z == 0, "held key cannot revive on respawn")
	d.combat_actions.record(key(KEY_W,false), true, a)
	d.combat_actions.record(key(KEY_W,true), true, a)
	check(d.combat_actions.sample(0,0,true).z != 0, "fresh released/repressed key works")
	var previous: Vector3 = d.camera.position
	snapshot(d, 4, [actor(1, 8)])
	check(not d.received_pose and d.camera.position == previous and not d.can_capture_pointer(), "absent local actor retains no control or substituted camera")
	a.frags = 4
	snapshot(d, 5, [a, actor(1, 8)], true)
	check(d.phase == 4 and not d.presentation.lifecycle.can_control(), "results gate controls")
	check(d.get_node("Scoreboard").finished and d.get_node("Scoreboard").entries[0].frags == "4", "shared final scoreboard consumes public state")
	check(d.native_hud.round_label.text == "WINNER  ·  Fixture Operator", "winner displayed from public leaders")
	d.request_restart()
	check(d.phase == 20 and d.client.writes.back().type == "start", "Enter restart contract queues start")
	decode(d, {"type":"start","mapId":"prism-foundry","geometryHash":"synthetic-test-only","inputEpoch":3})
	check(d.round_starts == 2 and not d.received_pose and d.presentation.actors.is_empty() and d.pickups.markers.is_empty(), "restart clears previous round presentation")
	snapshot(d, 1, [actor(0)])
	check(d.received_pose and d.client.last_ack == 1 and d.round_results == 1, "restart accepts reset public sequence")
	check(d.client.input_epoch == 3 and d.client.input_status.appliedSeq == 1, "restart advances native epoch and clears old input status")
	check(not decode(d, {"type":"snapshot","seq":2,"inputEpoch":3,"state":{"mapId":"aurora-basin"}}), "cross-map public snapshot refused")
	check(d.phase == -1 and not d.received_pose and not d.can_capture_pointer(), "transport mismatch safely ends session")
	for hash_value: Variant in [null, "", "different-geometry", 123]:
		d.client.requested_map = "prism-foundry"
		var start_frame := {"type":"start","mapId":"prism-foundry","inputEpoch":4}
		if hash_value != null: start_frame.geometryHash = hash_value
		decode(d, start_frame)
		check(d.phase == -1 and "geometry differ" in d.startup_error and d.round_starts == 2, "missing/malformed/mismatched start hash cannot restart controls")
	d.phase = 2
	d.on_lobby({"config":{"mode":"deathmatch","botCount":2,"timeLimit":60,"fragLimit":50}})
	check(d.phase == -1 and "different Deathmatch settings" in d.startup_error, "echoed authority settings cannot silently clamp UI selection")
	d.phase = 3
	d.on_results({"state":{"over":false}})
	check(d.phase == -1 and d.round_results == 1, "unfinished public state cannot become results")
	for bots: int in [0, 8]:
		d.phase = -2
		var writes_before: int = d.client.writes.size()
		d.launch_match("prism-foundry", "Fixture Operator", bots, 60)
		check(d.phase == -1 and d.client.writes.size() == writes_before, "invalid UI bot selection cannot reach transport")
	for epoch_value: Variant in [null, 0, 1.5, "2"]:
		check(not decode(d, {"type":"start","mapId":"prism-foundry","inputEpoch":epoch_value,"geometryHash":"synthetic-test-only"}), "missing/malformed native epoch rejected")
	d.client.input_epoch = 5
	check(not decode(d, {"type":"native-arena-input-reset","inputEpoch":4,"reason":"stale-input"}), "native epoch cannot regress")
	check(d.client.input_epoch == 0 and not d.received_pose, "failed epoch closes native session and clears epoch")
	# Regression: the lobby client widened create_room for the loadout identity. This
	# route's override must keep signature parity (a mismatch stopped the whole arena
	# scene from compiling), keep the create frame on the authority's key allowlist, and
	# refuse a real loadout choice instead of dropping it silently.
	var identity_probe := FixtureClient.new()
	check(identity_probe.create_room("Fixture Operator") == OK, "arena create_room accepts the widened lobby signature")
	check(identity_probe.writes.back().type == "create" and identity_probe.writes.back().nativeArenaInput == 1, "arena create frame still negotiates native input")
	check(not identity_probe.writes.back().has("character") and not identity_probe.writes.back().has("harness"), "arena create frame carries no lobby identity")
	check(identity_probe.create_room("Fixture Operator", "chatgpt", "openclaw") == OK, "documented default pair is not a loadout choice")
	check(identity_probe.create_room("Fixture Operator", "", "") == OK, "unset identity is not a loadout choice")
	var writes_before_choice: int = identity_probe.writes.size()
	check(identity_probe.create_room("Fixture Operator", "grok", "cline") == ERR_UNAUTHORIZED, "unsupported loadout is refused, not silently dropped")
	check(identity_probe.create_room("Fixture Operator", "chatgpt", "claudecode") == ERR_UNAUTHORIZED, "harness-only choice is refused too")
	check(identity_probe.writes.size() == writes_before_choice, "a refused loadout emits no frame")
	identity_probe.free()
	d.queue_free()
	await process_frame
	for id: String in NativeCatalog.MAP_IDS: DirAccess.remove_absolute(directory + id + ".json")
	DirAccess.remove_absolute(directory)
	print("NATIVE_DM_SYNTHETIC_TESTS checks=", checks, " failures=", failures, " evidence=fixture-only")
	quit(0 if failures == 0 else 1)
