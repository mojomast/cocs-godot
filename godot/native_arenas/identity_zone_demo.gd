extends "res://world/session.gd"
## Identity-map Domination composition for Vermilion Fold.
##
## Composition only: gameplay, public actor poses, first-person/ADS, pickups,
## combat/effects, HUD, scoreboard and lifecycle stay the shared authoritative
## session's responsibility. This scene adds the identity recipe builder
## (`identity_maps/map.gd` through the native catalog's reviewed entry), the one
## documented shared identity environment (one sun, one WorldEnvironment), and
## the delivered zone adapter/renderer/HUD that project the source snapshot.
##
## There is no exploration camera and no map preview pose: the camera is only
## ever placed from the authority's local actor (`presentation.eye_position()`),
## exactly like the delivered native/identity routes. The viewer's default sun
## and environment are freed in `_init` so an identity session can never run a
## second light or a second sky.
const NativeCatalog = preload("res://native_arenas/catalog.gd")
const NativeClient = preload("res://native_arenas/client.gd")
const IdentityEnvironment = preload("res://native_arenas/identity_environment.gd")
const ZoneHUD = preload("res://zone_modes/hud.gd")
const ZoneRenderer = preload("res://zone_modes/renderer.gd")
const ZoneAdapter = preload("res://zone_modes/adapter.gd")
const Scoreboard = preload("res://ui/scoreboard.gd")
const MAP_ID := "vermilion-fold"
const MODE := "domination"
const BOT_RANGE := Vector2i(0, 7)
const SECONDS_RANGE := Vector2i(60, 900)
const SCORE_RANGE := Vector2i(1, 900)
var zones := ZoneAdapter.new()
var zone_renderer: Node3D
var zone_hud: CanvasLayer
var bot_count := 2
var round_seconds := 120
var score_limit := 30
var auto_start := true
var evidence := false
var evidence_count := 0
var startup_error := ""
var authority_geometry_hash := ""

## The one reviewed destination this composition may host. Static, so the test
## suite can pin it without instantiating a scene.
static func destination() -> Dictionary:
	return {"mapId": MAP_ID, "mode": MODE}

func _init() -> void:
	catalog = NativeCatalog.new()
	# The identity route needs the authority's input-epoch contract.
	client.free()
	client = NativeClient.new()
	sun.free()
	environment.free()

func _ready() -> void:
	# Deliberately skip viewer/session _ready: both assume the locked nine-map
	# source catalog and the viewer runs its exploration fly camera.
	build_composition()
	var options := parse_options(OS.get_cmdline_user_args())
	smoke = "--smoke" in OS.get_cmdline_user_args()
	trace_enabled = "--native-trace" in OS.get_cmdline_user_args()
	evidence = "--zone-evidence" in OS.get_cmdline_user_args()
	if not options.error.is_empty():
		on_error(options.error)
		return
	endpoint = options.endpoint
	bot_count = options.bots
	round_seconds = options.seconds
	score_limit = options.score
	auto_start = options.autostart
	selected_mode = MODE
	if not catalog.open_dm():
		on_error(catalog.error)
		return
	ids = NativeCatalog.DM_MAP_IDS.duplicate()
	for id: String in ids: selector.add_item(catalog.entries[id].name)
	if not load_map(MAP_ID):
		on_error(catalog.error)
		return
	phase = -2
	if auto_start: launch_match(MAP_ID, "Operator", bot_count, round_seconds, score_limit)

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
	zone_renderer = ZoneRenderer.new()
	zone_renderer.name = "ZoneRenderer"
	for child: Node in [pickups, presentation, combat, client, zone_renderer]: add_child(child)
	presentation.interpolate_remote = true
	client.connection_error.connect(on_error)
	client.connect("input_reset", func(_reason: String) -> void: release_pointer())
	client.lobby.connect(on_lobby)
	client.started.connect(on_started)
	client.snapshot.connect(on_snapshot)
	client.results.connect(on_results)
	client.events.connect(func(items: Array) -> void:
		if phase == 3: combat.apply_events(items, client.actor_id))
	zone_hud = ZoneHUD.new()
	zone_hud.name = "ZoneHUD"
	add_child(zone_hud)
	var scores := Scoreboard.new()
	scores.name = "Scoreboard"
	add_child(scores)
	# Bind after the session handlers above so live zone state is projected
	# before the shared HUD reads it.
	zone_hud.bind_session(self)
	scores.bind_session(self)

static func parse_options(args: PackedStringArray) -> Dictionary:
	var options := {"map":MAP_ID, "endpoint":"", "bots":2, "seconds":120, "score":30,
		"autostart":true, "error":""}
	for arg: String in args:
		if arg.begins_with("--map="):
			options.map = arg.trim_prefix("--map=")
			if options.map != MAP_ID: options.error = "Identity zone route supports Vermilion Fold only."
		if arg.begins_with("--mode=") and arg != "--mode=" + MODE:
			options.error = "Identity zone route supports Domination only."
		if arg.begins_with("--endpoint="): options.endpoint = arg.trim_prefix("--endpoint=")
		if arg == "--autostart": options.autostart = true
		for option: String in ["bots", "round-seconds", "score-limit"]:
			if not arg.begins_with("--" + option + "="): continue
			var value := arg.trim_prefix("--" + option + "=")
			var key: String = {"bots":"bots", "round-seconds":"seconds", "score-limit":"score"}[option]
			if value.is_empty() or not value.is_valid_int() or value.contains("+") or value != value.strip_edges():
				options.error = option + " must be an integer."
			else: options[key] = value.to_int()
	if options.error.is_empty() and (options.bots < BOT_RANGE.x or options.bots > BOT_RANGE.y):
		options.error = "bots must be %d..%d." % [BOT_RANGE.x, BOT_RANGE.y]
	if options.error.is_empty() and (options.seconds < SECONDS_RANGE.x or options.seconds > SECONDS_RANGE.y):
		options.error = "round-seconds must be %d..%d." % [SECONDS_RANGE.x, SECONDS_RANGE.y]
	if options.error.is_empty() and (options.score < SCORE_RANGE.x or options.score > SCORE_RANGE.y):
		options.error = "score-limit must be %d..%d." % [SCORE_RANGE.x, SCORE_RANGE.y]
	if not options.error.is_empty(): return options
	var url: String = options.endpoint
	var endpoint_match := RegEx.create_from_string("^ws://127\\.0\\.0\\.1:([1-9][0-9]{0,4})(/native-zones|/)?$").search(url)
	if endpoint_match == null or endpoint_match.get_string() != url or endpoint_match.get_string(1).to_int() > 65535:
		options.error = "Launch with an owned ws://127.0.0.1:PORT/native-zones endpoint."
	return options

## The identity recipe builder is the reviewed catalog renderer entry; the
## envelope is re-validated and sha256-checked by the catalog before a byte
## reaches the builder.
func load_map(id: String) -> bool:
	if id != MAP_ID:
		catalog.error = "Identity zone route supports Vermilion Fold only: " + id
		return false
	if not catalog.entries.has(id):
		catalog.error = "Identity zone map is not allowlisted: " + id
		return false
	var data: Dictionary = catalog.resolve_envelope(id)
	if data.is_empty(): return false
	var path: String = str(catalog.entries[id].renderer)
	if not ResourceLoader.exists(path):
		catalog.error = "Identity zone renderer is missing: " + id
		return false
	var script: Variant = load(path)
	if not script is GDScript or not script.can_instantiate():
		catalog.error = "Identity zone renderer could not load: " + id
		return false
	var builder: Variant = script.new()
	if not builder is Node3D or not builder.has_method("build") or not builder.has_method("get_arena_id"):
		if builder is Node: builder.free()
		catalog.error = "Identity zone renderer contract is incomplete: " + id
		return false
	var next := Node3D.new()
	next.name = "IdentityArena"
	add_child(next)
	next.add_child(builder)
	if builder.build(id) != true or builder.get_arena_id() != id:
		next.free()
		catalog.error = "Identity zone builder refused: " + id
		return false
	var identity_environment := IdentityEnvironment.new()
	next.add_child(identity_environment)
	if not identity_environment.build(data):
		next.free()
		catalog.error = "Identity zone environment failed: " + id
		return false
	var markers := Node3D.new()
	markers.name = "StaticPickupMarkers"
	markers.hide()
	next.add_child(markers)
	if is_instance_valid(world):
		remove_child(world)
		world.free()
	world = next
	current_id = id
	world.set_meta("native_geometry_hash", catalog.entries[id].geometryHash)
	return true

func launch_match(map_id: String, player_name: String, bots: int, seconds: int, score: int) -> void:
	if phase != -2: return
	var invalid := map_id != MAP_ID or bots < BOT_RANGE.x or bots > BOT_RANGE.y or seconds < SECONDS_RANGE.x
	invalid = invalid or seconds > SECONDS_RANGE.y or score < SCORE_RANGE.x or score > SCORE_RANGE.y
	if invalid or player_name.strip_edges().is_empty():
		on_error("Invalid identity zone setup.")
		return
	if current_id != map_id and not load_map(map_id):
		on_error(catalog.error)
		return
	lobby_player_name = player_name.strip_edges().left(32)
	bot_count = bots
	round_seconds = seconds
	score_limit = score
	elapsed = 0
	connect_selected_match()

func on_lobby(frame: Dictionary) -> void:
	if phase == 1:
		if client.send_frame({"type":"host", "mapId":current_id,
			"config":{"mode":MODE, "botCount":bot_count, "timeLimit":round_seconds, "fragLimit":score_limit}}) != OK:
			on_error("Domination configuration could not be queued.")
		else: phase = 2
		return
	if phase == 2 and frame.get("config") != null:
		var config: Variant = frame.config
		if not config is Dictionary or config.get("mode") != MODE or config.get("botCount") != bot_count or \
				config.get("timeLimit") != round_seconds or config.get("fragLimit") != score_limit:
			on_error("Identity zone authority returned different Domination settings; start cancelled.")
			return
	super.on_lobby(frame)

func on_started(frame: Dictionary) -> void:
	authority_geometry_hash = str(frame.get("geometryHash", ""))
	if authority_geometry_hash.is_empty() or authority_geometry_hash != catalog.entries[current_id].geometryHash:
		on_error("Identity authority and renderer geometry differ; relaunch matching assets.")
		return
	zones.clear()
	zone_renderer.clear_round()
	super.on_started(frame)

func on_error(message: String) -> void:
	startup_error = message
	zones.clear()
	if is_instance_valid(zone_renderer): zone_renderer.clear_round()
	super.on_error(message)

func on_snapshot(frame: Dictionary) -> void:
	if phase != 3: return
	super.on_snapshot(frame)
	apply_zones(frame)

## Read-only projection of the full source zone snapshot. No local objective
## clock, no inferred ownership, no guessed geometry.
func apply_zones(frame: Dictionary) -> void:
	zones.apply(frame.state, client.actor_id, current_id, selected_mode)
	zone_renderer.apply(zones.projection)
	if is_instance_valid(zone_hud): zone_hud.refresh_zone()
	if zones.projection.is_empty(): release_pointer()
	if evidence and evidence_count < 6000:
		# Compact receipt: exactly the fields the Node validator correlates with
		# the authority's own frame (the source snapshot already carries the full
		# actor record, so repeating it here would only multiply the log size).
		# A cleared projection is an empty dictionary; `.get` keeps the receipt
		# well-formed so an unprojected tick is still readable, never an error.
		var projection: Dictionary = zones.projection
		print("ZONE_NATIVE ", JSON.stringify({"mapId":current_id, "mode":selected_mode,
			"round":round_starts, "seq":frame.get("seq", -1), "actor_id":client.actor_id,
			"ack":client.last_ack, "rendered":zone_renderer.rendered,
			"projection":{"team":projection.get("team", -1), "zones":projection.get("zones", []),
				"scores":projection.get("scores", [-1, -1]), "time":projection.get("time", -1.0),
				"limit":projection.get("limit", -1.0), "over":projection.get("over", false),
				"winner":projection.get("winner", null)},
			"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED}))
		evidence_count += 1

func on_results(frame: Dictionary) -> void:
	if phase != 3: return
	if frame.state.get("over") != true:
		on_error("Identity zone authority results must finish the round.")
		return
	round_results += 1
	phase = 4
	presentation.apply_state(frame.state, client.actor_id)
	pickups.apply_state(frame.state)
	apply_zones(frame)
	combat.clear_round()
	release_pointer()
	label.text = presentation.hud_text + "\nEnter: restart Domination"

func release_pointer() -> void:
	var was_active := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	super.release_pointer()
	# One FIFO cancellation when live capture ends; the authority still owns the
	# input epoch.
	if was_active and phase == 3:
		client.call("send_controls", {}, true)

func can_capture_pointer() -> bool:
	return super.can_capture_pointer() and not zones.projection.is_empty()

func controls_released() -> bool:
	for key: int in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_E, KEY_R, KEY_F, KEY_SHIFT, KEY_CTRL]:
		if Input.is_physical_key_pressed(key): return false
	return not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not controls_released(): return
	super._unhandled_input(event)

func smoke_ready() -> bool:
	if not received_pose or not moved or not fired or client.last_ack <= 10: return false
	if presentation.actors.size() != bot_count + 1: return false
	if zones.projection.is_empty() or zones.projection.zones.size() != 3: return false
	if zone_renderer.rendered.size() != 3: return false
	if not camera.position.is_equal_approx(presentation.eye_position()): return false
	if authority_geometry_hash != catalog.entries[current_id].geometryHash: return false
	for zone: Dictionary in zones.projection.zones:
		if not zone_renderer.markers.has(zone.id): return false
		var marker: Node3D = zone_renderer.markers[zone.id]
		if not marker.position.is_equal_approx(Vector3(zone.x, zone.y, zone.z)): return false
	return true

func _process(delta: float) -> void:
	if smoke and phase == 3 and smoke_ready():
		print("ZONE_IDENTITY_SMOKE_OK ", JSON.stringify({"map":current_id, "mode":selected_mode,
			"actors":presentation.actors.size(), "bots":bot_count, "snapshots":presentation.applied,
			"acks":client.last_ack, "moved":moved, "fired":fired, "zones":zones.projection.zones,
			"markers":zone_renderer.markers.size(), "camera":"authority-eye",
			"geometryHash":authority_geometry_hash}))
		client.disconnect_server()
		get_tree().quit(0)
		return
	super._process(delta)
	if phase == 3 and snapshot_watch.stale():
		zones.clear()
		zone_renderer.clear_round()
