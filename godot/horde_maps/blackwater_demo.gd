extends "res://horde/demo.gd"
const BlackwaterCatalog = preload("res://horde_maps/blackwater_catalog.gd")
const BlackwaterMap = preload("res://horde_maps/blackwater.gd")
const Atmosphere = preload("res://native_arenas/identity_environment.gd")
const ID := "blackwater-reclamation"
var builder: Node3D
var last_serial := 0

func _init() -> void:
	super()
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
	var target := ""
	for item: Variant in mission.get("stations", []):
		if not item is Dictionary or item.get("id") in mission.get("completed", []) or not item.get("available", false): continue
		target = "%s · %.1f / %.1fs" % [str(item.caption), float(item.progress), float(item.required)]
		if str(item.id) == str(mission.get("active", "")): target += " · WORKING"
		else: target += " · E TO ARM"
		break
	if not target.is_empty(): horde_label.text += "\n" + target
	var transit: Variant = stage.get("transit")
	if transit is Dictionary:
		var to := str(transit.get("to", ""))
		horde_label.text += "\nFLOODGATE %s · %s · WALK TO %s" % [to, "OPENING" if str(transit.get("phase", "")) == "warning" else "OPEN", str(envelope.presentation.stages.get(to, to))]
	var serial := int(mission.get("serial", 0))
	if serial > last_serial:
		last_serial = serial
		horde_label.text += "\nSYSTEM RESTORED · SUPPLY CACHE AVAILABLE"
