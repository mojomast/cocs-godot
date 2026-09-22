extends SceneTree
const Pickups = preload("res://world/pickups.gd")
const Catalog = preload("res://combat_pickup_assets/catalog.gd")
var checks := 0
var failed := false

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error(message)

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void: push_error("pickup validation watchdog"); quit(1))
	call_deferred("run")

func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/combat_pickup_assets/source.json"))
	var pristine := JSON.stringify(fixture)
	var view := Pickups.new()
	root.add_child(view)
	var initial: Dictionary = fixture.frames[0].state
	view.apply_state(initial)
	var identities := {}
	var mesh_ids := {}
	var material_ids := {}
	var maximum_triangles := 0
	for p: Dictionary in initial.pickups:
		var node: Node3D = view.markers[int(p.id)]
		identities[int(p.id)] = node.get_instance_id()
		check(node.get_child_count() == 4, "fixed four render nodes per source ID")
		var triangles := 0
		for child: MeshInstance3D in node.get_children():
			check(child.mesh.get_surface_count() == 1, "single surface per draw")
			check(child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "no shadow-pass draw multiplication")
			var aabb := child.mesh.get_aabb()
			check(aabb.size.x <= 0.8 and aabb.size.y <= 0.8 and aabb.size.z <= 0.8, "compact silhouette")
			triangles += child.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
			check(child.get_child_count() == 0, "render leaves have no hidden labels/colliders")
		maximum_triangles = maxi(maximum_triangles, triangles)
		check(triangles <= 1400, "triangle cap")
		mesh_ids[int(p.id)] = node.parts[1].mesh.get_instance_id()
		check(not material_ids.has(node.energy.get_instance_id()), "independent mutable shader material")
		material_ids[node.energy.get_instance_id()] = true
		check(node.energy != node.halo, "ring/core uniforms isolated")
		check(node.energy.get_shader_parameter("base_map") != null and node.energy.get_shader_parameter("lut_r") != null, "real Moth resources")
	var first: Node3D = view.markers[0]
	first._process(0.1)
	check(first.effect_time > 0, "visible decorative clock")
	view.apply_state(fixture.frames[1].state)
	check(not first.visible and first.effect_time == 0 and not first.is_processing(), "actual source collection hides/resets/stops presentation")
	first._process(100.0)
	check(not first.visible and first.effect_time == 0, "no local respawn even after wait elapsed")
	view.apply_state(fixture.frames[2].state)
	for node: Node3D in view.markers.values(): check(not node.visible, "source waits hide every kind")
	view.apply_state(fixture.frames[3].state)
	for id: int in identities:
		check(view.markers[id].get_instance_id() == identities[id], "same instance across availability changes")
		check(view.markers[id].parts[1].mesh.get_instance_id() == mesh_ids[id], "same mesh across availability changes")
		check(view.markers[id].visible, "only source snapshot respawns model")
	var repeated := initial.duplicate(true)
	repeated.pickups.reverse()
	for i in range(200): view.apply_state(repeated)
	check(view.get_child_count() == initial.pickups.size(), "no snapshot/reorder node growth")
	for id: int in identities: check(view.markers[id].get_instance_id() == identities[id], "reorder identity")
	var duplicate: Dictionary = initial.pickups[0].duplicate(true)
	duplicate.id = 99
	view.apply_state({"pickups": [initial.pickups[0], duplicate]})
	check(view.get_child_count() == 2, "stale IDs removed immediately")
	check(view.markers[0].parts[1].mesh == view.markers[99].parts[1].mesh, "immutable geometry shared across IDs")
	check(view.markers[0].energy != view.markers[99].energy, "shader materials independent across same kind")
	check(view.markers[0].energy.get_shader_parameter("base_map") == view.markers[99].energy.get_shader_parameter("base_map"), "immutable Moth textures shared")
	var retained: Node3D = view.markers[99]
	var render_id: int = retained.parts[1].get_instance_id()
	for i in range(200):
		duplicate.kind = "unrecognized-%d" % i
		view.apply_state({"pickups": [duplicate]})
		check(retained.parts[1].get_instance_id() == render_id, "kind change reuses fixed nodes")
	check(Catalog.cache_size() <= Catalog.KINDS.size(), "unknown kinds cannot grow geometry cache")
	check(retained.parts[1].mesh == Catalog.meshes("unknown")[1], "unknown fallback, no false weapon identity")
	check(retained.get_meta("kind") == duplicate.kind, "public metadata retains source kind")
	check(JSON.stringify(fixture) == pristine, "all snapshot actors/pickups/events remain immutable")
	var stale: WeakRef = weakref(retained)
	var stale_material: WeakRef = weakref(retained.energy)
	retained = null
	view.apply_state({})
	check(view.markers.is_empty() and view.get_child_count() == 0 and stale.get_ref() == null, "missing list frees stale resources/nodes")
	check(stale_material.get_ref() == null, "removed marker releases its unique mutable shader material")
	for i in range(10):
		view.apply_state(initial)
		view.clear_round()
		check(view.markers.is_empty() and view.get_child_count() == 0, "repeat clear/reset is empty")
	print("PICKUP_ASSETS_OK checks=", checks, " kinds=", initial.pickups.size(), " max_triangles=", maximum_triangles, " draws_per_pickup=4 nodes_per_pickup=5 particles=0 cache=", Catalog.cache_size())
	view.free()
	quit(1 if failed else 0)
