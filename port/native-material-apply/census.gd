extends SceneTree
## Material census: per-map unique materials/shaders/textures plus the Moth and
## derived caches, for the same six playable maps and the nine locked maps the
## capture harness renders. Headless; no pixels, no gameplay.
##
## The Moth cache is cleared before each map, so every row is that map's own
## allocation and not the running total of everything built before it.
##
##     godot --headless --path <stage> --script res://tests/material_apply/census.gd -- --output=<file>
const IdentityMap = preload("res://identity_maps/map.gd")
const Viewer = preload("res://world/viewer.gd")
const Moth = preload("res://moth/library.gd")
const MaterialLanguage = preload("res://material_language/library.gd")

var output := ""
var seen: Dictionary = {}
var materials: Dictionary = {}
var shaders: Dictionary = {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty():
		push_error("--output is required")
		quit(2)
		return
	call_deferred("run")

func _collect(material: Material) -> void:
	materials[material.get_instance_id()] = true
	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		if shader_material.shader != null:
			shaders[shader_material.shader.get_instance_id()] = shader_material.shader.resource_path
			for uniform: Dictionary in shader_material.shader.get_shader_uniform_list():
				var value: Variant = shader_material.get_shader_parameter(StringName(str(uniform.get("name", ""))))
				if value is Texture2D:
					var texture := value as Texture2D
					seen[texture.get_instance_id()] = {"w": texture.get_width(), "h": texture.get_height(), "sampler": str(uniform.get("name", ""))}

func census(node: Node) -> Dictionary:
	seen = {}
	materials = {}
	shaders = {}
	var pending: Array[Node] = [node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child: Node in current.get_children(): pending.append(child)
		if current is MeshInstance3D:
			var instance := current as MeshInstance3D
			if instance.material_override != null:
				_collect(instance.material_override)
			elif instance.mesh != null:
				for index in instance.mesh.get_surface_count():
					var surface_material := instance.mesh.surface_get_material(index)
					if surface_material != null: _collect(surface_material)
		elif current is MultiMeshInstance3D:
			var batch := current as MultiMeshInstance3D
			if batch.material_override != null: _collect(batch.material_override)
		elif current is Label3D:
			if current.material_override != null: _collect(current.material_override)
	var total_bytes := 0
	for entry: Dictionary in seen.values(): total_bytes += int(entry.w) * int(entry.h) * 4
	var shader_list: Array = shaders.values()
	shader_list.sort()
	return {"materials": materials.size(), "shaders": shader_list, "textures": seen.size(),
		"texture_bytes_rgba8": total_bytes, "moth": Moth.cache_stats(), "derived": Moth.derived_cache_stats()}

func run() -> void:
	var entries: Array = []
	for id: String in ["prism-foundry", "aurora-basin", "cinder-array"]:
		Moth.clear_cache()
		var builder: Node3D = (load("res://native_arenas/maps/%s.gd" % id) as GDScript).new()
		root.add_child(builder)
		await process_frame
		entries.append({"id": id, "kind": "arena", "census": census(builder)})
		builder.queue_free()
		await process_frame
	for id: String in IdentityMap.IDS:
		Moth.clear_cache()
		var map: Node3D = IdentityMap.new()
		root.add_child(map)
		if not map.build(id, false):
			push_error("identity build failed: " + id)
			quit(2)
			return
		entries.append({"id": id, "kind": "identity", "census": census(map), "geometry": map.metrics_snapshot()})
		map.queue_free()
		await process_frame
	for id: String in ["meridian-exchange", "ember-crucible", "ion-speedway", "aurora-stadium"]:
		Moth.clear_cache()
		var viewer := Viewer.new()
		root.add_child(viewer)
		await process_frame
		if not viewer.load_map(id):
			push_error("locked map failed: " + id)
			quit(2)
			return
		var result := census(viewer.world)
		result["surface_kinds"] = viewer.world.get_meta("surface_kinds", [])
		entries.append({"id": id, "kind": "locked", "census": result})
		viewer.queue_free()
		await process_frame
	var report := {"engine": Engine.get_version_info().string, "maps": entries,
		"cache": Moth.cache_stats(), "derived_cache": Moth.derived_cache_stats(),
		"library": MaterialLanguage.cache_stats(), "library_budget": MaterialLanguage.budget(),
		"coverage": MaterialLanguage.coverage().counts}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("MATERIAL_APPLY_CENSUS ", JSON.stringify({"maps": entries.size(), "output": output}))
	quit(0)
