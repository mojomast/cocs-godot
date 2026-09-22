extends RefCounted
## Shared per-map identity materials and render-only trim detail.
##
## One material per semantic key per map (six), reused by every block, floor,
## wall and art surface in that map: no per-surface shader instances, no
## runtime-generated textures beyond the Moth registry's own 48-64 px tiles.
## Colors come from the recipe's four authored palette entries, so the JSON
## stays the colour authority and this file only decides which baked tile and
## finish reads as chalk / indigo / copper / vermilion / jade / pearl / amber.
##
## Compatibility renderer first: StandardMaterial3D via the Moth world-space
## triplanar surface shader only. No SSAO/SSR/decals/VoxelGI, no screen-space
## effects, no per-map shader variants. Glow is an environment decision made by
## the caller, never required by these materials.
const MothSurfaces = preload("res://moth/surfaces.gd")
const Moth = preload("res://moth/library.gd")
# Shared, already-gated sky shader from the atmosphere lane: a static gradient
# plus the baked Moth panorama. Reused read-only rather than duplicated, so the
# three identity maps read as the same world as the rest of the project.
const SKY_SHADER = preload("res://graphics_atmosphere/horizon.gdshader")

const KEYS := ["floor", "shell", "cut", "enamel", "accent", "trim"]

# tile: Moth texture name. tint: palette index and/or fixed hex. repeat is the
# honest texel-density knob: a 64 px tile at repeat 0.35 covers ~2.9 m.
const SPECS := {
	"lacuna-court": {
		# Sunlit chalk and pale cut stone, deep indigo recesses, copper inlays.
		"floor": {"tile": "sand", "palette": 0, "mix": "fff3dd", "mix_amount": 0.35, "repeat": 0.55, "roughness": 0.94, "normal": 0.30, "texture_strength": 0.7, "texture_saturation": 0.45},
		"shell": {"tile": "rough_stucco", "palette": 1, "mix": "fff8ea", "mix_amount": 0.34, "repeat": 0.55, "roughness": 0.86, "normal": 0.34, "texture_strength": 0.68, "texture_saturation": 0.4},
		"cut": {"tile": "weathered_concrete-worn", "palette": 1, "mix": "cfc3a8", "mix_amount": 0.30, "repeat": 0.6, "roughness": 0.86, "normal": 0.4, "texture_strength": 0.72, "texture_saturation": 0.35},
		"enamel": {"tile": "hex_paneling-mottle", "palette": 2, "repeat": 0.45, "roughness": 0.34, "metallic": 0.18, "normal": 0.30, "lut": "entanglement-void", "lut_intensity": 0.10},
		"accent": {"tile": "metal-oxide", "palette": 3, "repeat": 0.55, "roughness": 0.38, "metallic": 0.72, "normal": 0.26},
		"trim": {"tile": "brushed_metal", "tint": "5a5346", "palette_mix": 3, "palette_mix_amount": 0.25, "repeat": 0.70, "roughness": 0.42, "metallic": 0.55},
	},
	"vermilion-fold": {
		# Vermilion folded ribbons, ivory tension members, jade enamel.
		"floor": {"tile": "sand", "palette": 0, "mix": "b3a68a", "mix_amount": 0.4, "repeat": 0.55, "roughness": 0.92, "normal": 0.3, "texture_strength": 0.7, "texture_saturation": 0.45},
		"shell": {"tile": "rough_stucco", "palette": 0, "repeat": 0.55, "roughness": 0.80, "normal": 0.36, "texture_strength": 0.68, "texture_saturation": 0.4},
		"cut": {"tile": "weathered_concrete", "palette": 1, "repeat": 0.6, "roughness": 0.86, "normal": 0.36, "texture_strength": 0.7, "texture_saturation": 0.35},
		"enamel": {"tile": "hex_paneling", "palette": 2, "repeat": 0.45, "roughness": 0.30, "metallic": 0.12, "normal": 0.28, "lut": "entanglement-ceramic", "lut_intensity": 0.10},
		"accent": {"tile": "weathered_concrete-worn", "palette": 3, "mix": "ffd9cd", "mix_amount": 0.16, "repeat": 0.42, "roughness": 0.62, "normal": 0.34},
		"trim": {"tile": "riveted_armor", "tint": "343943", "repeat": 0.80, "roughness": 0.38, "metallic": 0.60, "normal": 0.32},
	},
	"nacre-engine": {
		# Pearl shell vaults, ultramarine recesses, amber service organs.
		"floor": {"tile": "weathered_concrete", "palette": 0, "mix": "e8e2d4", "mix_amount": 0.45, "repeat": 0.55, "roughness": 0.78, "normal": 0.32, "texture_strength": 0.7, "texture_saturation": 0.35},
		"shell": {"tile": "rough_stucco-weathered", "palette": 0, "mix": "f4eee1", "mix_amount": 0.36, "repeat": 0.55, "roughness": 0.62, "normal": 0.34, "texture_strength": 0.64, "texture_saturation": 0.3, "lut": "entanglement-arcane", "lut_intensity": 0.10},
		"cut": {"tile": "metal_grating", "palette": 1, "repeat": 0.60, "roughness": 0.55, "metallic": 0.30, "normal": 0.34},
		"enamel": {"tile": "hex_paneling-mottle", "palette": 2, "repeat": 0.42, "roughness": 0.30, "metallic": 0.20, "normal": 0.30, "lut": "entanglement-void", "lut_intensity": 0.14},
		"accent": {"tile": "metal-oxide", "palette": 3, "repeat": 0.55, "roughness": 0.36, "metallic": 0.70, "normal": 0.28},
		"trim": {"tile": "brushed_metal", "tint": "394a55", "repeat": 0.80, "roughness": 0.40, "metallic": 0.62},
	},
}

static func _finite(value: Variant, fallback: float) -> float:
	return float(value) if (value is float or value is int) and is_finite(float(value)) else fallback

static func _color(hex: String) -> Color:
	return Color(hex) if Color.html_is_valid(hex) else Color.WHITE

## One shared material per key; `palette` is the recipe's four authored colours.
static func create(map_id: String, palette: Array) -> Dictionary:
	var out: Dictionary = {}
	if not SPECS.has(map_id):
		push_error("identity style: unknown map " + map_id)
		return out
	for key: String in KEYS:
		var spec: Dictionary = SPECS[map_id][key]
		var tint := Color.WHITE
		if palette.size() >= 4:
			var index: int = int(spec.get("palette", -1))
			if index >= 0 and index < palette.size():
				tint = Color(str(palette[index]))
			var mix_index: int = int(spec.get("palette_mix", -1))
			if mix_index >= 0 and mix_index < palette.size():
				tint = tint.lerp(Color(str(palette[mix_index])), _finite(spec.get("palette_mix_amount", 0.0), 0.0))
		if spec.has("tint"):
			tint = _color(str(spec["tint"]))
		if spec.has("mix"):
			tint = tint.lerp(_color(str(spec["mix"])), _finite(spec.get("mix_amount", 0.0), 0.0))
		var material := MothSurfaces.create_surface(str(spec["tile"]), tint)
		material.set_shader_parameter("repeat_scale", _finite(spec.get("repeat", 0.35), 0.35))
		material.set_shader_parameter("texture_strength", _finite(spec.get("texture_strength", 0.55), 0.55))
		material.set_shader_parameter("texture_saturation", _finite(spec.get("texture_saturation", 0.30), 0.30))
		material.set_shader_parameter("roughness", _finite(spec.get("roughness", 0.82), 0.82))
		material.set_shader_parameter("metallic", _finite(spec.get("metallic", 0.0), 0.0))
		material.set_shader_parameter("normal_strength", _finite(spec.get("normal", 0.24), 0.24))
		if spec.has("lut"):
			MothSurfaces.apply_lut(material, str(spec["lut"]), _finite(spec.get("lut_intensity", 0.0), 0.0), _finite(spec.get("lut_phase", 0.35), 0.35))
		out[key] = material
	return out

## Bytes of unique Moth tiles referenced by this map's materials, counted once
## per resource. This is the honest per-map texture allocation, not a GPU stat.
static func texture_bytes(map_id: String) -> int:
	if not SPECS.has(map_id):
		return 0
	var seen: Dictionary = {}
	var total := 0
	var manifest: Dictionary = Moth.manifest()
	for key: String in KEYS:
		var tile := str(SPECS[map_id][key]["tile"])
		if seen.has(tile):
			continue
		seen[tile] = true
		var albedo: Dictionary = manifest.get("textures", {}).get(tile, {})
		if not albedo.is_empty():
			total += int(albedo.get("width", 0)) * int(albedo.get("height", 0)) * 4
		var normal: Dictionary = manifest.get("normals", {}).get(tile, {})
		if not normal.is_empty():
			total += int(normal.get("width", 0)) * int(normal.get("height", 0)) * 4
	return total

## Render-only trim. MultiMesh batches (one draw call per key), shadows off, no
## collider, every piece at most 5 cm proud of the block it decorates, so
## silhouette and collision are untouched by construction.
static func detail_batches(map_id: String, recipe: Dictionary) -> Dictionary:
	var boxes: Dictionary = {}
	var bolts: Array[Transform3D] = []
	var blocks: Array = recipe.arena.get("blocks", [])
	var bounds: Dictionary = recipe.arena.bounds
	for block: Dictionary in blocks:
		var id := str(block.get("id", ""))
		_add(boxes, "trim", Transform3D(Basis().scaled(Vector3(block.w + 0.05, 0.18, block.d + 0.05)), Vector3(block.x, block.h - 0.09, block.z)))
		_add(boxes, "trim", Transform3D(Basis().scaled(Vector3(block.w + 0.06, 0.34, block.d + 0.06)), Vector3(block.x, 0.34, block.z)))
		if map_id == "vermilion-fold" and id.begins_with("pavilion-retainer"):
			var count := maxi(2, int(block.w / 2.4))
			for i in count:
				var offset := (i - (count - 1) * 0.5) * 2.4
				bolts.append(Transform3D(Basis().scaled(Vector3.ONE * 0.26), Vector3(block.x + offset, block.h + 0.10, block.z)))
		if map_id == "nacre-engine" and id == "memory-housing":
			for face in 4:
				var horizontal := face % 2 == 0
				var sign := 1.0 if face < 2 else -1.0
				for level in 3:
					var centre: Vector3 = Vector3(block.x, 1.4 + level * 1.6, block.z)
					centre += Vector3(0, 0, sign * (block.d * 0.5 + 0.03)) if horizontal else Vector3(sign * (block.w * 0.5 + 0.03), 0, 0)
					var size := Vector3(block.w * 0.62, 0.14, 0.06) if horizontal else Vector3(0.06, 0.14, block.d * 0.62)
					_add(boxes, "accent", Transform3D(Basis().scaled(size), centre))
		if map_id == "lacuna-court" and id.begins_with("resonator-"):
			for side in 2:
				var sx := -1.0 if side == 0 else 1.0
				_add(boxes, "accent", Transform3D(Basis().scaled(Vector3(block.w * 0.86, 0.06, 0.34)), Vector3(block.x + sx * block.w * 0.34, block.h + 0.03, block.z - 1.0)))
				_add(boxes, "accent", Transform3D(Basis().scaled(Vector3(block.w * 0.86, 0.06, 0.34)), Vector3(block.x + sx * block.w * 0.34, block.h + 0.03, block.z + 1.0)))
	# Perimeter parapet ledge: reads the movement bound without owning it.
	_add(boxes, "trim", Transform3D(Basis().scaled(Vector3(bounds.maxX - bounds.minX + 0.4, 0.22, 0.3)), Vector3((bounds.minX + bounds.maxX) * 0.5, 7.06, bounds.minZ - 1)))
	_add(boxes, "trim", Transform3D(Basis().scaled(Vector3(bounds.maxX - bounds.minX + 0.4, 0.22, 0.3)), Vector3((bounds.minX + bounds.maxX) * 0.5, 7.06, bounds.maxZ + 1)))
	_add(boxes, "trim", Transform3D(Basis().scaled(Vector3(0.3, 0.22, bounds.maxZ - bounds.minZ + 0.4)), Vector3(bounds.minX - 1, 7.06, (bounds.minZ + bounds.maxZ) * 0.5)))
	_add(boxes, "trim", Transform3D(Basis().scaled(Vector3(0.3, 0.22, bounds.maxZ - bounds.minZ + 0.4)), Vector3(bounds.maxX + 1, 7.06, (bounds.minZ + bounds.maxZ) * 0.5)))
	var count := bolts.size()
	for key: String in boxes:
		count += (boxes[key] as Array).size()
	return {"boxes": boxes, "bolts": bolts, "count": count, "keys": boxes.keys().size() + (1 if bolts.size() > 0 else 0)}


# --- environment and distant scenery ---------------------------------------
# Per-map sky/light/fog so the three identities read as different places with
# zero extra lights (one shadowed key, ambient fill, linear fog: Compatibility
# safe, no SSAO/SSR/volumetric). The baked Moth 128x64 sky panorama is the only
# sky resource; scenery is render-only MultiMesh outside the movement bounds.
const ENVIRONMENTS := {
	"lacuna-court": {
		"sky": "frost", "sky_energy": 1.0, "zenith": "5d7fae", "horizon": "e8dcc2", "ground": "8a8271", "panorama_strength": 0.62, "panorama_rotation": 0.22, "disk_strength": 0.7,
		"ambient": "cfd6dd", "ambient_energy": 0.52, "fog": "d8d3c4", "fog_density": 0.00085,
		"sun_color": "fff1d8", "sun_energy": 1.45, "pitch": -46.0, "yaw": -34.0,
		"scenery": "cut", "scenery_dark": 0.30, "backdrop": "9a917c", "silhouette": "6c6555", "backdrop_darken": 0.42,
	},
	"vermilion-fold": {
		"sky": "ashen", "sky_energy": 0.9, "zenith": "6d7590", "horizon": "ecd0a8", "ground": "87674f", "panorama_strength": 0.66, "panorama_rotation": 0.48, "disk_strength": 0.55,
		"ambient": "d8cfc0", "ambient_energy": 0.50, "fog": "ddc9ab", "fog_density": 0.00070,
		"sun_color": "ffdfae", "sun_energy": 1.40, "pitch": -40.0, "yaw": -24.0,
		"scenery": "cut", "scenery_dark": 0.34, "backdrop": "a08a71", "silhouette": "6f6152", "backdrop_darken": 0.46,
	},
	"nacre-engine": {
		"sky": "void", "sky_energy": 1.1, "zenith": "101c31", "horizon": "58708a", "ground": "222d3a", "panorama_strength": 0.78, "panorama_rotation": 0.08, "disk_strength": 0.0,
		"ambient": "9fb4c6", "ambient_energy": 0.46, "fog": "2c3a4d", "fog_density": 0.00075,
		"sun_color": "dfe9f5", "sun_energy": 1.15, "pitch": -52.0, "yaw": -30.0,
		"scenery": "cut", "scenery_dark": 0.42, "backdrop": "1d2733", "silhouette": "27313d", "backdrop_darken": 0.5,
	},
}

static func configure_environment(map_id: String, world: WorldEnvironment, sun: DirectionalLight3D) -> void:
	var spec: Dictionary = ENVIRONMENTS.get(map_id, ENVIRONMENTS["lacuna-court"])
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	for pair: Array in [["zenith", "zenith"], ["horizon", "horizon"], ["ground", "ground"], ["sun_color", "sun_color"]]:
		sky_material.set_shader_parameter(pair[0], _color(str(spec[pair[1]])))
	var panorama := Moth.sky(str(spec.sky))
	if panorama == null:
		push_error("identity style: missing Moth sky " + str(spec.sky))
	sky_material.set_shader_parameter("panorama", panorama)
	sky_material.set_shader_parameter("has_panorama", panorama != null and _finite(spec.get("panorama_strength", 0.0), 0.0) > 0.0)
	sky_material.set_shader_parameter("panorama_strength", _finite(spec.get("panorama_strength", 0.55), 0.55))
	sky_material.set_shader_parameter("panorama_rotation", _finite(spec.get("panorama_rotation", 0.15), 0.15))
	sky_material.set_shader_parameter("veil_strength", _finite(spec.get("veil_strength", 0.0), 0.0))
	sky_material.set_shader_parameter("disk_strength", _finite(spec.get("disk_strength", 0.6), 0.6))
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.background_energy_multiplier = _finite(spec.get("sky_energy", 1.0), 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_sky_contribution = 0.0
	env.ambient_light_color = _color(str(spec.ambient))
	env.ambient_light_energy = _finite(spec.get("ambient_energy", 0.5), 0.5)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = _color(str(spec.fog))
	env.fog_light_energy = 1.0
	env.fog_density = _finite(spec.get("fog_density", 0.0008), 0.0008)
	env.fog_sun_scatter = 0.0
	env.fog_sky_affect = 0.0
	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.ssr_enabled = false
	env.volumetric_fog_enabled = false
	world.environment = env
	sun.rotation_degrees = Vector3(_finite(spec.get("pitch", -46.0), -46.0), _finite(spec.get("yaw", -34.0), -34.0), 0.0)
	sun.light_color = _color(str(spec.sun_color))
	sun.light_energy = _finite(spec.get("sun_energy", 1.3), 1.3)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.0
	sky_material.set_shader_parameter("sun_direction", sun.basis.z.normalized())

## Render-only horizon: a ground plane far below the playfield plus a bounded
## silhouette ring outside the movement bounds. No collision, no walkable
## surface, nothing inside bounds, so it can never become cover or support.
static func decorate(map_id: String, recipe: Dictionary, parent: Node3D, materials: Dictionary) -> Dictionary:
	var spec: Dictionary = ENVIRONMENTS.get(map_id, ENVIRONMENTS["lacuna-court"])
	var root := Node3D.new()
	root.name = "IdentityHorizon"
	parent.add_child(root)
	var backdrop := MeshInstance3D.new()
	backdrop.name = "DistantGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1600, 1600)
	backdrop.mesh = plane
	backdrop.position.y = -4.0
	var backdrop_material := StandardMaterial3D.new()
	backdrop_material.albedo_color = _color(str(spec.backdrop)).darkened(_finite(spec.get("backdrop_darken", 0.5), 0.5))
	backdrop_material.roughness = 1.0
	backdrop.material_override = backdrop_material
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(backdrop)
	var bounds: Dictionary = recipe.arena.bounds
	var mid_x := (float(bounds.minX) + float(bounds.maxX)) * 0.5
	var mid_z := (float(bounds.minZ) + float(bounds.maxZ)) * 0.5
	var radius := 0.5 * maxf(float(bounds.maxX) - float(bounds.minX), float(bounds.maxZ) - float(bounds.minZ)) + 66.0
	var transforms: Array[Transform3D] = []
	for i in 28:
		var angle := TAU * i / 28.0 + sin(float(i) * 9.0) * 0.035
		var height := 14.0 + fmod(float(i) * 17.0, 26.0)
		var distance := radius + sin(float(i) * 13.0) * 20.0
		var size := Vector3(34.0 + fmod(float(i) * 7.0, 22.0), height, 30.0 + fmod(float(i) * 5.0, 18.0))
		transforms.append(Transform3D(Basis(Vector3.UP, angle).scaled_local(size), Vector3(mid_x + cos(angle) * distance, height * 0.5 - 4.0, mid_z + sin(angle) * distance)))
	var instances := MultiMeshInstance3D.new()
	instances.name = "SkylineSilhouette"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size(): multimesh.set_instance_transform(i, transforms[i])
	instances.multimesh = multimesh
	var silhouette := _color(str(spec.silhouette)).darkened(_finite(spec.get("scenery_dark", 0.45), 0.45))
	var silhouette_material := StandardMaterial3D.new()
	silhouette_material.albedo_color = silhouette
	silhouette_material.roughness = 1.0
	instances.material_override = silhouette_material
	instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instances)
	return {"nodes": root.get_child_count(), "silhouettes": transforms.size(), "collision": false}

static func _add(boxes: Dictionary, key: String, transform: Transform3D) -> void:
	var list: Array = boxes.get(key, [])
	list.append(transform)
	boxes[key] = list
