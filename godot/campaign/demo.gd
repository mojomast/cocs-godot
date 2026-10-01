extends "res://world/session.gd"
## Real shared session composition, with port-owned campaign content and protocol.
const CampaignCatalog = preload("res://campaign/catalog.gd")
const CampaignClient = preload("res://campaign/client.gd")
const CampaignModel = preload("res://campaign/model.gd")
const CampaignHUD = preload("res://campaign/hud.gd")
const SourceVisual = preload("res://source_operators/operator_visual.gd")
const Telegraphs = preload("res://campaign/telegraphs.gd")
const CampaignEnvironment = preload("res://campaign/environment.gd")
const StoryDirector = preload("res://campaign/story_director.gd")
const StoryWidgets = preload("res://campaign/story_widgets.gd")

class CampaignCombat extends "res://world/combat_feedback.gd":
	## The shared feedback catalog knows source maps only. Supply the built native
	## colliders directly to its existing visibility, impact and particle services.
	func _configure_map(state: Dictionary) -> void:
		if not is_instance_valid(effect_camera) or not is_instance_valid(effect_session): return
		var terrain: Node3D = effect_session.world
		if not is_instance_valid(terrain): return
		var id := str(state.get("mapId", ""))
		var key := "%s/%s" % [id, terrain.get_instance_id()]
		if map_key == key: return
		if not map_key.is_empty(): clear_round()
		map_key = key
		var arena: Dictionary = effect_session.catalog.resolve_map(id)
		var bounds: Dictionary = arena.get("bounds", {})
		if bounds.is_empty():
			map_error = "Campaign effects recipe has no bounds"
			return
		var map := {"id":id, "bounds":AABB(Vector3(bounds.minX, -32, bounds.minZ), Vector3(bounds.maxX - bounds.minX, 192, bounds.maxZ - bounds.minZ)), "collision_root":terrain}
		occlusion.configure(effect_camera, map)
		map_error = "" if occlusion.ready else "Campaign collision geometry unavailable"
		if is_instance_valid(impacts):
			impacts.configure(effect_camera, occlusion)
			impacts.set_map(map)
		if is_instance_valid(world_particles):
			var result: Dictionary = world_particles.configure(effect_camera, map)
			if not result.get("ok", false): map_error = str(result.get("error", "Campaign particle configuration failed"))
		if is_instance_valid(blood_fx):
			var result: Dictionary = blood_fx.configure(effect_camera, map)
			if not result.get("ok", false): map_error = str(result.get("error", "Campaign surface configuration failed"))
		if is_instance_valid(projectiles): projectiles.configure_occlusion(occlusion.segment_blocked)

var campaign := CampaignModel.new()
var campaign_hud: Control
var difficulty := "normal"
var startup_error := ""
var action_pending := false
var authority_geometry_hash := ""
var robot_instances := 0
var ground_tells := Telegraphs.new()
var robot_voices := preload("res://campaign/robot_voices.gd").new()
var story_director := StoryDirector.new()
var interlude_director := preload("res://campaign/interlude_director.gd").new()
var story_widgets: Control
var solo_cheats: CanvasLayer

func _init() -> void:
	catalog = CampaignCatalog.new()
	client.free()
	client = CampaignClient.new()
	combat.free()
	combat = CampaignCombat.new()
	sun.free()
	environment.free()

static func parse_options(args: PackedStringArray) -> Dictionary:
	var options := {"map":"rootfall-verge", "endpoint":"", "difficulty":"normal", "error":""}
	for arg: String in args:
		for key: String in ["map", "endpoint", "difficulty"]:
			if arg.begins_with("--" + key + "="): options[key] = arg.trim_prefix("--" + key + "=")
		if arg.begins_with("--mode=") and arg != "--mode=campaign": options.error = "This route requires campaign mode."
	if options.map not in CampaignCatalog.MAP_IDS: options.error = "Unknown campaign chapter."
	if options.difficulty not in ["easy", "normal", "hard"]: options.error = "Difficulty must be easy, normal, or hard."
	var match_url := RegEx.create_from_string("^ws://127\\.0\\.0\\.1:([1-9][0-9]{0,4})/native-campaign$").search(options.endpoint)
	if match_url == null or match_url.get_string() != options.endpoint or match_url.get_string(1).to_int() > 65535:
		options.error = "Launch with an owned ws://127.0.0.1:PORT/native-campaign endpoint."
	return options

func _ready() -> void:
	phase = -2
	camera.far = 2000
	camera.rotation_order = EULER_ORDER_YXZ
	add_child(camera)
	camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	for item: Control in [label, selector, combat_label]:
		layer.add_child(item)
		item.hide()
	presentation.actor_visual_factory = create_visual
	presentation.interpolate_remote = true
	for child: Node in [pickups, presentation, combat, client, ground_tells, robot_voices, story_director, interlude_director]: add_child(child)
	var voice_settings := SettingsAccess.service()
	if voice_settings != null:
		voice_settings.audio_preferences_changed.connect(robot_voices.apply_settings)
		robot_voices.apply_settings(voice_settings.values)
	else: robot_voices.apply_settings({})
	# Campaign owns its compact mission HUD; don't print the transient shared
	# quality tutorial across objective text. F9/F10 remain available explicitly.
	if is_instance_valid(combat.quality_controls): combat.quality_controls.set_shortcut_hint(false)
	client.connection_error.connect(on_error)
	client.transport_dropped.connect(on_transport_dropped)
	client.connect("input_reset", func(_reason: String) -> void: release_pointer())
	client.lobby.connect(on_lobby)
	client.started.connect(on_started)
	client.snapshot.connect(on_snapshot)
	client.results.connect(on_results)
	client.events.connect(func(items: Array) -> void:
		if phase == 3:
			ground_tells.apply_events(items)
			combat.apply_events(items, client.actor_id)
			av_events(items))
	campaign_hud = CampaignHUD.new()
	layer.layer = 5
	layer.add_child(campaign_hud)
	campaign_hud.bind_session(self)
	story_widgets = StoryWidgets.new()
	layer.add_child(story_widgets)
	story_widgets.session = self
	solo_cheats = preload("res://debug/solo_cheats.gd").new()
	add_child(solo_cheats)
	solo_cheats.bind_session(self)
	var args := OS.get_cmdline_user_args()
	smoke = "--smoke" in args
	trace_enabled = "--native-trace" in args
	var options := parse_options(args)
	if not options.error.is_empty():
		on_error(options.error)
		return
	endpoint = options.endpoint
	difficulty = options.difficulty
	selected_mode = "campaign"
	if not catalog.open() or not load_map(options.map):
		on_error(catalog.error)
		return
	ids = CampaignCatalog.MAP_IDS.duplicate()
	campaign_hud.show_brief(current_id)
	if smoke: launch_campaign()

func create_visual(actor: Dictionary, local_id: int) -> Node3D:
	if actor.get("npcModel") in CampaignModel.ROBOTS:
		var script: GDScript = load("res://campaign/robot_visual.gd")
		var robot: Node3D = script.new()
		robot.configure(actor, local_id)
		robot_instances += 1
		return robot
	var operator := SourceVisual.new()
	operator.local_id = local_id
	return operator

func load_map(id: String) -> bool:
	if not catalog.entries.has(id):
		catalog.error = "Unknown campaign map: " + id
		return false
	var script: GDScript = load("res://campaign/terrain.gd")
	if script == null or not script.can_instantiate():
		catalog.error = "Campaign terrain unavailable"
		return false
	var next: Node3D = script.new()
	add_child(next)
	if next.build(id) != true:
		next.free()
		catalog.error = "Campaign terrain refused: " + id
		return false
	var markers := Node3D.new()
	markers.name = "StaticPickupMarkers"
	markers.hide()
	next.add_child(markers)
	var atmosphere := CampaignEnvironment.new()
	if not atmosphere.build(next.recipe):
		atmosphere.free()
		next.free()
		catalog.error = "Campaign daylight recipe refused: " + id
		return false
	if is_instance_valid(world): world.free()
	next.add_child(atmosphere)
	world = next
	current_id = id
	ground_tells.bind_terrain(world)
	story_director.clear_round()
	interlude_director.clear_round()
	if phase == -2: position_briefing_camera()
	return true

func position_briefing_camera() -> void:
	# Camera only: the map's persistent CampaignEnvironment lights every phase.
	var recipe: Dictionary = world.recipe
	var start: Dictionary = recipe.campaign.anchors.start
	var origin := Vector3(start.x, start.y, start.z)
	var target := origin + Vector3(0, 0, -20)
	for point: Dictionary in recipe.campaign.criticalPath:
		var next := Vector3(point.x, point.y, point.z)
		if Vector2(next.x - origin.x, next.z - origin.z).length() >= 16:
			target = next
			break
	var direction := Vector3(target.x - origin.x, 0, target.z - origin.z).normalized()
	var eye := origin - direction * 6 + Vector3(direction.z * 4, 8, -direction.x * 4)
	for entry: Dictionary in recipe.get("cameras", []):
		# Overview/gallery cameras may be beyond the near-world visibility bands.
		if entry.get("id") == "briefing" and entry.get("at") is Array and entry.at.size() == 3 and entry.get("target") is Array and entry.target.size() == 3:
			eye = Vector3(entry.at[0], entry.at[1], entry.at[2])
			target = Vector3(entry.target[0], entry.target[1], entry.target[2])
			break
	# Preview placement is cosmetic. The first received actor still seeds real play.
	eye.y = maxf(eye.y, float(world.height_at(eye.x, eye.z)) + 6)
	camera.position = eye
	if eye.distance_to(target) > 0.1: camera.look_at(target)

func launch_campaign() -> void:
	if phase != -2: return
	campaign_hud.hide_brief()
	elapsed = 0
	connect_selected_match()

func on_lobby(frame: Dictionary) -> void:
	if phase == 1:
		if client.send_frame({"type":"host", "mapId":current_id, "config":{"mode":"campaign", "difficulty":difficulty}}) != OK:
			on_error("Campaign configuration could not be queued.")
		else: phase = 2
		return
	super.on_lobby(frame)

func on_started(frame: Dictionary) -> void:
	robot_voices.clear_round()
	ground_tells.clear_round()
	story_director.clear_round()
	var id := str(frame.get("mapId", ""))
	if not catalog.entries.has(id) or frame.get("geometryHash") != catalog.entries[id].geometryHash:
		on_error("Campaign authority and terrain geometry differ.")
		return
	if id != current_id and not load_map(id):
		on_error(catalog.error)
		return
	authority_geometry_hash = frame.geometryHash
	campaign.state.clear()
	action_pending = false
	audiovisual_round = "" # every chapter/checkpoint start owns a fresh audio epoch
	super.on_started(frame)

func on_snapshot(frame: Dictionary) -> void:
	if phase != 3: return
	if not campaign.apply(frame.state.get("campaign")):
		on_error(campaign.error)
		return
	var checking := smoke
	smoke = false
	super.on_snapshot(frame)
	smoke = checking
	ground_tells.apply_state(frame.state)
	story_director.apply(campaign.state.get("story", {}), current_id)
	interlude_director.apply(campaign.state.get("interludes", {}), current_id)
	story_widgets.observe(campaign.state.get("story", {}), campaign.playing() and not action_pending and application_focused and phase == 3, campaign.state.get("interludes", {}))
	robot_voices.set_active(campaign.playing() and vehicle_shots_allowed() and not action_pending)
	robot_voices.apply_state(frame.state, camera.global_position)
	campaign_hud.observe_boss(frame.state)
	if not campaign.playing():
		release_pointer()
		ground_tells.clear_round()
		story_widgets.observe({}, false)
	campaign_hud.refresh()
	if checking and moved and fired and client.last_ack > 10 and robot_instances > 0 and combat.shots > 0 and combat.map_error.is_empty() and combat.occlusion.ready and authority_geometry_hash == catalog.entries[current_id].geometryHash:
		print("CAMPAIGN_SMOKE_OK ", JSON.stringify({"map":current_id, "moved":moved, "fired":fired, "acks":client.last_ack, "robotsLoaded":robot_instances, "combatShots":combat.shots, "geometryHash":authority_geometry_hash, "firstPerson":is_instance_valid(first_person)}))
		client.disconnect_server()
		get_tree().quit(0)

func on_results(frame: Dictionary) -> void:
	robot_voices.set_active(false)
	if phase != 3: return
	on_snapshot(frame)
	if phase != 3: return
	av_finish(frame.state)
	phase = 4
	story_widgets.observe({}, false)
	robot_voices.clear_round()
	release_pointer()
	campaign_hud.refresh()

func can_capture_pointer() -> bool:
	return campaign.playing() and not action_pending and super.can_capture_pointer()

var smoke_route := preload("res://campaign/smoke_route.gd").new()
var smoke_route_round := -1

func smoke_deadline() -> float:
	return 90.0

func smoke_controls(controls: Dictionary) -> Dictionary:
	if not campaign.playing() or action_pending: return controls
	if smoke_route_round != round_starts:
		var recipe: Dictionary = world.get("recipe")
		if not smoke_route.configure(recipe, elapsed):
			on_error(smoke_route.error)
			return controls
		smoke_route_round = round_starts
	var actor: Dictionary = presentation.local_actor
	var feet := Vector3(float(actor.get("x", 0)), float(actor.get("y", 0)), float(actor.get("z", 0)))
	var guidance: Dictionary = smoke_route.sample(feet, elapsed)
	if not smoke_route.error.is_empty():
		on_error(smoke_route.error)
		return controls
	controls.merge(guidance, true)
	yaw = float(guidance.yaw)
	pitch = float(guidance.pitch)
	return controls

func _process(delta: float) -> void:
	super._process(delta)
	robot_voices.set_active(campaign.playing() and vehicle_shots_allowed() and not action_pending)
	for visual: Node3D in presentation.actors.values():
		if visual.has_method("select_distance"):
			visual.select_distance(camera.position.distance_to(visual.position))

func request_restart() -> void:
	request_campaign_action(campaign.action())

func request_campaign_action(action: String) -> void:
	if action_pending or phase not in [3, 4] or action.is_empty(): return
	if action != "restart" and action != campaign.action(): return
	release_pointer()
	if client.call("campaign_action", action) != OK:
		on_error("Campaign action could not be queued.")
		return
	action_pending = true
	robot_voices.clear_round()
	phase = 20

func release_pointer() -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	super.release_pointer()
	if is_instance_valid(story_widgets): story_widgets.refresh()
	if captured and phase == 3: client.call("send_controls", {}, true)

func leave_campaign() -> void:
	robot_voices.clear_round()
	release_pointer()
	ground_tells.clear_round()
	story_director.clear_round()
	client.disconnect_server()
	get_tree().quit()

func on_error(message: String) -> void:
	robot_voices.clear_round()
	if is_instance_valid(story_widgets): story_widgets.observe({}, false)
	startup_error = message
	super.on_error(message)
	label.hide()
	if is_instance_valid(campaign_hud): campaign_hud.refresh()

func on_transport_dropped(message: String) -> void:
	robot_voices.clear_round()
	if is_instance_valid(story_widgets): story_widgets.observe({}, false)
	super.on_transport_dropped(message)
