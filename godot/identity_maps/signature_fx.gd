extends Node3D
## One bounded signature environmental effect per identity map.
##
## Contract (shared with the delivered combat particle pattern):
##   * a fixed pool of GPUParticles3D emitters, built once in configure();
##   * explicit Low/High budgets (8192 / 32768) with a documented allocation;
##   * one shared draw shader + one draw material per map, one process material
##     per emitter, no per-frame allocation anywhere;
##   * distance gating (a throttled camera check stops emission far away) plus
##     GeometryInstance3D visibility ranges and a tight visibility AABB;
##   * emission stops on application focus loss and on tree pause;
##   * reset() clears live particles for a round boundary;
##   * zero gameplay authority: nothing here reads or writes Match state, and
##     nothing is keyed to objective, pickup, spawn or damage events. Effects
##     are placed inside opaque architecture, above eye level, or as sparse
##     ground haze, and never as a ground ring/beacon that could be read as a
##     capture marker, pickup, projectile or door.
const Draw = preload("res://identity_maps/signature_particle.gdshader")
const QUALITY := {"Low": 8192, "High": 32768}
const GATE_INTERVAL := 0.25
const GATE_DISTANCE := 26.0
var emitters: Array[Dictionary] = []
var quality := "High"
var budget := 32768
var allocated := 0
var map_id := ""
var paused := false
var focused := true
var _suspended := true
var _draw: ShaderMaterial
var _clock := 0.0
var _gate_clock := 0.0
var _camera: Camera3D = null

func configure(recipe: Dictionary, view_camera: Camera3D = null) -> void:
	map_id = str(recipe.get("id", ""))
	_camera = view_camera
	_draw = ShaderMaterial.new()
	_draw.shader = Draw
	_draw.set_shader_parameter("tint", _tint(recipe))
	_draw.set_shader_parameter("opacity", 0.34)
	_draw.set_shader_parameter("softness", 0.72)
	for spec: Dictionary in _specs(recipe):
		_add_emitter(spec)
	set_quality(quality)
	_sync()
	set_process(true)

func _tint(recipe: Dictionary) -> Color:
	var palette: Array = recipe.get("palette", [])
	if palette.size() >= 4:
		if map_id == "lacuna-court": return Color(str(palette[0])).lerp(Color(str(palette[3])), 0.25)
		if map_id == "vermilion-fold": return Color(str(palette[3])).lerp(Color(str(palette[0])), 0.45)
		return Color(str(palette[0])).lerp(Color(str(palette[2])), 0.18)
	return Color("d8d2c4")

# --- effect design ---------------------------------------------------------

func _specs(recipe: Dictionary) -> Array:
	var bounds: Dictionary = recipe.arena.bounds
	var mid_x: float = (float(bounds.minX) + float(bounds.maxX)) * 0.5
	var mid_z: float = (float(bounds.minZ) + float(bounds.maxZ)) * 0.5
	var specs: Array = []
	if map_id == "lacuna-court":
		# Restrained seam pulse along the two copper inlay arcs, plus localised
		# dust haze in the four quiet lanes (never on the court centreline).
		for side in [-1, 1]:
			specs.append({"tag": "seam", "style": "seam", "at": Vector3(side * 5, 6.4, side * 3), "extent": Vector3(2.6, 3.4, 8.6), "amount_high": 240, "amount_low": 70, "size": 0.12, "lifetime": 7.5, "speed": 0.14})
		for corner in 4:
			var sx := -1.0 if corner < 2 else 1.0
			var sz := -1.0 if corner % 2 == 0 else 1.0
			specs.append({"tag": "dust", "style": "mote", "at": Vector3(sx * 19, 2.6, sz * 15), "extent": Vector3(9, 2.2, 8), "amount_high": 520, "amount_low": 140, "size": 0.07, "lifetime": 9.0, "speed": 0.18})
	elif map_id == "vermilion-fold":
		# Light sheets drifting inside the opaque crown, fan and pleat volumes,
		# at 6 m and above: no ground-level effect anywhere near a fold point.
		specs.append({"tag": "crown-sheet", "style": "sheet", "at": Vector3(0, 9.4, 0), "extent": Vector3(8, 1.8, 8), "amount_high": 150, "amount_low": 45, "size": 1.9, "lifetime": 11.0, "speed": 0.16})
		specs.append({"tag": "fan-sheet", "style": "sheet", "at": Vector3(0, 8.8, -17), "extent": Vector3(6, 1.3, 4), "amount_high": 120, "amount_low": 35, "size": 1.7, "lifetime": 10.0, "speed": 0.14})
		specs.append({"tag": "pleat-sheet", "style": "sheet", "at": Vector3(0, 8.6, 17), "extent": Vector3(7, 1.2, 3.4), "amount_high": 110, "amount_low": 35, "size": 1.6, "lifetime": 10.0, "speed": 0.14})
		for z in [-17, 0, 17]:
			specs.append({"tag": "tension-breathe", "style": "seam", "at": Vector3(0, 7.4, z), "extent": Vector3(11, 3.4, 1.4), "amount_high": 90, "amount_low": 25, "size": 0.12, "lifetime": 6.5, "speed": 0.10})
	else:
		# Sparse suspended motes in the vault bays plus slow bounded pressure
		# pulses wrapped around the memory drum (never a ground ring).
		for bay in 5:
			var angle := TAU * bay / 5.0
			specs.append({"tag": "vault-mote", "style": "mote", "at": Vector3(mid_x + cos(angle) * 15.0, 3.6, mid_z + sin(angle) * 13.0), "extent": Vector3(10, 4.0, 9), "amount_high": 430, "amount_low": 120, "size": 0.075, "lifetime": 12.0, "speed": 0.14})
		for ring in 2:
			specs.append({"tag": "pressure-%d" % ring, "style": "pulse", "at": Vector3(mid_x, 8.0 + ring * 1.1, mid_z), "extent": Vector3(9, 2.6, 9), "amount_high": 150, "amount_low": 45, "size": 0.85, "lifetime": 1.8, "speed": 3.4 + ring * 0.8, "period": 5.5 + ring * 2.0, "one_shot": true})
	return specs

func _add_emitter(spec: Dictionary) -> void:
	var node := GPUParticles3D.new()
	node.name = "Fx" + str(spec.tag).capitalize().replace("-", "")
	node.position = spec.at
	node.amount = int(spec.amount_high)
	node.lifetime = float(spec.lifetime)
	node.explosiveness = 1.0 if bool(spec.get("one_shot", false)) else 0.0
	node.one_shot = bool(spec.get("one_shot", false))
	node.randomness = 1.0
	node.fixed_fps = 30.0
	node.interpolate = true
	node.fract_delta = true
	node.local_coords = false
	node.use_fixed_seed = true
	node.seed = 20240922 + emitters.size() * 7919
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.draw_order = GPUParticles3D.DRAW_ORDER_LIFETIME
	node.visibility_aabb = AABB(Vector3(-spec.extent.x * 2.0, -spec.extent.y * 2.5, -spec.extent.z * 2.0), spec.extent * 4.0)
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	mesh.material = _draw
	node.draw_pass_1 = mesh
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = spec.extent
	process.direction = Vector3(0, 1, 0)
	process.gravity = Vector3.ZERO
	process.angular_velocity_min = -6.0
	process.angular_velocity_max = 6.0
	var speed := float(spec.speed)
	match str(spec.style):
		"mote":
			process.spread = 180.0
			process.initial_velocity_min = speed * 0.2
			process.initial_velocity_max = speed
			process.damping_min = 0.02
			process.damping_max = 0.08
			process.scale_min = float(spec.size) * 0.5
			process.scale_max = float(spec.size) * 1.4
			process.color_ramp = _ramp(Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.40), Color(1, 1, 1, 0.0))
		"seam":
			process.spread = 60.0
			process.initial_velocity_min = speed * 0.1
			process.initial_velocity_max = speed
			process.damping_min = 0.0
			process.damping_max = 0.04
			process.scale_min = float(spec.size) * 0.4
			process.scale_max = float(spec.size) * 1.1
			process.color_ramp = _ramp(Color(1, 0.94, 0.82, 0.0), Color(1, 0.86, 0.62, 0.5), Color(1, 0.92, 0.78, 0.0))
		"sheet":
			process.spread = 25.0
			process.initial_velocity_min = speed * 0.05
			process.initial_velocity_max = speed
			process.damping_min = 0.0
			process.damping_max = 0.03
			process.scale_min = float(spec.size) * 0.55
			process.scale_max = float(spec.size) * 1.25
			process.color_ramp = _ramp(Color(1, 0.96, 0.92, 0.0), Color(1, 0.9, 0.86, 0.34), Color(1, 0.97, 0.94, 0.0))
		"pulse":
			process.spread = 180.0
			process.initial_velocity_min = speed * 0.75
			process.initial_velocity_max = speed
			process.damping_min = 1.4
			process.damping_max = 2.4
			process.scale_min = float(spec.size) * 0.35
			process.scale_max = float(spec.size) * 0.6
			process.scale_curve = _curve()
			process.color_ramp = _ramp(Color(0.9, 0.97, 1.0, 0.0), Color(0.82, 0.92, 1.0, 0.30), Color(0.95, 0.98, 1.0, 0.0))
	node.process_material = process
	node.emitting = true
	add_child(node)
	emitters.append({
		"node": node, "process": process, "tag": str(spec.tag),
		"center": spec.at, "radius": Vector3(spec.extent.x, spec.extent.y, spec.extent.z).length(),
		"high": int(spec.amount_high), "low": int(spec.amount_low),
		"period": float(spec.get("period", 0.0)),
	})

static func _ramp(start: Color, mid: Color, end: Color) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, start)
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, end)
	gradient.add_point(0.5, mid)
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture

static func _curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(0.6, 1.0))
	curve.add_point(Vector2(1.0, 0.9))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture

# --- budget / lifecycle ----------------------------------------------------

func set_quality(level: String) -> bool:
	if not QUALITY.has(level): return false
	quality = level
	budget = int(QUALITY[level])
	allocated = 0
	for emitter: Dictionary in emitters:
		var amount: int = int(emitter.high if level == "High" else emitter.low)
		(emitter.node as GPUParticles3D).amount = amount
		allocated += amount
	_sync()
	return true

func set_paused(value: bool) -> void:
	paused = value
	_sync()

func reset() -> void:
	_clock = 0.0
	for emitter: Dictionary in emitters:
		var node: GPUParticles3D = emitter.node
		node.emitting = false
		node.restart(true)
	_sync()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused = false
		_sync()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focused = true
		_sync()

func _sync() -> void:
	var tree_paused := is_inside_tree() and get_tree().paused
	var hidden := is_inside_tree() and not is_visible_in_tree()
	_suspended = paused or not focused or tree_paused or hidden
	for emitter: Dictionary in emitters:
		var node: GPUParticles3D = emitter.node
		node.speed_scale = 0.0 if _suspended else 1.0
		node.emitting = not _suspended

func _gate() -> void:
	var camera := _camera
	if not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d() if is_inside_tree() else null
	for emitter: Dictionary in emitters:
		var node: GPUParticles3D = emitter.node
		var visible_here := true
		if is_instance_valid(camera):
			var distance := camera.global_position.distance_to(node.global_position)
			visible_here = distance <= GATE_DISTANCE + float(emitter.radius)
		node.emitting = visible_here and not _suspended

func _process(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	_clock += delta
	_gate_clock += delta
	if not _suspended:
		if _gate_clock >= GATE_INTERVAL:
			_gate_clock = 0.0
			_gate()
		for emitter: Dictionary in emitters:
			if float(emitter.period) <= 0.0: continue
			var node: GPUParticles3D = emitter.node
			if node.emitting:
				var phase := fmod(_clock, float(emitter.period))
				if phase < delta:
					# One bounded restart per period; no per-frame work.
					node.restart(true)

func snapshot() -> Dictionary:
	var live := 0
	var active := 0
	for emitter: Dictionary in emitters:
		var node: GPUParticles3D = emitter.node
		if node.emitting:
			active += 1
			live += node.amount
	return {
		"quality": quality, "budget": budget, "allocated": allocated,
		"emitters": emitters.size(), "active_emitters": active, "submitted_particles": live,
		"backend": "GPUParticles3D", "suspended": _suspended, "paused": paused,
		"gate_distance": GATE_DISTANCE, "per_frame_allocation": false,
		"gameplay_authority": false, "texture_bytes": 0,
	}
