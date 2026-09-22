extends SceneTree
## Material-apply lane capture harness (staged privately under res://tests/material_apply/).
##
## One SceneTree process per resolution and phase. Every view is a fixed camera
## written down here (or read from authored recipe data) so a before and an after
## run differ only in the material-application source, never in framing.
## Measured per view: cadence over 40 frames after 12 warm-up frames, draw calls,
## primitives, video memory, node/resource counts, Moth cache and the honest
## unique-texture census of every ShaderMaterial actually bound in the scene.
##
## Time is frozen (Engine.time_scale = 0) before warm-up so rotating rings,
## turbines, particles and shader clocks cannot move between two captures.
const IdentityMap = preload("res://identity_maps/map.gd")
const IdentityStyle = preload("res://identity_maps/style.gd")
const Viewer = preload("res://world/viewer.gd")
const Moth = preload("res://moth/library.gd")

const PLAYABLE := ["prism-foundry", "aurora-basin", "cinder-array", "lacuna-court", "vermilion-fold", "nacre-engine"]
const LOCKED := ["meridian-exchange", "verdant-reliquary", "ember-crucible", "tidal-citadel", "sunscar-convoy", "asterion-relay", "monsoon-foundry", "ion-speedway", "aurora-stadium"]

# Authored arena poses. Prism entries are the shipped photo viewpoints; Aurora is
# the shipped camera_views() table; Cinder adds two route anchors plus an orbit.
const ARENA_VIEWS := {
	"prism-foundry": [
		{"id": "atrium", "at": Vector3(11.5, 7.2, 12.5), "target": Vector3(-1, 4.9, -2)},
		{"id": "turbine", "at": Vector3(-21, 2.1, 7.0), "target": Vector3(-29, 2.7, -4)},
		{"id": "garden", "at": Vector3(1.8, 1.75, -20), "target": Vector3(-1, 1.3, -31)},
		{"id": "overview", "at": Vector3(47, 35, -49), "target": Vector3(-3, 2.4, -7)},
	],
	"aurora-basin": [
		{"id": "landing", "at": Vector3(-23, 1.705, 34), "target": Vector3(0, 7.3, -13)},
		{"id": "fracture", "at": Vector3(15, 1.64, 17), "target": Vector3(-4, 7.8, -12)},
		{"id": "observatory", "at": Vector3(-17, 1.705, 34), "target": Vector3(-33, 5.0, 12)},
		{"id": "overview", "at": Vector3(84, 72, 99), "target": Vector3(0, 4.0, -3)},
	],
	"cinder-array": [
		{"id": "deck", "at": Vector3(-25.5, 8.9, 31), "target": Vector3(6, 11.5, -2)},
		{"id": "gantry", "at": Vector3(20, 13.9, -8), "target": Vector3(-20, 11, 6)},
		{"id": "bore", "at": Vector3(7, 13.7, -27), "target": Vector3(-20, 15, -27)},
		{"id": "overview", "at": Vector3(64, 56, 62), "target": Vector3(-2, 9, -4)},
	],
}

# Locked nine-map presentation. "authored" is the viewer's own arrival pose;
# "street" is a fixed eye-level pose chosen once and reused by both phases.
const LOCKED_VIEWS := [
	{"id": "authored", "at": Vector3(65, 48, 70), "target": Vector3(0, 2, 0), "fov": 70.0, "ui": true},
	{"id": "street", "at": Vector3(0, 3.0, 34), "target": Vector3(0, 3.0, 0), "fov": 70.0, "ui": false},
]
const IDENTITY_VIEWS := ["entrance", "combat", "landmark", "worst"]

var output := ""
var width := 960
var height := 640
var phase := "after"
var glow := false
var quality := "High"
var only: Array = []
var stage: Node3D
var camera: Camera3D
var report: Dictionary = {"scope": "Fixed-camera material-apply evidence; static inspection, no actors or gameplay.", "maps": []}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			width = parts[0].to_int()
			height = parts[1].to_int()
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
		if arg.begins_with("--maps="): only = arg.trim_prefix("--maps=").split(",")
		if arg == "--glow": glow = true
		if arg.begins_with("--quality="): quality = arg.trim_prefix("--quality=")
	if output.is_empty():
		push_error("--output is required")
		quit(2)
		return
	root.size = Vector2i(width, height)
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")

func _wanted(id: String) -> bool:
	return only.is_empty() or id in only

func _arm() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.far = 700.0
	stage.add_child(camera)
	camera.current = true
	Engine.time_scale = 0.0

func _settle() -> void:
	Engine.time_scale = 0.0
	var scenery := stage.find_child("MothScenery", true, false)
	if scenery != null and scenery.has_method("set_clock_for_capture"):
		scenery.set_clock_for_capture(12.0)

## Unique-texture census of every material bound under `node`: the honest
## "did this pass add unbounded texture growth?" number.
func _texture_census(node: Node) -> Dictionary:
	var seen: Dictionary = {}
	var materials: Dictionary = {}
	var shaders: Dictionary = {}
	var pending: Array[Node] = [node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child: Node in current.get_children():
			pending.append(child)
		var material: Material = null
		if current is MeshInstance3D: material = current.material_override
		if current is MultiMeshInstance3D: material = current.material_override
		if current is GPUParticles3D: material = current.process_material
		if current is CPUParticles3D and current.mesh != null and current.mesh is PrimitiveMesh:
			material = (current.mesh as PrimitiveMesh).material
		if current is Label3D: material = current.material_override
		if material == null: continue
		materials[material.get_instance_id()] = true
		if material is ShaderMaterial:
			var shader_material := material as ShaderMaterial
			if shader_material.shader != null:
				shaders[shader_material.shader.get_instance_id()] = true
				for uniform: Dictionary in shader_material.shader.get_shader_uniform_list():
					var uniform_name := StringName(str(uniform.get("name", "")))
					var value: Variant = shader_material.get_shader_parameter(uniform_name)
					if value is Texture2D:
						var texture := value as Texture2D
						seen[texture.get_instance_id()] = {"width": texture.get_width(), "height": texture.get_height()}
	var total_bytes := 0
	for entry: Dictionary in seen.values():
		total_bytes += int(entry.width) * int(entry.height) * 4
	return {"unique_materials": materials.size(), "unique_shaders": shaders.size(), "unique_textures": seen.size(), "texture_bytes_rgba8": total_bytes}

func _sample(map_id: String, view: Dictionary) -> Dictionary:
	camera.fov = float(view.get("fov", 70.0))
	camera.position = view.at
	camera.look_at(view.target, Vector3.UP)
	Engine.time_scale = 0.0
	for i in 12: await process_frame
	var samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in 40:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		previous = now
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_width() != width or image.get_height() != height:
		push_error("dimension mismatch: " + str(image.get_size()))
		quit(4)
		return {}
	var suffix := "-glow" if glow else ""
	var filename := "%s-%s-%dx%d-%s%s.png" % [map_id, str(view.id), width, height, phase, suffix]
	if image.save_png(output.path_join(filename)) != OK:
		push_error("save failed: " + filename)
		quit(3)
		return {}
	samples.sort()
	var census := _texture_census(stage)
	return {
		"map": map_id, "view": str(view.id), "phase": phase, "glow": glow, "file": filename,
		"width": width, "height": height, "fov": camera.fov,
		"position": [camera.position.x, camera.position.y, camera.position.z],
		"target": [view.target.x, view.target.y, view.target.z],
		"frame_ms_mean": samples.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / float(samples.size()),
		"frame_ms_median": samples[samples.size() / 2],
		"frame_ms_p95": samples[int(float(samples.size()) * 0.95)],
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"video_memory_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"moth_cache": Moth.cache_stats(),
		"textures": census,
	}

func _write() -> void:
	var views := 0
	for entry: Dictionary in report.maps: views += (entry.cameras as Array).size()
	report["views_total"] = views
	var file := FileAccess.open(output.path_join("manifest-%s-%dx%d%s.json" % [phase, width, height, "-glow" if glow else ""]), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("MATERIAL_APPLY_CAPTURE ", JSON.stringify({"maps": report.maps.size(), "views": views, "phase": phase, "size": [width, height]}))

func _record(map_id: String, view: Dictionary, entry: Dictionary) -> void:
	if entry.is_empty(): return
	entry["map"] = map_id
	report["views"] = report.get("views", [])
	report.views.append(entry)
	_write()

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(width, height)
	await process_frame
	report["engine"] = Engine.get_version_info().string
	report["renderer"] = RenderingServer.get_current_rendering_method()
	report["adapter"] = RenderingServer.get_video_adapter_name()
	report["phase"] = phase
	report["resolution"] = [width, height]
	report["glow"] = glow
	for id: String in PLAYABLE:
		if not _wanted(id): continue
		_arm()
		var entry: Dictionary
		if id in ARENA_VIEWS:
			var builder: Node3D = (load("res://native_arenas/maps/%s.gd" % id) as GDScript).new()
			stage.add_child(builder)
			await process_frame
			_settle()
			entry = {"kind": "arena", "cameras": []}
			for view: Dictionary in ARENA_VIEWS[id]:
				var shot: Dictionary = await _sample(id, view)
				entry.cameras.append(shot)
			if builder.has_method("resource_report"): entry["resources"] = builder.resource_report()
		else:
			var map: Node3D = IdentityMap.new()
			stage.add_child(map)
			if not map.build(id, false):
				push_error("identity build failed: " + id)
				quit(2)
				return
			if map.fx != null: map.set_fx_quality(quality)
			var world := WorldEnvironment.new()
			stage.add_child(world)
			var light := DirectionalLight3D.new()
			stage.add_child(light)
			IdentityStyle.configure_environment(id, world, light)
			world.environment.glow_enabled = glow
			if glow: world.environment.glow_intensity = 0.5
			IdentityStyle.decorate(id, map.recipe, stage, map.materials)
			await process_frame
			_settle()
			entry = {"kind": "identity", "cameras": [], "geometry": map.metrics_snapshot()}
			for view: Dictionary in map.recipe.cameras:
				if str(view.id) in IDENTITY_VIEWS:
					var pose := {"id": str(view.id), "at": Vector3(view.at[0], view.at[1], view.at[2]), "target": Vector3(view.target[0], view.target[1], view.target[2])}
					var shot: Dictionary = await _sample(id, pose)
					entry.cameras.append(shot)
		report.maps.append(entry)
		_write()
		stage.queue_free()
		stage = null
		for i in 3: await process_frame
	for id: String in LOCKED:
		if not _wanted(id): continue
		_arm()
		var viewer := Viewer.new()
		stage.add_child(viewer)
		await process_frame
		if not viewer.load_map(id):
			push_error("locked map failed: " + id)
			quit(2)
			return
		for child: Node in viewer.get_children():
			if child is CanvasLayer: (child as CanvasLayer).hide()
		_settle()
		var entry := {"kind": "locked", "cameras": []}
		for view: Dictionary in LOCKED_VIEWS:
			var pose := {"id": view.id, "at": view.at, "target": view.target, "fov": view.fov}
			var shot: Dictionary = await _sample(id, pose)
			entry.cameras.append(shot)
		entry["surface_kinds"] = viewer.world.get_meta("surface_kinds", [])
		report.maps.append(entry)
		_write()
		stage.queue_free()
		stage = null
		for i in 3: await process_frame
	Engine.time_scale = 1.0
	_write()
	print("MATERIAL_APPLY_CAPTURE_DONE ", JSON.stringify({"phase": phase, "size": [width, height], "glow": glow, "views": report.get("views_total", 0), "maps": report.maps.size()}))
	quit(0)
