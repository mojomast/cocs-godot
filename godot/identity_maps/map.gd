extends Node3D
## Map-only deterministic presentation. Source Node Match remains authoritative.
##
## Render geometry and collision are deliberately different products:
##   * art[]     renders exactly as authored. It owns no physics.
##   * blocks / terrain.surfaces / terrain.walls render AND own physics, so the
##     Godot static world is byte-identical to the source's ray triangles and
##     the source's obstruction segments.
## This is why the map can drop 2.9-14.8 s of wall-scan cost without a single
## decorative surface silently losing its ray or gaining false cover.
const Style = preload("res://identity_maps/style.gd")
const SignatureFx = preload("res://identity_maps/signature_fx.gd")
const EnvironmentStyle = preload("res://world/environment_style.gd")
const IDS := ["lacuna-court", "vermilion-fold", "nacre-engine"]
const CELL := 12.0

# Surface roles for the six shared identity materials. The recipe's four-entry
# palette stays the colour authority: `palette` / `mix` / `tint` are read here
# exactly like the pre-pass style table, but the surface (base + baked bump +
# finish) comes from the material language, keyed by published family names.
# Six keys, one shared material each, no per-surface instance.
const IDENTITY_ROLES := {
	"lacuna-court": {
		"floor": {"role": "floor", "palette": 0, "mix": "fff3dd", "mix_amount": 0.35, "options": {"tiles_per_metre": 0.55, "texture_strength": 0.52, "albedo_gain": 2.25}},
		"shell": {"role": "wall", "palette": 1, "mix": "fff8ea", "mix_amount": 0.34, "options": {"tiles_per_metre": 0.55, "texture_strength": 0.38, "albedo_gain": 2.4}},
		"cut": {"role": "wall-worn", "palette": 1, "mix": "cfc3a8", "mix_amount": 0.30, "options": {"tiles_per_metre": 0.6, "texture_strength": 0.38, "albedo_gain": 2.4}},
		"enamel": {"role": "wall-panel", "palette": 2, "options": {"tiles_per_metre": 0.45, "roughness": 0.34, "metallic": 0.18, "lut_gain": 0.14}},
		"accent": {"role": "pipe", "palette": 3, "options": {"tiles_per_metre": 0.55, "roughness": 0.38, "metallic": 0.55}},
		"trim": {"role": "rail", "tint": "5a5346", "palette_mix": 3, "palette_mix_amount": 0.25, "options": {"tiles_per_metre": 0.7, "metallic": 0.55, "lut_gain": 0.0}},
	},
	"vermilion-fold": {
		"floor": {"role": "floor", "palette": 0, "mix": "b3a68a", "mix_amount": 0.4, "options": {"tiles_per_metre": 0.55, "texture_strength": 0.52, "albedo_gain": 2.25}},
		"shell": {"role": "wall-stucco", "palette": 0, "options": {"tiles_per_metre": 0.55, "texture_strength": 0.40, "albedo_gain": 2.2}},
		"cut": {"role": "wall-worn", "palette": 1, "options": {"tiles_per_metre": 0.6, "texture_strength": 0.38, "albedo_gain": 2.4}},
		"enamel": {"role": "wall-panel", "palette": 2, "options": {"tiles_per_metre": 0.45, "roughness": 0.30, "metallic": 0.12, "lut_gain": 0.14}},
		"accent": {"role": "wall-worn", "palette": 3, "mix": "ffd9cd", "mix_amount": 0.16, "options": {"tiles_per_metre": 0.42, "texture_strength": 0.38, "albedo_gain": 2.4}},
		"trim": {"role": "riveted", "tint": "343943", "options": {"tiles_per_metre": 0.8, "metallic": 0.60}},
	},
	"nacre-engine": {
		"floor": {"role": "floor-built", "palette": 0, "mix": "e8e2d4", "mix_amount": 0.45, "options": {"tiles_per_metre": 0.55, "texture_strength": 0.45, "albedo_gain": 2.5}},
		"shell": {"role": "wall-stucco", "palette": 0, "mix": "f4eee1", "mix_amount": 0.36, "options": {"tiles_per_metre": 0.55, "texture_strength": 0.42, "albedo_gain": 2.2, "roughness": 0.62, "lut_gain": 0.10}},
		"cut": {"role": "grating", "palette": 1, "options": {"tiles_per_metre": 0.6, "metallic": 0.30, "lut_gain": 0.0}},
		"enamel": {"role": "wall-panel", "palette": 2, "options": {"tiles_per_metre": 0.42, "roughness": 0.30, "metallic": 0.20, "lut_gain": 0.16}},
		"accent": {"role": "pipe", "palette": 3, "options": {"tiles_per_metre": 0.55, "roughness": 0.36, "metallic": 0.55}},
		"trim": {"role": "rail", "tint": "394a55", "options": {"tiles_per_metre": 0.8, "metallic": 0.62, "lut_gain": 0.0}},
	},
}
var identity_plan: Dictionary = {}
var recipe: Dictionary = {}
var materials: Dictionary = {}
var batches: Dictionary = {}
var metrics: Dictionary = {}
var built := false
var graybox := false
var fx: Node3D = null
var detail: Node3D = null

func get_arena_id() -> String:
	return str(recipe.get("id", ""))

func get_spawn_points() -> Array:
	return recipe.get("arena", {}).get("spawns", [])

func build(id: String = "lacuna-court", gray: bool = false) -> bool:
	if built: return get_arena_id() == id
	if id not in IDS: return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://identity_maps/generated/" + id + ".json"))
	if not parsed is Dictionary: return false
	recipe = parsed
	graybox = gray
	var started := Time.get_ticks_usec()
	_make_materials()
	var arena: Dictionary = recipe.arena
	for block: Dictionary in arena.blocks:
		var size := Vector3(block.w, block.h - block.baseY, block.d)
		var center := Vector3(block.x, (block.h + block.baseY) * 0.5, block.z)
		var mesh := BoxMesh.new()
		mesh.size = size
		_append_arrays(mesh.get_mesh_arrays(), center, str(block.material))
		var body := StaticBody3D.new()
		body.name = str(block.id)
		body.position = center
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
		add_child(body)
	_count_counters()
	for surface: Dictionary in arena.terrain.surfaces:
		_surface(surface, "floor", true)
	for wall: Dictionary in arena.terrain.walls:
		_wall(wall)
	for surface: Dictionary in recipe.art:
		if not graybox or str(surface.id).ends_with("-infill"):
			_surface(surface, str(surface.material), false)
	_flush()
	if not graybox:
		_build_detail()
		_build_fx()
	built = true
	metrics.build_ms = float(Time.get_ticks_usec() - started) / 1000.0
	metrics.geometry_hash = recipe.geometryHash
	metrics.graybox = graybox
	return true

func _count_counters() -> void:
	metrics.blocks = (recipe.arena.get("blocks", []) as Array).size()
	metrics.surfaces = (recipe.arena.terrain.surfaces as Array).size()
	metrics.walls = (recipe.arena.terrain.walls as Array).size()

func _make_materials() -> void:
	materials = Style.create(str(recipe.id), recipe.palette)
	identity_plan = _apply_identity_roles()
	if graybox:
		for key: String in materials.keys():
			var flat := StandardMaterial3D.new()
			flat.albedo_color = Color("a4a8ac")
			flat.roughness = 0.82
			flat.metallic = 0.45 if key == "accent" else 0.0
			flat.cull_mode = BaseMaterial3D.CULL_DISABLED
			materials[key] = flat
		identity_plan = {}
		return
	metrics.texture_bytes = texture_bytes_of(materials.values())

## One shared family material per key, tinted from the recipe palette with the
## same palette/mix rules the pre-pass style table used. A role whose family is
## not published keeps the pre-pass material for that key.
func _apply_identity_roles() -> Dictionary:
	var plan: Dictionary = {}
	var table: Dictionary = IDENTITY_ROLES.get(str(recipe.id), {})
	var palette: Array = recipe.get("palette", [])
	for key: String in materials.keys():
		if not table.has(key): continue
		var spec: Dictionary = table[key]
		var material: Material = EnvironmentStyle.role_material(str(spec.role), _identity_tint(spec, palette), spec.get("options", {}), str(recipe.id))
		if material == null: continue
		materials[key] = material
		plan[key] = EnvironmentStyle.ROLE_TABLE[spec.role].family
	return plan

static func _identity_tint(spec: Dictionary, palette: Array) -> Color:
	var tint := Color.WHITE
	if palette.size() >= 4:
		var index: int = int(spec.get("palette", -1))
		if index >= 0 and index < palette.size(): tint = Color(str(palette[index]))
		var mix_index: int = int(spec.get("palette_mix", -1))
		if mix_index >= 0 and mix_index < palette.size():
			tint = tint.lerp(Color(str(palette[mix_index])), float(spec.get("palette_mix_amount", 0.0)))
	if spec.has("tint"): tint = Color(str(spec.tint))
	if spec.has("mix"): tint = tint.lerp(Color(str(spec.mix)), float(spec.get("mix_amount", 0.0)))
	return tint

## Unique texture bytes actually bound by these materials, counted once per
## resource: the honest number the contract gate budgets, instead of the
## pre-pass table's estimate.
static func texture_bytes_of(bound: Array) -> int:
	var seen: Dictionary = {}
	for material: Material in bound:
		if not material is ShaderMaterial: continue
		var shader_material := material as ShaderMaterial
		if shader_material.shader == null: continue
		for uniform: Dictionary in shader_material.shader.get_shader_uniform_list():
			var value: Variant = shader_material.get_shader_parameter(StringName(str(uniform.get("name", ""))))
			if value is Texture2D:
				var texture := value as Texture2D
				seen[texture.get_instance_id()] = texture.get_width() * texture.get_height() * 4
	var total := 0
	for size: int in seen.values(): total += size
	return total

func _material_for(key: String) -> Material:
	if materials.has(key): return materials[key]
	# A wall or art entry naming an unknown key is a build error, not a silent
	# fallback to an unrelated map's material.
	push_error("identity map: unknown material key " + key)
	return materials.get("cut", materials.values()[0])

func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

func _triangle(a: Vector3, b: Vector3, c: Vector3, material: String) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.length_squared() < 0.5: return
	var center := (a + b + c) / 3.0
	var key := "%s:%d:%d" % [material, floori(center.x / CELL), floori(center.z / CELL)]
	if not batches.has(key):
		batches[key] = {"vertices": PackedVector3Array(), "normals": PackedVector3Array(), "material": material}
	for vertex: Vector3 in [a, b, c]:
		batches[key].vertices.append(vertex)
		batches[key].normals.append(normal)

func _append_arrays(arrays: Array, center: Vector3, material: String) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0, indices.size(), 3):
		_triangle(vertices[indices[i]] + center, vertices[indices[i + 1]] + center, vertices[indices[i + 2]] + center, material)

## One art/floor/wall surface: batched render triangles, plus an exact concave
## collider when the source answers rays with it too.
func _surface(s: Dictionary, material: String, collide: bool) -> void:
	var faces := PackedVector3Array()
	for triangle: Array in s.triangles:
		var a := _v(s.vertices[triangle[0]])
		var b := _v(s.vertices[triangle[1]])
		var c := _v(s.vertices[triangle[2]])
		_triangle(a, b, c, material)
		faces.append_array(PackedVector3Array([a, b, c]))
	if faces.is_empty(): return
	if not collide: return
	_collider(str(s.id), faces)

## Source-compatible wall: polygon walls are fanned exactly like
## game/terrain.mjs wallTriangles (v0, v[i+1], v[i+2]) and get the same static
## mesh, because the source answers rays with those very triangles. Two-point
## entries are movement-only barriers and deliberately own no Godot collider:
## the source returns no ray hit for them either.
func _wall(wall: Dictionary) -> void:
	if wall.has("a") or wall.has("b"):
		metrics.movement_fences = int(metrics.get("movement_fences", 0)) + 1
		return
	var vertices: Array = wall["vertices"]
	var faces := PackedVector3Array()
	for i in range(1, vertices.size() - 1):
		var a := _v(vertices[0])
		var b := _v(vertices[i])
		var c := _v(vertices[i + 1])
		_triangle(a, b, c, str(wall.material))
		faces.append_array(PackedVector3Array([a, b, c]))
	if faces.is_empty(): return
	_collider(str(wall.id), faces)

func _collider(id: String, faces: PackedVector3Array) -> void:
	var body := StaticBody3D.new()
	body.name = id if not id.is_empty() else "wall"
	var collider := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

func _flush() -> void:
	var triangles := 0
	for key: String in batches:
		var batch: Dictionary = batches[key]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = batch.vertices
		arrays[Mesh.ARRAY_NORMAL] = batch.normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, _material_for(batch.material))
		var instance := MeshInstance3D.new()
		instance.name = key.replace(":", "_")
		instance.mesh = mesh
		add_child(instance)
		triangles += batch.vertices.size() / 3
	metrics.triangles = triangles
	metrics.material_cells = batches.size()
	batches.clear()

func _build_detail() -> void:
	detail = Node3D.new()
	detail.name = "IdentityTrim"
	add_child(detail)
	var data := Style.detail_batches(str(recipe.id), recipe)
	for key: String in data.boxes:
		var list: Array = data.boxes[key]
		if list.is_empty(): continue
		var instances := MultiMeshInstance3D.new()
		instances.name = key.capitalize() + "Trim"
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		multimesh.mesh = mesh
		multimesh.instance_count = list.size()
		for i in list.size(): multimesh.set_instance_transform(i, list[i])
		instances.multimesh = multimesh
		instances.material_override = _material_for(key)
		instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		detail.add_child(instances)
	if not data.bolts.is_empty():
		var bolts := MultiMeshInstance3D.new()
		bolts.name = "BoltTrim"
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.5
		mesh.bottom_radius = 0.5
		mesh.height = 1.0
		mesh.radial_segments = 6
		multimesh.mesh = mesh
		multimesh.instance_count = data.bolts.size()
		for i in data.bolts.size(): multimesh.set_instance_transform(i, data.bolts[i])
		bolts.multimesh = multimesh
		bolts.material_override = _material_for("trim")
		bolts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		detail.add_child(bolts)
	metrics.detail_instances = data.count
	metrics.detail_batches = detail.get_child_count()
	metrics.texture_bytes = texture_bytes_of(materials.values())

func _build_fx() -> void:
	fx = SignatureFx.new()
	fx.name = "SignatureFx"
	fx.configure(recipe)
	add_child(fx)
	metrics.fx = fx.snapshot()

# Public seams used by tests and by a future session composition.
func set_fx_quality(level: String) -> bool:
	return fx != null and fx.set_quality(level)

func reset_fx() -> void:
	if fx != null: fx.reset()

func metrics_snapshot() -> Dictionary:
	var snapshot := metrics.duplicate(true)
	snapshot.nodes = get_child_count() + 1
	if fx != null: snapshot.fx = fx.snapshot()
	return snapshot
