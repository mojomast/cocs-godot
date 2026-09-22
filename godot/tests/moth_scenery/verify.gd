extends SceneTree

const Scenery = preload("res://moth_scenery/scenery.gd")
const Catalog = preload("res://world/catalog.gd")
const Library = preload("res://moth/library.gd")
const DetailControl = preload("res://moth_scenery/detail_control.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("verify")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func freeze(value: Variant) -> void:
	if value is Dictionary:
		for item: Variant in value.values(): freeze(item)
		value.make_read_only()
	elif value is Array:
		for item: Variant in value: freeze(item)
		value.make_read_only()

func finite(value: Variant) -> bool:
	if value is float: return is_finite(value)
	if value is Vector2 or value is Vector3: return value.is_finite()
	if value is Transform3D: return value.origin.is_finite() and value.basis.is_finite()
	if value is AABB: return value.position.is_finite() and value.size.is_finite()
	if value is Color: return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)
	if value is Dictionary:
		for item: Variant in value.values():
			if not finite(item): return false
	if value is Array:
		for item: Variant in value:
			if not finite(item): return false
	return true

func inspect_geometry(scenery: Node3D, map: Dictionary) -> void:
	var snapshot: Dictionary = scenery.placement_snapshot()
	check(finite(snapshot), "finite placements " + map.id)
	var shape: Mesh
	for child: Node in scenery.get_children():
		check(child is MultiMeshInstance3D, "only batched visual nodes")
		check(not child.is_processing() and not child.is_physics_processing(), "no per-frame scripts")
		check(child.get_child_count() == 0, "no hidden gameplay children")
		check(child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "no scenic shadows")
		if shape == null: shape = child.multimesh.mesh
		check(shape == child.multimesh.mesh, "one shared quad mesh per map")
		check(child.material_override.shader in [Scenery.PanelShader, Scenery.MoteShader], "only shared shaders")
		for i in range(child.multimesh.instance_count):
			check(finite(child.multimesh.get_instance_transform(i)), "finite renderer transform")
	for plate: Dictionary in snapshot.plates:
		var block: Dictionary = map.blocks[plate.block]
		var center := Vector3(block.x, 0, block.z)
		var normal: Vector3 = plate.normal
		var half_depth: float = (block.d if normal.z != 0 else block.w) * 0.5
		for x in [-0.5, 0.5]:
			for y in [-0.5, 0.5]:
				var corner: Vector3 = plate.transform * Vector3(x, y, 0)
				# Independent world-space corner check, not the planner's size test.
				check(absf((corner - center).dot(normal) - half_depth - Scenery.FACE_OFFSET) < 0.00002, "flush face distance")
				check(corner.y >= Scenery.INSET - 0.00002 and corner.y <= block.h - Scenery.INSET + 0.00002, "vertical silhouette")
				var lateral := absf(corner.x - block.x) if normal.z != 0 else absf(corner.z - block.z)
				var half_span: float = (block.w if normal.z != 0 else block.d) * 0.5
				check(lateral <= half_span - Scenery.INSET + 0.00002, "within single solid span / no doorway bridging")
		check(not block.kind in ["soccer-goal", "race-rail", "cover", "crate", "race-apron", "race-infield", "tree", "tunnel"], "no false gameplay cue anchor")
	for pocket: Dictionary in snapshot.pockets:
		check(Scenery._empty_box(map.blocks, pocket.bounds), "ambient pocket excludes solids")
		for point: Dictionary in pocket.points:
			for clock in [0.0, 1.0, 20.0, 4000.0]:
				var speed := 0.08 if map.id == "tidal-citadel" else (-0.025 if map.id in ["ember-crucible", "asterion-relay"] else 0.024)
				var age := fposmod(point.custom.g + clock * speed, 1.0)
				var position: Vector3 = point.position
				position.y += (point.custom.g - age) * pocket.height
				position.x += sin(clock * 0.21 + point.custom.r * 30.0) * 0.18
				position.z += cos(clock * 0.16 + point.custom.r * 25.0) * 0.18
				check(pocket.bounds.has_point(position), "finite bounded shader motion")

func verify() -> void:
	var catalog := Catalog.new()
	check(catalog.open(), "actual source catalog")
	check(catalog.entries.size() == 9, "exact existing nine maps")
	var viewer = load("res://world/viewer.gd").new()
	root.add_child(viewer)
	viewer.set_process(false)
	var control := DetailControl.new()
	root.add_child(control)
	var results: Array = []
	for id: String in catalog.entries:
		check(viewer.load_map(id), "actual viewer load " + id)
		check(viewer.world.get_node_or_null("MothScenery") != null, "production viewer composes scenery")
		# The integrated viewer already creates this layer. Establish the geometry
		# baseline without it before testing repeated create/clear ownership.
		Scenery.clear(viewer.world)
		var map: Dictionary = catalog.resolve_map(id)
		var source_hash := JSON.stringify(map).sha256_text()
		freeze(map)
		var base_children: int = viewer.world.get_child_count()
		var original_transforms: Array = []
		for child: Node3D in viewer.world.get_children(): original_transforms.append(child.transform)
		var scenery = Scenery.create(map, viewer.world)
		control.bind_scenery(scenery)
		var counts: Dictionary = scenery.stats()
		var hash: String = scenery.geometry_hash()
		check(counts.surfaces > 0 and counts.surfaces <= counts.surface_limit and counts.surfaces <= Scenery.MAX_SURFACES, "surface ceiling " + id)
		if counts.surfaces == 0:
			viewer.free()
			quit(1)
			return
		check(counts.motes <= counts.mote_limit and counts.motes <= Scenery.MAX_MOTES and counts.motes <= 512, "particle ceiling " + id)
		check(counts.batches <= Scenery.MAX_BATCHES, "draw-batch ceiling " + id)
		check(not scenery.is_processing() and not scenery.is_physics_processing(), "no controller process")
		inspect_geometry(scenery, map)
		check(viewer.world.get_meta("semantic_block_count") == map.blocks.size(), "source block count unchanged")
		check(viewer.world.get_meta("semantic_triangle_count") == map.get("terrain", {}).get("support_triangles", []).size(), "source support count unchanged")
		for i in range(original_transforms.size()): check(viewer.world.get_child(i).transform == original_transforms[i], "base geometry untouched")
		var positions: Array = []
		for plate: Dictionary in scenery.placement_snapshot().plates:
			positions.append({"block": plate.block, "kind": plate.kind, "position": [plate.transform.origin.x, plate.transform.origin.y, plate.transform.origin.z], "normal": [plate.normal.x, plate.normal.y, plate.normal.z], "size": [plate.size.x, plate.size.y]})
		var pockets: Array = []
		for pocket: Dictionary in scenery.placement_snapshot().pockets:
			var points: Array = []
			for point: Dictionary in pocket.points: points.append([point.position.x, point.position.y, point.position.z])
			pockets.append({"anchor_block": pocket.block, "min": [pocket.bounds.position.x, pocket.bounds.position.y, pocket.bounds.position.z], "size": [pocket.bounds.size.x, pocket.bounds.size.y, pocket.bounds.size.z], "initial_positions": points})
		var first_material: WeakRef = weakref(scenery.get_child(0).material_override)
		control.select(Scenery.Detail.LOW)
		control.item_selected.emit(Scenery.Detail.LOW)
		var low: Dictionary = scenery.stats()
		check(low.motes == 0 and low.surfaces > 0 and low.surfaces <= counts.surfaces, "low actually frees ambient and optional plates")
		check(first_material.get_ref() == null, "rebuild releases material resources")
		control.select(Scenery.Detail.OFF)
		control.item_selected.emit(Scenery.Detail.OFF)
		check(scenery.get_child_count() == 0 and scenery.stats().surfaces == 0 and scenery.stats().motes == 0, "off frees every renderer")
		control.select(Scenery.Detail.FULL)
		control.item_selected.emit(Scenery.Detail.FULL)
		check(scenery.stats() == counts and scenery.geometry_hash() == hash, "detail restores deterministic plan")
		var node_ref: WeakRef = weakref(scenery)
		var mesh_ref: WeakRef = weakref(scenery.get_child(0).multimesh)
		var material_ref: WeakRef = weakref(scenery.get_child(0).material_override)
		scenery = Scenery.decorate(map, viewer.world)
		check(node_ref.get_ref() == null and mesh_ref.get_ref() == null and material_ref.get_ref() == null, "same-frame prior node/resources freed")
		check(viewer.world.get_child_count() == base_children + 1, "idempotent one owned root")
		check(scenery.geometry_hash() == hash, "repeated deterministic geometry " + id)
		check(JSON.stringify(map).sha256_text() == source_hash, "recursive frozen map unchanged " + id)
		var edited: Dictionary = scenery.placement_snapshot()
		edited.plates.clear()
		check(scenery.geometry_hash() == hash, "diagnostic copies isolated")
		results.append({"map": id, "geometry_sha256": hash, "source_map_sha256": source_hash, "full": counts, "low": low, "mounted_positions": positions, "ambient_pockets": pockets})
		print("MOTH_SCENERY_MAP ", id, " full=", counts, " low=", low.surfaces, " hash=", hash)
		var final_ref: WeakRef = weakref(scenery)
		Scenery.clear(viewer.world)
		Scenery.clear(viewer.world)
		check(final_ref.get_ref() == null and viewer.world.get_child_count() == base_children, "idempotent clear / per-map release")
		await process_frame
	# Unknown / malformed input cannot yield NaN or accidental full-map effects.
	var unknown := Scenery.create({"id": "unknown"}, viewer.world)
	check(unknown.get_child_count() == 0, "unknown map empty")
	var malformed := Scenery.create({"id": "meridian-exchange", "blocks": [{"x": NAN, "z": 0, "w": 2, "d": 2, "h": 5, "kind": "building"}]}, viewer.world)
	check(malformed.stats().surfaces == 0 and malformed.stats().motes == 0, "nonfinite blocks rejected")
	check(Library.cache_stats().textures <= Library.MAX_TEXTURES, "bounded external resource cache")
	viewer.free()
	control.item_selected.emit(Scenery.Detail.LOW)
	control.free()
	await process_frame
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var file := FileAccess.open(args[0], FileAccess.WRITE)
		file.store_string(JSON.stringify({"maps": results, "failures": failures, "engine": Engine.get_version_info().string}, "\t") + "\n")
	print("MOTH_SCENERY_VERIFY maps=9 deterministic=true immutable=true finite=true teardown=true failures=", failures)
	quit(0 if failures == 0 else 1)
