extends Node3D
## Presentation-only child. Catalog establishes placement; recipient establishes state.
const Instrument = preload("res://lattice_assets/instrument.gd")
const Recipes = preload("res://lattice_assets/recipes.gd")
var session: Node
var map_id := ""
var mode := ""
var authored: Dictionary = {}
var objectives: Dictionary = {}
var static_props: Array[Node3D] = []

func attach(source_session: Node) -> void:
	session = source_session
	session.client.snapshot.connect(func(_frame: Dictionary) -> void: receive())
	bind_map(session.current_id, session.selected_mode, session.catalog.resolve_map(session.current_id))

func clear() -> void:
	for child: Node in get_children(): child.free()
	objectives.clear()
	static_props.clear()
	authored.clear()

func bind_map(id: String, selected_mode: String, source: Dictionary) -> void:
	clear()
	map_id = id
	mode = selected_mode
	if not Recipes.PALETTES.has(id) or source.get("id") != id: return
	for raw: Variant in source.get("nodes", []):
		if not raw is Dictionary or not valid_position(raw): continue
		if raw.get("archetype") not in ["hq","front","relay","economy"]: continue
		if not raw.get("id") is String or authored.has(raw.id) or authored.size() >= 16: continue
		authored[raw.id] = raw.duplicate(true)
		var prop := make_prop(raw.archetype,raw)
		prop.hide()
		objectives[raw.id] = prop
	# Depots are static authored service markings, never claims about vehicles/owner.
	for raw: Variant in source.get("depots", []):
		if static_props.size() >= 8: break
		if raw is Dictionary and valid_position(raw): static_props.append(make_prop("depot",raw))
	# Operations sockets coincide with HQ/relay instruments. Add sealed cartridges
	# only as an authored subtype, without exposing mission or terminal state.
	if selected_mode == "cocs-coop":
		var sockets := {}
		for raw: Variant in source.get("terminals", []):
			if sockets.size() >= 3: break
			if not raw is Dictionary or not valid_position(raw): continue
			if sockets.has(raw.get("nodeId")): continue
			for id_key: String in objectives:
				if raw.get("nodeId") != id_key: continue
				var anchor: Dictionary = authored[id_key]
				if float(raw.x) != float(anchor.x) or float(raw.z) != float(anchor.z): continue
				if float(raw.y) != float(anchor.y): continue
				sockets[id_key] = true
				var cartridge := Instrument.new()
				cartridge.build("operations",map_id)
				# Retain only cartridge detail, not a second base/owner display.
				for piece: Node in cartridge.get_children():
					if not str(piece.name).begins_with("Cartridge") and not str(piece.name).begins_with("Latch"): piece.free()
				cartridge.position.y = 1.5
				objectives[id_key].add_child(cartridge)

static func valid_position(raw: Dictionary) -> bool:
	for axis: String in ["x","y","z"]:
		var value: Variant = raw.get(axis)
		if not (value is int or value is float) or not is_finite(float(value)): return false
	return true

func make_prop(kind: String, raw: Dictionary) -> Node3D:
	var prop := Instrument.new()
	prop.build(kind,map_id)
	prop.position = Vector3(raw.x,raw.y,raw.z)
	prop.set_meta("authored_id",str(raw.get("id","")))
	add_child(prop)
	return prop

func clear_recipient() -> void:
	for prop: Node3D in objectives.values():
		prop.hide()
		prop.apply_recipient({})

func apply_projection(projection: Dictionary) -> void:
	clear_recipient()
	if projection.get("map") != map_id or projection.get("mode") != mode: return
	for raw: Variant in projection.get("nodes", []):
		if not raw is Dictionary or not objectives.has(raw.get("id")): continue
		var anchor: Dictionary = authored[raw.id]
		# Refuse mismatched coordinates instead of relocating an authored machine.
		if raw.get("x") != anchor.x or raw.get("z") != anchor.z: continue
		if raw.has("y") and raw.y != anchor.y: continue
		var prop: Node3D = objectives[raw.id]
		prop.show()
		prop.apply_recipient(raw)

func receive() -> void:
	if not is_instance_valid(session): return
	if map_id != session.current_id or mode != session.selected_mode:
		bind_map(session.current_id,session.selected_mode,session.catalog.resolve_map(session.current_id))
	if session.phase != 3 or session.client.projection_actor != session.client.actor_id:
		clear_recipient()
		return
	apply_projection(session.client.projection)

func _process(_delta: float) -> void:
	if not is_instance_valid(session): return
	if session.phase != 3 or session.client.projection.is_empty() or session.snapshot_watch.stale(): clear_recipient()
