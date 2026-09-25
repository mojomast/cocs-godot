extends "res://horde/demo.gd"
## Nacre Engine Horde composition.
##
## This is the identity-family sibling of res://horde/demo.tscn. It changes only
## how the world is built: the arena comes from the reviewed identity recipe
## through res://identity_maps/map.gd (the same builder the Deathmatch route
## ships), and the map's own atmosphere is installed once by
## identity_environment.gd (exactly one sun, exactly one WorldEnvironment).
##
## Everything else is the inherited Horde session: shared presentation with
## first-person/ADS, pickups, combat feedback and the delivered effect stack,
## the Horde strip, GameHUD and scoreboard. No gameplay code is duplicated here.
##
## Launch contract (same as the base scene):
##   --map=nacre-engine --endpoint=ws://127.0.0.1:PORT --waves=1..30
##   optional --horde-evidence / --native-trace / --identity-evidence
const NativeCatalog = preload("res://native_arenas/catalog.gd")
const IdentityEnvironment = preload("res://native_arenas/identity_environment.gd")
const IDENTITY_HORDE_MAPS := ["nacre-engine"]
var cache_plan: Array = []
var cache_signs: Dictionary = {}

func _init() -> void:
	# GDScript does not chain _init automatically; run the inherited constructor
	# (it replaces the session client with this family's HordeClient), then
	# specialize the catalog and view layers.
	super()
	catalog = NativeCatalog.new()
	# Identity maps own no light and no WorldEnvironment; map.gd renders geometry
	# only. The base scene's viewer layers would be a second sun and a second
	# environment, so drop them before _ready and install one shared environment
	# with the arena instead.
	sun.free()
	environment.free()

func build_view_layers() -> void:
	add_child(camera)
	camera.far = 2000
	camera.rotation_order = EULER_ORDER_YXZ

func open_catalog() -> bool:
	return catalog.open_dm()

func map_ids() -> Array:
	return IDENTITY_HORDE_MAPS

func default_map_id() -> String:
	return IDENTITY_HORDE_MAPS[0]

func map_supports_horde(id: String) -> bool:
	if id not in IDENTITY_HORDE_MAPS or not catalog.entries.has(id):
		return false
	# The recipe's own mode metadata is authoritative for the identity family;
	# the Deathmatch catalog entry stamps every identity map as "deathmatch".
	var data: Dictionary = catalog.resolve_envelope(id)
	return str(data.get("mode", "")) == "horde"

func load_selected_map(id: String) -> bool:
	if id not in IDENTITY_HORDE_MAPS:
		catalog.error = "Identity Horde map is not allowlisted: " + id
		return false
	var data: Dictionary = catalog.resolve_envelope(id)
	if data.is_empty():
		return false
	if str(data.get("mode", "")) != "horde":
		catalog.error = "Identity map is not authored for Horde: " + id
		return false
	var renderer: String = str(catalog.entries[id].renderer)
	if not ResourceLoader.exists(renderer):
		catalog.error = "Identity Horde renderer is missing: " + id
		return false
	var script: Variant = load(renderer)
	if not script is GDScript or not script.can_instantiate():
		catalog.error = "Identity Horde renderer could not load: " + id
		return false
	var builder: Variant = script.new()
	if not builder is Node3D:
		if builder is Node: builder.free()
		catalog.error = "Identity renderer must be a map-only Node3D: " + id
		return false
	for method: String in ["build", "get_spawn_points", "get_arena_id"]:
		if not builder.has_method(method):
			builder.free()
			catalog.error = "Identity renderer contract is incomplete: " + id
			return false
	var next := Node3D.new()
	next.name = "NativeArena"
	add_child(next)
	next.add_child(builder)
	# identity_maps/map.gd build(id) is idempotent and reports refusal.
	if builder.build(id) != true:
		next.free()
		catalog.error = "Identity Horde renderer refused: " + id
		return false
	if builder.get_arena_id() != id:
		next.free()
		catalog.error = "Identity renderer identity mismatch: " + id
		return false
	var identity_environment := IdentityEnvironment.new()
	next.add_child(identity_environment)
	if not identity_environment.build(data):
		next.free()
		catalog.error = "Identity Horde environment failed: " + id
		return false
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
	world.set_meta("native_geometry_hash", catalog.entries[id].geometryHash)
	# Horde-only, non-colliding wayfinding. The paired Node authority controls
	# actual pickup availability; these signs only read its public snapshot.
	cache_plan = data.arena.get("hordeCaches", [])
	cache_signs.clear()
	var guides := Node3D.new()
	guides.name = "HordeCacheGuides"
	next.add_child(guides)
	for value: Variant in cache_plan:
		if not value is Dictionary: continue
		var cache: Dictionary = value
		var pickup: Array = data.arena.pickups[int(cache.pickupId)]
		var sign := Label3D.new()
		sign.name = "Cache_%d" % int(cache.pickupId)
		sign.position = Vector3(float(pickup[1]), 2.65, float(pickup[2]))
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.pixel_size = 0.007
		sign.font_size = 36
		sign.no_depth_test = false
		sign.modulate = Color("f2c57c")
		sign.text = "%s · WAVE %d\n%s" % [str(pickup[0]).to_upper(), int(cache.wave), str(cache.zone).to_upper()]
		guides.add_child(sign)
		cache_signs[int(cache.pickupId)] = sign
	return true

func on_snapshot(frame: Dictionary) -> void:
	super.on_snapshot(frame)
	if phase != 3 or not frame.get("state") is Dictionary: return
	var state: Dictionary = frame.state
	var public_pickups := {}
	for value: Variant in state.get("pickups", []):
		if value is Dictionary: public_pickups[int(value.get("id", -1))] = value
	var next_cache := ""
	for value: Variant in cache_plan:
		var cache: Dictionary = value
		var id := int(cache.pickupId)
		if not public_pickups.has(id) or not cache_signs.has(id): continue
		var pickup: Dictionary = public_pickups[id]
		var sign: Label3D = cache_signs[id]
		var wait := float(pickup.get("wait", 1e9))
		var locked := wait > 1000.0
		var weapon := str(pickup.get("kind", "")).to_upper()
		sign.text = "%s · %s\n%s" % [weapon, "WAVE %d" % int(cache.wave) if locked else "REFILLING" if wait > 0 else "READY", str(cache.zone).to_upper()]
		sign.modulate = Color("f2c57c") if locked else Color("74e4ce")
		if locked and next_cache.is_empty():
			next_cache = "NEXT CACHE · W%d %s · %s" % [int(cache.wave), weapon, str(cache.zone).to_upper()]
	if not next_cache.is_empty() and not horde.offer_pending:
		horde_label.text += "\n" + next_cache

## Evidence helper: the composition must expose exactly one sun and one
## WorldEnvironment after the arena is built. Counted on the live tree, not on
## the loader's intent.
func environment_census() -> Dictionary:
	var census := {"suns": 0, "environments": 0, "maps": 0, "actors": 0}
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is DirectionalLight3D: census.suns += 1
		if node is WorldEnvironment: census.environments += 1
		if node is MeshInstance3D or node is MultiMeshInstance3D: census.maps += 1
		for child: Node in node.get_children(): stack.push_back(child)
	census.actors = presentation.actors.size()
	return census
