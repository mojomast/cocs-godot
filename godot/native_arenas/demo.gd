extends "res://world/session.gd"
## Native map composition; gameplay, controls, public actor poses and first person
## remain the shared authoritative session's responsibility.
const NativeCatalog = preload("res://native_arenas/catalog.gd")
const NativeHUD = preload("res://native_arenas/hud.gd")
const NativeClient = preload("res://native_arenas/client.gd")
const GameHUD = preload("res://ui/game_hud.gd")
const Scoreboard = preload("res://ui/scoreboard.gd")
var native_hud: Control
var bot_count := 2
var round_seconds := 180
var startup_error := ""
var selected_native_map := "prism-foundry"
var auto_start := false
var authority_geometry_hash := ""

func _init() -> void:
	catalog = NativeCatalog.new()
	# Native DM requires the authority's death/stale-input epoch contract.
	client.free()
	client = NativeClient.new()
	# Native map builders own atmosphere and sun. Viewer defaults must never
	# become a second environment/light (or a detached Node leak).
	sun.free()
	environment.free()

func _ready() -> void:
	# Deliberately skip viewer/session _ready: both assume source catalog content,
	# and viewer runs an unrelated all-map smoke/fly-camera loop.
	build_composition()
	var options := parse_options(OS.get_cmdline_user_args())
	smoke = "--smoke" in OS.get_cmdline_user_args()
	trace_enabled = "--native-trace" in OS.get_cmdline_user_args()
	if not options.error.is_empty():
		on_error(options.error)
		return
	selected_native_map = options.map
	endpoint = options.endpoint
	bot_count = options.bots
	round_seconds = options.seconds
	auto_start = options.autostart or smoke
	selected_mode = "deathmatch"
	if not catalog.open():
		on_error(catalog.error)
		return
	ids = NativeCatalog.MAP_IDS.duplicate()
	if not load_map(selected_native_map):
		on_error(catalog.error)
		return
	phase = -2
	native_hud.configure(self)
	if auto_start: launch_match(selected_native_map, "Operator", bot_count, round_seconds)

func build_composition() -> void:
	phase = -2
	camera.name = "AuthoritativeCamera"
	camera.far = 2000
	camera.rotation_order = EULER_ORDER_YXZ
	add_child(camera)
	camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	var diagnostics := VBoxContainer.new()
	diagnostics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(diagnostics)
	for item: Control in [label, selector, combat_label]:
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		diagnostics.add_child(item)
		item.hide()
	selector.disabled = true
	for child: Node in [pickups, presentation, combat, client]: add_child(child)
	presentation.interpolate_remote = true
	client.connection_error.connect(on_error)
	client.connect("input_reset", func(_reason: String) -> void: release_pointer())
	client.lobby.connect(on_lobby)
	client.started.connect(on_started)
	client.snapshot.connect(on_snapshot)
	client.results.connect(on_results)
	client.events.connect(func(items: Array) -> void:
		if phase == 3: combat.apply_events(items, client.actor_id))
	var shared_hud := GameHUD.new()
	shared_hud.name = "GameHUD"
	add_child(shared_hud)
	var scores := Scoreboard.new()
	scores.name = "Scoreboard"
	add_child(scores)
	var setup_layer := CanvasLayer.new()
	setup_layer.layer = 10
	add_child(setup_layer)
	native_hud = NativeHUD.new()
	setup_layer.add_child(native_hud)
	setup_menu = native_hud
	native_hud.start_requested.connect(launch_match)
	# Bind now, after session handlers, so even a fast local start is observed.
	shared_hud.bind_session(self)
	scores.bind_session(self)
	shared_hud.controls.text = "WASD move · Space jump · Shift sprint · Ctrl/C crouch · X mobility · E use · Q power\nLMB fire · RMB ADS · Z/MMB alt · R reload · F melee · G grenade · 1–9/0/wheel weapons · Tab scores · Esc release"

static func parse_options(args: PackedStringArray) -> Dictionary:
	var options := {"map":"prism-foundry", "endpoint":"", "bots":2,
		"seconds":180, "autostart":false, "error":""}
	for arg: String in args:
		if arg.begins_with("--map="): options.map = arg.trim_prefix("--map=")
		if arg.begins_with("--endpoint="): options.endpoint = arg.trim_prefix("--endpoint=")
		if arg.begins_with("--mode=") and arg != "--mode=deathmatch": options.error = "Native arenas support Deathmatch only."
		if arg in ["--autostart", "--smoke"]: options.autostart = true
		for option: String in ["bots", "round-seconds"]:
			if not arg.begins_with("--" + option + "="): continue
			var value := arg.trim_prefix("--" + option + "=")
			if value.is_empty() or not value.is_valid_int() or value.contains("+") or value != value.strip_edges():
				options.error = option + " must be an integer."
			else: options["bots" if option == "bots" else "seconds"] = value.to_int()
	if options.map not in NativeCatalog.MAP_IDS: options.error = "Choose Prism Foundry, Aurora Basin or Cinder Array."
	if options.bots < 1 or options.bots > 7: options.error = "bots must be 1..7."
	if options.seconds < 60 or options.seconds > 300: options.error = "round-seconds must be 60..300."
	var url: String = options.endpoint
	var endpoint_match := RegEx.create_from_string("^ws://127\\.0\\.0\\.1:([1-9][0-9]{0,4})(/native-arenas|/)?$").search(url)
	if endpoint_match == null or endpoint_match.get_string() != url or endpoint_match.get_string(1).to_int() > 65535:
		options.error = "Launch with an owned ws://127.0.0.1:PORT/native-arenas endpoint."
	return options

func renderer_path(id: String) -> String:
	return "res://native_arenas/maps/" + id + ".gd"

func load_map(id: String) -> bool:
	var map := catalog.resolve_map(id)
	if map.is_empty(): return false
	var path := renderer_path(id)
	if not ResourceLoader.exists(path):
		catalog.error = "Native Deathmatch renderer is missing: " + id
		return false
	var script: Variant = load(path)
	if not script is GDScript or not script.can_instantiate():
		catalog.error = "Native Deathmatch renderer could not load: " + id
		return false
	var builder: Variant = script.new()
	if not builder is Node3D:
		if builder is Node: builder.free()
		catalog.error = "Native renderer must be a map-only Node3D: " + id
		return false
	for method: String in ["build", "get_spawn_points", "get_arena_id"]:
		if not builder.has_method(method):
			builder.free()
			catalog.error = "Native renderer contract is incomplete: " + id
			return false
	if builder.get_arena_id() != id:
		builder.free()
		catalog.error = "Native renderer identity mismatch: " + id
		return false
	var next := Node3D.new()
	next.name = "NativeArena"
	# Native builders collect world-space mesh transforms and need tree membership.
	# Their build() is idempotent, including when _ready has already invoked it.
	add_child(next)
	next.add_child(builder)
	builder.build()
	# Empty hidden compatibility hook; pickups are created only from public state.
	var markers := Node3D.new()
	markers.name = "StaticPickupMarkers"
	markers.hide()
	next.add_child(markers)
	if is_instance_valid(world):
		remove_child(world)
		world.free()
	world = next
	current_id = id
	selected_native_map = id
	world.set_meta("native_geometry_hash", catalog.entries[id].geometryHash)
	# No map spawn/preview camera assignment: only on_snapshot sets camera pose.
	return true

func launch_match(map_id: String, player_name: String, bots: int, seconds: int) -> void:
	if phase != -2: return
	if map_id not in NativeCatalog.MAP_IDS or bots < 1 or bots > 7 or seconds < 60 or seconds > 300 or player_name.strip_edges().is_empty():
		on_error("Invalid native Deathmatch setup.")
		return
	if current_id != map_id and not load_map(map_id):
		on_error(catalog.error)
		return
	lobby_player_name = player_name.strip_edges().left(32)
	bot_count = bots
	round_seconds = seconds
	native_hud.hide()
	elapsed = 0
	connect_selected_match()

func on_lobby(frame: Dictionary) -> void:
	lobby_roster = frame.duplicate(true)
	if phase == 1:
		if client.send_frame({"type":"host", "mapId":current_id,
			"config":{"mode":"deathmatch", "botCount":bot_count, "timeLimit":round_seconds, "fragLimit":50}}) != OK:
			on_error("Deathmatch configuration could not be queued.")
		else: phase = 2
		return
	if phase == 2 and frame.get("config") != null:
		var config: Variant = frame.config
		if not config is Dictionary or config.get("mode") != "deathmatch" or config.get("botCount") != bot_count or config.get("timeLimit") != round_seconds or config.get("fragLimit") != 50:
			on_error("Native authority returned different Deathmatch settings; start cancelled.")
			return
	super.on_lobby(frame)

func on_snapshot(frame: Dictionary) -> void:
	if phase != 3: return
	# Shared smoke assumes precisely two bots and source pickups. Keep its public
	# input stimulus, but assess this native route's selected roster separately.
	var checking := smoke
	smoke = false
	super.on_snapshot(frame)
	smoke = checking
	if not checking: return
	if received_pose and presentation.lifecycle.can_control() and camera.position.is_equal_approx(presentation.eye_position()) and moved and fired and client.last_ack > 10 and presentation.actors.size() == bot_count + 1 and authority_geometry_hash == catalog.entries[current_id].geometryHash:
		print("NATIVE_DM_SMOKE_OK ", JSON.stringify({"map":current_id, "mode":"deathmatch",
			"actors":presentation.actors.size(), "snapshots":presentation.applied, "acks":client.last_ack,
			"moved":moved, "fired":fired, "localAlive":true, "camera":"public-actor",
			"geometryHash":catalog.entries[current_id].geometryHash}))
		client.disconnect_server()
		get_tree().quit(0)

func on_started(frame: Dictionary) -> void:
	authority_geometry_hash = str(frame.get("geometryHash", ""))
	if not frame.get("geometryHash") is String or authority_geometry_hash.is_empty() or authority_geometry_hash != catalog.entries[current_id].geometryHash:
		on_error("Native authority and renderer geometry differ; relaunch matching assets.")
		return
	super.on_started(frame)

func on_results(frame: Dictionary) -> void:
	if phase != 3: return
	if frame.state.get("over") != true:
		on_error("Native authority results must finish the round.")
		return
	round_results += 1
	presentation.apply_state(frame.state, client.actor_id)
	pickups.apply_state(frame.state)
	phase = 4
	combat.clear_round()
	release_pointer()
	label.text = presentation.hud_text + "\nEnter: restart Deathmatch"

func release_pointer() -> void:
	var was_active := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	super.release_pointer()
	# Send one FIFO cancellation when leaving live capture. Normal neutral frames
	# still use the shared 60 Hz loop; epoch resets are supplied by the authority.
	if was_active and phase == 3:
		client.call("send_controls", {}, true)

func on_error(message: String) -> void:
	startup_error = message
	super.on_error(message)
