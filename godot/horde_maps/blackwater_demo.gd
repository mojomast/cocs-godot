extends "res://horde/demo.gd"
const BlackwaterCatalog = preload("res://horde_maps/blackwater_catalog.gd")
const BlackwaterMap = preload("res://horde_maps/blackwater.gd")
const Atmosphere = preload("res://native_arenas/identity_environment.gd")
const ID := "blackwater-reclamation"
const MissionGuidance = preload("res://horde/mission_guidance.gd")
class BlackwaterCombat extends "res://world/combat_feedback.gd":
	func _configure_map(state: Dictionary) -> void:
		if not is_instance_valid(effect_camera) or not is_instance_valid(effect_session): return
		var terrain: Node3D = effect_session.world
		if not is_instance_valid(terrain): return
		var id := str(state.get("mapId", ""))
		var key := "%s/%s" % [id, terrain.get_instance_id()]
		if map_key == key: return
		if not map_key.is_empty(): clear_round()
		map_key = key
		var envelope: Dictionary = effect_session.catalog.resolve_envelope(id)
		var arena: Dictionary = envelope.get("arena", {})
		var bounds: Dictionary = arena.get("bounds", {})
		if bounds.is_empty():
			map_error = "Blackwater effects recipe has no bounds"
			return
		var map := {"id":id,"bounds":AABB(Vector3(bounds.minX, -32, bounds.minZ),
			Vector3(bounds.maxX - bounds.minX, 192, bounds.maxZ - bounds.minZ)),"collision_root":terrain}
		occlusion.configure(effect_camera, map)
		map_error = "" if occlusion.ready else "Blackwater collision geometry unavailable"
		if is_instance_valid(impacts):
			impacts.configure(effect_camera, occlusion)
			impacts.set_map(map)
		if is_instance_valid(world_particles):
			var result: Dictionary = world_particles.configure(effect_camera, map)
			if not result.get("ok", false): map_error = str(result.get("error", "Blackwater particles failed"))
		if is_instance_valid(blood_fx):
			var result: Dictionary = blood_fx.configure(effect_camera, map)
			if not result.get("ok", false): map_error = str(result.get("error", "Blackwater blood surfaces failed"))
		if is_instance_valid(projectiles): projectiles.configure_occlusion(occlusion.segment_blocked)
var builder: Node3D
var last_serial := 0
var mission_notice := ""
var mission_notice_until := -1.0

func _ready() -> void:
	super()
	client.events.connect(on_blackwater_events)

func on_blackwater_events(items: Array) -> void:
	for item: Variant in items:
		if not item is Dictionary: continue
		var kind := str(item.get("type", ""))
		if kind not in ["blackwater-station-armed", "blackwater-station-restored"]: continue
		var station := str(item.get("station", "")).replace("-", " ").to_upper()
		mission_notice = "%s · %s" % [station, "REPAIR ARMED · HOLD THE AREA" if kind == "blackwater-station-armed" else "RESTORED · SYSTEM ONLINE"]
		if kind == "blackwater-station-restored" and item.get("pickupId") != null: mission_notice += " · CACHE REFRESHED"
		mission_notice_until = float(item.get("time", 0.0)) + 5.0

func _init() -> void:
	super()
	combat.free()
	combat = BlackwaterCombat.new()
	catalog = BlackwaterCatalog.new()
	sun.free()
	environment.free()

func build_view_layers() -> void:
	add_child(camera)
	camera.far = 2000
	camera.rotation_order = EULER_ORDER_YXZ

func open_catalog() -> bool:
	return catalog.open()

func map_ids() -> Array:
	return [ID]

func default_map_id() -> String:
	return ID

func map_supports_horde(id: String) -> bool:
	return id == ID and catalog.entries.has(id)

func load_selected_map(id: String) -> bool:
	if not map_supports_horde(id): return false
	var next := Node3D.new()
	next.name = "BlackwaterReclamation"
	var map := BlackwaterMap.new()
	next.add_child(map)
	if not map.build(id):
		next.free()
		catalog.error = "Blackwater geometry unavailable"
		return false
	var light := Atmosphere.new()
	next.add_child(light)
	light.build(catalog.resolve_envelope(id))
	var markers := Node3D.new()
	markers.name = "StaticPickupMarkers"
	markers.hide()
	next.add_child(markers)
	if is_instance_valid(world):
		remove_child(world)
		world.free()
	add_child(next)
	world = next
	builder = map
	current_id = id
	world.set_meta("native_geometry_hash", catalog.entries[id].geometryHash)
	return true

func on_started(frame: Dictionary) -> void:
	last_serial = 0
	mission_notice = ""
	mission_notice_until = -1.0
	super.on_started(frame)

func on_snapshot(frame: Dictionary) -> void:
	var envelope: Dictionary = catalog.resolve_envelope(current_id)
	var contract: Dictionary = frame.get("hordeMapContract", {})
	if contract.get("geometryHash") != envelope.get("geometryHash") or contract.get("planHash") != envelope.get("planHash"):
		on_error("Blackwater authority/scene geometry checksum mismatch")
		return
	super.on_snapshot(frame)
	if phase != 3 or not frame.get("state") is Dictionary or not is_instance_valid(builder): return
	var state: Dictionary = frame.state
	var stage: Dictionary = state.get("singleplayer", {}).get("stage", {})
	var mission: Dictionary = state.get("blackwater", {})
	if stage.is_empty() or mission.get("version") != 1:
		on_error("Blackwater authoritative stage/director snapshot missing")
		return
	builder.call("apply_source_stage", stage, str(frame.get("inputEpoch", "")))
	builder.call("apply_station_state", mission)
	var guidance := MissionGuidance.project(mission, stage, presentation.local_actor)
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x<850 or viewport_size.y<600
	if compact:
		var single: Dictionary = state.get("singleplayer",{})
		horde_label.text = "WAVE %d/%d · %s · LIVES %d · ENEMIES %d" % [int(single.get("wave",0)),int(single.get("waveTarget",10)),str(single.get("phase","")).to_upper(),int(single.get("lives",0)),int(single.get("enemiesAlive",0))]
		var boss: Variant = single.get("boss")
		if boss is Dictionary and boss.get("alive",false): horde_label.text += "\n%s · HP %d/%d · PHASE %d" % [str(boss.get("name","BOSS")),int(boss.get("hp",0)),int(boss.get("maxHp",0)),int(boss.get("phase",1))]
	horde_label.text += "\nSYSTEMS %d/4 · %s\n%s" % [guidance.completed,guidance.route,guidance.instruction]
	if not mission_notice.is_empty() and float(state.get("time", 0.0)) <= mission_notice_until and (not compact or mission.get("active") == null):
		horde_label.text += "\n" + mission_notice
	var serial := int(mission.get("serial", 0))
	if serial > last_serial:
		last_serial = serial

func _process(delta: float) -> void:
	super(delta)
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x<850 or viewport_size.y<600
	horde_label.add_theme_font_size_override("font_size",13 if compact else 17)
	var hud: Node = get_node_or_null("GameHUD")
	var top := 70.0
	if hud != null and hud.status_panel.visible: top = hud.status_panel.position.y+hud.status_panel.size.y+8.0
	horde_label.position.y = top
	# Reflow downward after changing viewport/font; allow the label to shrink.
	horde_label.size.y = horde_label.get_minimum_size().y
	if choice_layer != null:
		choice_layer.offset = Vector2(20,top+horde_label.size.y+6)
		choice_scroll.size.y = maxf(32,viewport_size.y-choice_layer.offset.y-(116 if compact else 174))
