extends Node3D
## Reusable, bounded native GPU particle field. No CPU particle iteration.
## configure(count, preset, backend) is transactional; invalid values do not mutate.
const Library = preload("res://moth/library.gd")
const DrawShader = preload("res://particle_lab/particles.gdshader")
const SimulationShader = preload("res://particle_lab/simulation.gdshader")
const PRESETS := ["vortex", "galaxy", "burst", "fountain"]
const COUNTS := [8192, 32768, 131072, 524288, 1048576]
const HARD_LIMIT := 1048576
const BOUNDS := AABB(Vector3(-52, -32, -52), Vector3(104, 80, 104))

## Lower this before configure() for in-map effects. No maximum preallocation.
var budget := HARD_LIMIT
var clock := 0.0
var paused := false
var count := 0
var preset := "vortex"
var backend := "gpu"
var disposed := false
var particle_size := 0.34
var intensity := 0.85
var gpu: GPUParticles3D
var analytic: MultiMeshInstance3D
var multimesh: MultiMesh
var mesh: QuadMesh
var draw_material: ShaderMaterial
var simulation_material: ShaderMaterial
var _frames: Array[Texture2D] = []
var _frame_index := -1
var _effect_fps := 8.0
var _configured := false
var _resources_ready := false

func _init() -> void:
	set_process(false)

func configure(requested_count: Variant, requested_preset: Variant = "vortex", requested_backend: Variant = "gpu") -> Dictionary:
	if disposed:
		return {"ok": false, "error": "Field has been disposed"}
	if typeof(requested_count) != TYPE_INT or requested_count < 1 or requested_count > mini(budget, HARD_LIMIT):
		return {"ok": false, "error": "Count must be an integer in 1..%d" % mini(budget, HARD_LIMIT)}
	if typeof(requested_preset) != TYPE_STRING or not requested_preset in PRESETS:
		return {"ok": false, "error": "Unknown preset"}
	if typeof(requested_backend) != TYPE_STRING or not requested_backend in ["gpu", "analytic"]:
		return {"ok": false, "error": "Unknown backend"}
	if not _configured:
		_build()
	count = requested_count
	preset = requested_preset
	backend = requested_backend
	var index := PRESETS.find(preset)
	draw_material.set_shader_parameter("field_preset", index)
	simulation_material.set_shader_parameter("field_preset", index)
	draw_material.set_shader_parameter("analytic_backend", backend == "analytic")
	# Reuse all node/material/mesh identities; only the requested backend owns
	# a large buffer. Reducing count really releases capacity; no hidden 1M pool.
	gpu.visible = backend == "gpu"
	gpu.emitting = backend == "gpu"
	analytic.visible = backend == "analytic"
	if backend == "gpu":
		multimesh.instance_count = 0
		gpu.amount = count
	else:
		gpu.amount = 1
		multimesh.instance_count = count
		multimesh.visible_instance_count = count
	set_process(true)
	reset()
	return {"ok": true, "count": count, "preset": preset, "backend": backend}

func _build() -> void:
	mesh = QuadMesh.new()
	mesh.size = Vector2.ONE
	draw_material = ShaderMaterial.new()
	draw_material.shader = DrawShader
	simulation_material = ShaderMaterial.new()
	simulation_material.shader = SimulationShader
	mesh.material = draw_material
	var flow := Library.texture("flow-field")
	var lut: Dictionary = Library.material_lut("entanglement")
	var effect: Dictionary = Library.effect("arc-burst")
	_frames.assign(effect.get("frames", []))
	_effect_fps = float(effect.get("fps", 8.0))
	_resources_ready = flow != null and lut.get("r") is Texture2D and lut.get("t") is Texture2D and not _frames.is_empty()
	for material in [draw_material, simulation_material]:
		material.set_shader_parameter("flow_field", flow)
		material.set_shader_parameter("material_lut", lut.get("r"))
	gpu = GPUParticles3D.new()
	gpu.name = "GPUTransformFeedback"
	gpu.emitting = false
	gpu.amount = 1
	gpu.amount_ratio = 1.0
	gpu.lifetime = 600.0
	gpu.explosiveness = 1.0
	gpu.preprocess = 0.0
	gpu.fixed_fps = 0 # exactly one simulation step per render, no catch-up spiral
	gpu.interpolate = false
	gpu.fract_delta = false
	gpu.local_coords = true
	gpu.use_fixed_seed = true
	gpu.seed = 1984
	gpu.draw_order = GPUParticles3D.DRAW_ORDER_INDEX # no CPU depth sort/readback
	gpu.visibility_aabb = BOUNDS
	gpu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gpu.process_material = simulation_material
	gpu.draw_passes = 1
	gpu.draw_pass_1 = mesh
	add_child(gpu)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = false
	multimesh.use_custom_data = false
	multimesh.mesh = mesh
	multimesh.custom_aabb = BOUNDS
	analytic = MultiMeshInstance3D.new()
	analytic.name = "GPUAnalyticMultiMesh"
	analytic.multimesh = multimesh
	analytic.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(analytic)
	_configured = true
	set_appearance(particle_size, intensity)

func set_appearance(size_value: float, intensity_value: float) -> void:
	if not is_finite(size_value) or not is_finite(intensity_value):
		return
	particle_size = clampf(size_value, 0.04, 0.8)
	intensity = clampf(intensity_value, 0.05, 2.0)
	if draw_material:
		draw_material.set_shader_parameter("particle_size", particle_size)
		draw_material.set_shader_parameter("intensity", intensity)

func set_paused(value: bool) -> void:
	paused = value
	if gpu:
		gpu.speed_scale = 0.0 if paused else 1.0

func reset() -> void:
	clock = 0.0
	_frame_index = -1
	if not _configured or disposed:
		return
	_update_uniforms()
	# restart() also turns emitting on, including for hidden emitters.
	if backend == "gpu":
		gpu.restart(true)
	else:
		gpu.emitting = false
	set_paused(paused)

func _process(delta: float) -> void:
	if not paused:
		clock += delta
	_update_uniforms()

func _update_uniforms() -> void:
	draw_material.set_shader_parameter("field_clock", clock)
	simulation_material.set_shader_parameter("field_clock", clock)
	# Node transform is a single uniform, also making analytic fields reusable.
	draw_material.set_shader_parameter("field_transform", global_transform if is_inside_tree() else transform)
	if not _frames.is_empty():
		var next := int(clock * _effect_fps) % _frames.size()
		if next != _frame_index:
			_frame_index = next
			draw_material.set_shader_parameter("effect_frame", _frames[next])

func snapshot() -> Dictionary:
	var active_gpu := _configured and not disposed and backend == "gpu"
	var active_analytic := _configured and not disposed and backend == "analytic"
	return {
		"backend": backend,
		"backend_label": backend_label(),
		"preset": preset, "requested_count": count,
		"emitter_amount": gpu.amount if active_gpu else 0,
		"amount_ratio": gpu.amount_ratio if active_gpu else 0.0,
		"instance_count": multimesh.instance_count if active_analytic else 0,
		"visible_instance_count": multimesh.visible_instance_count if active_analytic else 0,
		"draw_slots": count if _configured and not disposed else 0,
		"particle_draw_passes": 1 if _configured and not disposed else 0,
		"capacity": count if _configured and not disposed else 0,
		"budget": mini(budget, HARD_LIMIT),
		"clock_seconds": clock, "paused": paused, "disposed": disposed,
		"particle_size": particle_size, "intensity": intensity,
		# 4.5.2 GLES3: two 96-byte process + two 64-byte instance buffers.
		# Analytic: 12 float32 transform slots; driver/CPU copies not included.
		"buffer_payload_estimate_bytes": count * (320 if active_gpu else 48) if not disposed else 0,
		"moth_cached_textures": Library.cache_stats().textures,
		"effect_frames": _frames.size(),
		"moth_resources_ready": _resources_ready,
	}

func backend_label() -> String:
	if backend == "analytic":
		return "MultiMesh / GPU analytic vertex motion"
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		return "GPUParticles3D / GPU transform feedback"
	return "GPUParticles3D / GPU simulation (RD)"

func resource_ids() -> Dictionary:
	if not _configured or disposed:
		return {}
	return {"gpu": gpu.get_instance_id(), "analytic": analytic.get_instance_id(),
		"mesh": mesh.get_instance_id(), "multimesh": multimesh.get_instance_id(),
		"draw_material": draw_material.get_instance_id(), "simulation_material": simulation_material.get_instance_id()}

func dispose() -> void:
	if disposed:
		return
	disposed = true
	set_process(false)
	if _configured:
		gpu.emitting = false
		gpu.draw_pass_1 = null
		gpu.process_material = null
		gpu.free()
		analytic.multimesh = null
		analytic.free()
		multimesh.instance_count = 0
		multimesh.mesh = null
		mesh.material = null
	gpu = null
	analytic = null
	multimesh = null
	mesh = null
	draw_material = null
	simulation_material = null
	_frames.clear()
	count = 0
	_configured = false
	_resources_ready = false
