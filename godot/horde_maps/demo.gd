extends "res://horde/demo.gd"
const DrydockCatalog = preload("res://horde_maps/catalog.gd")
const Drydock = preload("res://horde_maps/cinderwake.gd")
const DrydockEnvironment = preload("res://native_arenas/identity_environment.gd")
var drydock: Node3D
var horn := AudioStreamPlayer.new()
var horn_key := ""
var horn_epoch := -1

func _ready() -> void:
	# Short captioned three-beat warning. Received source ticks choose each beat;
	# this audio player has no clock, trigger or callback into gameplay.
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(7056)
	for i: int in 3528:
		var envelope := sin(PI * float(i) / 3528.0)
		var tone := sin(TAU * 165.0 * float(i) / 22050.0) + 0.4 * sin(TAU * 330.0 * float(i) / 22050.0)
		samples.encode_s16(i * 2, int(tone * envelope * 3200.0))
	audio.data = samples
	horn.stream = audio
	add_child(horn)
	super()

func _init() -> void:
	super()
	catalog = DrydockCatalog.new()
	sun.free()
	environment.free()

func build_view_layers() -> void:
	add_child(camera)
	camera.far = 2000
	camera.rotation_order = EULER_ORDER_YXZ

func open_catalog() -> bool:
	return catalog.open()

func map_ids() -> Array:
	return ["cinderwake-drydock"]

func default_map_id() -> String:
	return "cinderwake-drydock"

func map_supports_horde(id: String) -> bool:
	return id == "cinderwake-drydock" and catalog.entries.has(id)

func load_selected_map(id: String) -> bool:
	if not map_supports_horde(id): return false
	var next := Node3D.new()
	next.name = "CinderwakeDrydock"
	var builder := Drydock.new()
	next.add_child(builder)
	if not builder.build(id):
		next.free()
		catalog.error = "Cinderwake geometry unavailable"
		return false
	var atmosphere := DrydockEnvironment.new()
	next.add_child(atmosphere)
	atmosphere.build(catalog.resolve_envelope(id))
	var markers := Node3D.new()
	markers.name = "StaticPickupMarkers"
	markers.hide()
	next.add_child(markers)
	if is_instance_valid(world):
		remove_child(world)
		world.free()
	add_child(next)
	world = next
	drydock = builder
	current_id = id
	world.set_meta("native_geometry_hash", catalog.entries[id].geometryHash)
	return true

func on_snapshot(frame: Dictionary) -> void:
	var envelope: Dictionary = catalog.resolve_envelope(current_id)
	var contract: Dictionary = frame.get("hordeMapContract", {})
	if contract.get("geometryHash") != envelope.get("geometryHash") or contract.get("planHash") != envelope.get("planHash"):
		on_error("Cinderwake authority/scene geometry or stage-plan checksum mismatch")
		return
	super.on_snapshot(frame)
	if phase != 3 or not frame.get("state") is Dictionary or not is_instance_valid(drydock): return
	var state: Dictionary = frame.state
	var sp: Dictionary = state.get("singleplayer", {})
	var stage: Dictionary = sp.get("stage", {})
	if stage.is_empty():
		on_error("Cinderwake requires source-authoritative stage snapshots")
		return
	var epoch := int(frame.get("inputEpoch", 0))
	if epoch != horn_epoch:
		horn_epoch = epoch
		horn_key = ""
		horn.stop()
	drydock.call("apply_source_stage", stage, str(frame.get("inputEpoch", "")))
	if bool(state.get("over", false)): return
	var transit: Variant = stage.get("transit")
	if transit is Dictionary:
		var destination := str(envelope.presentation.stages.get(str(transit.to), transit.to))
		var age := float(stage.tick) - float(transit.begunTick)
		if str(transit.phase) == "warning":
			var beat := clampi(int(age / 60.0), 0, 2)
			var key := "%s:%d" % [str(transit.id), beat]
			if key != horn_key:
				horn_key = key
				horn.play()
		var instruction := "BULKHEAD OPENING · %.1fs" % maxf(0.0, (180.0 - age) / 60.0) if str(transit.phase) == "warning" else "WALK TO " + destination
		horde_label.text += "\n%s · ARRIVAL %.1f / 0.5s\nE PASSAGE ALWAYS OPEN%s%s" % [instruction, minf(0.5, float(transit.arrivalTicks) / 60.0), " · BOTH GATES OPEN" if bool(transit.fallback) else "", " · [WARNING HORN]" if str(transit.phase) == "warning" else ""]
	elif stage.get("closure") is Dictionary:
		horde_label.text += "\nBULKHEAD CLOSING · KEEP THRESHOLD CLEAR · E OPEN"
