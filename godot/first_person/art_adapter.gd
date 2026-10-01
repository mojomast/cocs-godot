extends RefCounted
## Reviewed Blender presentation layer. Source-exported nodes remain authoritative for
## sights, muzzle, grip contacts and handling pivots; only their renderers are hidden.
const FIRST := "res://first_person/art/weapon-%d.glb"
const WORLD := "res://first_person/art/world-%d.glb"
static var cache: Dictionary = {}
static var enabled := true # Capture fixture toggles this for matched source baseline.

static func install(model: Node3D, id: int, world: bool = false) -> bool:
	if not enabled: return false
	var path: String = (WORLD if world else FIRST) % id
	if not cache.has(path): cache[path] = load(path)
	var scene: PackedScene = cache[path]
	if scene == null: return false
	var art: Node3D = scene.instantiate()
	var targets: Dictionary = {}
	for key: String in ["body", "feed", "bolt", "barrel-assembly", "shock-emitter", "flak-barrel"]:
		targets[key] = model if world or key == "body" else model.find_child(key, true, false)
	# Explicit reviewed asset override: the canonical export stays loaded so its
	# assembly hierarchy and contact nodes remain the sole motion authority.
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D"):
		mesh.visible = false
	model.add_child(art)
	var assemblies: Array[Node] = art.get_children()
	var surfaces: Array[Node] = art.find_children("*", "MeshInstance3D", true, false)
	for child: Node in assemblies:
		var assembly := child as Node3D
		if assembly == null: continue
		var key := str(assembly.name)
		# The source world GLB has static body geometry and grip anchors, without
		# viewmodel-only moving groups. Its lower LOD stays rigid on GunMount.
		var target: Node3D = targets.get(key) as Node3D
		if target == null:
			push_error("Blender art missing source assembly %s on weapon %d" % [key,id])
			continue
		if target == assembly: continue
		# Blender coordinates are in weapon space. preserve global_transform also
		# when the imported source group carries a non-identity rest transform.
		assembly.reparent(target, true)
		assembly.owner = model
	for mesh: MeshInstance3D in surfaces:
		mesh.owner = model
		mesh.set_meta("blender_art", true)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if not world else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for surface: int in mesh.mesh.get_surface_count():
			var mat: Material = mesh.mesh.surface_get_material(surface)
			if mat != null: mesh.set_surface_override_material(surface, mat.duplicate())
	return true
