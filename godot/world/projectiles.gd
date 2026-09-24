class_name PortProjectiles
extends Node3D

# Presentation only: no prediction, collision, damage, or disappearance explosions.
# A short emissive exhaust is part of the rocket mesh, never a hitscan tracer.
#
# Faster-reading flight: authoritative samples (20 Hz or 60 Hz) snap exactly onto
# the marker, then a bounded dead-reckoned offset and an exhaust ribbon keep the
# motion continuous between samples. A bounce (reversed velocity) or a teleport
# clears the ribbon and restarts from the fresh sample; a stale trail fades. No
# collision, hit, damage or endpoint is ever invented here.
const MAX_PROJECTILES := 128
const MAX_SCAN := 512
const ORIGIN_SECONDS := 0.12
const MAX_ORIGINS := 128
const SAMPLE_MIN_DT := 0.001
const SAMPLE_MAX_DT := 0.5
## Longest visual lead past the last authoritative sample and its distance cap.
const EXTRAPOLATE_MAX := 0.12
const EXTRAPOLATE_MAX_METERS := 3.0
## A sample that jumps further than this, reverses more than ~105 degrees, or
## arrives after a time gap is a bounce/teleport: snap and restart the ribbon.
const TELEPORT_METERS := 3.0
const REVERSAL_DOT := -0.25
const TRAIL_POINTS := 7
const TRAIL_MIN_STEP := 0.05
const TRAIL_STALE := 0.30
const TRAIL_WIDTH_HEAD := 0.062
const TRAIL_WIDTH_TAIL := 0.010
const TRAIL_TINTS: Array[Color] = [
	Color("70ffe6"), Color("ffad61"), Color("bb9aff"), Color("ffde87"), Color("72cfff"),
	Color("ff806b"), Color("8ce8ff"), Color("ffd166"), Color("ffd27a"), Color("8affc1"),
]
var markers: Dictionary = {}
var flight: Dictionary = {}
var rocket_mesh: ArrayMesh
var generic_mesh: SphereMesh
var launch_origins: Dictionary = {}
var authoritative: Dictionary = {}
var occlusion: Callable
var clock := 0.0
var samples := 0

func configure_occlusion(provider: Callable) -> void:
	occlusion = provider

## Primary fire in game/core.mjs increments the rocket serial immediately before
## emit('launch'); alt fire explicitly publishes projectile. sourceId preserves
## that serial on ordinal-ID Horde/native transports. Never match by proximity,
## event ordinal, volley, weapon alone, or pellet number.
static func launch_projectile_id(event: Dictionary) -> int:
	if event.get("type") != "launch": return -1
	if event.has("projectile"): return identity(event.projectile)
	if event.get("alt", false) or identity(event.get("weapon")) not in [1, 4, 5]: return -1
	var source := identity(event.get("sourceId", event.get("id")))
	return source - 1 if source > 0 else -1

func cache_launch(event: Dictionary, origin: Dictionary, local_id: int) -> void:
	var time: Variant = event.get("time")
	if not (time is float or time is int) or not is_finite(float(time)) or float(time) < 0: return
	var id := launch_projectile_id(event)
	var pos: Variant = point(event.get("pos"))
	if id < 0 or identity(event.get("actor")) != local_id or pos == null or not origin.get("position") is Vector3: return
	if launch_origins.has(id) or launch_origins.size() >= MAX_ORIGINS: return
	var muzzle: Vector3 = origin.position
	if muzzle.distance_to(pos) > 3.0 or _blocked(muzzle, pos): return
	launch_origins[id] = {"muzzle":muzzle, "launch":pos, "owner":local_id, "weapon":identity(event.get("weapon")), "until":clock+ORIGIN_SECONDS}
	_render_origins()

func _blocked(from: Vector3, to: Vector3) -> bool:
	return not occlusion.is_valid() or occlusion.call(from, to) != false

func _render_origins() -> void:
	for id: int in launch_origins.keys():
		var record: Dictionary = launch_origins[id]
		if clock >= record.until:
			launch_origins.erase(id)
			if markers.has(id) and authoritative.has(id): _seat(id, authoritative[id].pos)
			continue
		if not markers.has(id) or not authoritative.has(id): continue
		var sample: Dictionary = authoritative[id]
		if sample.owner != record.owner or sample.weapon != record.weapon or sample.pos.distance_to(record.launch) > 8.0 or _blocked(record.muzzle, sample.pos):
			launch_origins.erase(id)
			_seat(id, sample.pos)
			continue
		var weight := clampf(1.0-(record.until-clock)/ORIGIN_SECONDS, 0.0, 1.0)
		var blended: Vector3 = record.muzzle.lerp(sample.pos, weight)
		markers[id].position = blended
		if flight.has(id): flight[id].visual = blended

## Snap the presentation (and the dead-reckoning origin) onto an authoritative
## sample. The ribbon is kept: it continues from the fresh position.
func _seat(id: int, pos: Vector3) -> void:
	if not markers.has(id): return
	markers[id].position = pos
	if flight.has(id):
		flight[id].visual = pos
		flight[id].sample = pos

func _process(delta: float) -> void:
	if not is_finite(delta) or delta < 0: return
	clock += delta
	_advance_flight(delta)
	_render_origins()

static func identity(value: Variant) -> int:
	if not (value is int or value is float): return -1
	var number := float(value)
	if not is_finite(number) or number < 0 or number > 2147483647 or number != floor(number): return -1
	return int(number)

static func point(value: Variant) -> Variant:
	if not value is Dictionary: return null
	for key: String in ["x", "y", "z"]:
		if not (value.get(key) is float or value.get(key) is int): return null
		if not is_finite(float(value[key])) or absf(float(value[key])) > 100000.0: return null
	return Vector3(value.x, value.y, value.z)

func _init() -> void:
	# Shared low-poly mesh, pointing along local -Z. Three surfaces per rocket.
	rocket_mesh = ArrayMesh.new()
	var body := CylinderMesh.new()
	body.top_radius = 0.085
	body.bottom_radius = 0.085
	body.height = 0.42
	body.radial_segments = 8
	append_part(body, Vector3.ZERO, Color(0.65, 0.72, 0.78))
	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 0.085
	nose.height = 0.18
	nose.radial_segments = 8
	append_part(nose, Vector3(0, 0, -0.30), Color(1.0, 0.32, 0.08))
	var exhaust := CylinderMesh.new()
	exhaust.top_radius = 0.075
	exhaust.bottom_radius = 0.0
	exhaust.height = 0.65
	exhaust.radial_segments = 8
	append_part(exhaust, Vector3(0, 0, 0.535), Color(1.0, 0.66, 0.12))
	generic_mesh = SphereMesh.new()
	generic_mesh.radius = 0.14
	generic_mesh.height = 0.28
	generic_mesh.radial_segments = 8
	generic_mesh.rings = 4
	generic_mesh.material = material(Color(0.35, 0.9, 1.0))

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.albedo_color = color
	return result

func append_part(primitive: PrimitiveMesh, offset: Vector3, color: Color) -> void:
	var arrays := primitive.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var rotation := Basis(Vector3.RIGHT, -PI / 2.0)
	for index: int in range(vertices.size()):
		vertices[index] = rotation * vertices[index] + offset
		normals[index] = rotation * normals[index]
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	rocket_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	rocket_mesh.surface_set_material(rocket_mesh.get_surface_count() - 1, material(color))

func apply_state(state: Dictionary) -> void:
	if state.get("over", false):
		clear_round()
		return
	var sample_time: float = float(state.get("time")) if _number(state.get("time")) else -INF
	var present: Dictionary = {}
	var items: Variant = state.get("rockets", [])
	if items is Array and not state.get("over", false):
		for index: int in range(mini(items.size(), MAX_SCAN)):
			var item: Variant = items[index]
			if not item is Dictionary: continue
			var id := identity(item.get("id"))
			var owner := identity(item.get("owner"))
			var weapon := identity(item.get("weapon"))
			var pos: Variant = point(item.get("pos"))
			var direction: Variant = point(item.get("dir"))
			if id < 0 or owner < 0 or weapon < 0 or pos == null or direction == null: continue
			if direction.length_squared() < 0.000001 or present.has(id): continue
			if present.size() >= MAX_PROJECTILES: break
			present[id] = {"pos":pos,"dir":direction,"owner":owner,"weapon":weapon}
	# Retire missing IDs before allocating replacements: even a completely new
	# saturated snapshot never transiently doubles the scene/render-node budget.
	for id: int in markers.keys():
		if not present.has(id): _retire(id)
	authoritative = present
	for id: int in present:
		_apply_sample(id, present[id], sample_time)
	_render_origins()

## One authoritative sample for one projectile: exact snap on the marker, then a
## bounded velocity estimate for the interpolation between samples.
func _apply_sample(id: int, item: Dictionary, sample_time: float) -> void:
	if not markers.has(id): _spawn(id)
	var node: MeshInstance3D = markers[id]
	var pos: Vector3 = item.pos
	var record: Dictionary = flight.get(id, {})
	if record.is_empty():
		record = {"sample":pos, "visual":pos, "velocity":Vector3.ZERO, "sample_time":sample_time,
			"sample_age":0.0, "heading":item.dir.normalized(), "trail":[], "trail_timer":0.0, "weapon":item.weapon}
		flight[id] = record
		node.position = pos
	else:
		var dt: float = -1.0
		if sample_time > -INF and float(record.sample_time) > -INF:
			dt = sample_time - float(record.sample_time)
		var measured := Vector3.ZERO
		var valid := dt > SAMPLE_MIN_DT and dt < SAMPLE_MAX_DT
		if valid: measured = (pos - record.sample) / dt
		if not valid and dt >= 0.0:
			# A time gap or a rewound sample: restart dead reckoning cleanly.
			record.trail = []
			record.trail_timer = 0.0
			record.velocity = Vector3.ZERO
		elif valid and measured.is_finite() and measured.length() <= 300.0:
			var prior: Vector3 = record.velocity
			var reversal: bool = prior.length() > 1.0 and measured.length() > 1.0 and measured.normalized().dot(prior.normalized()) < REVERSAL_DOT
			if reversal or pos.distance_to(record.visual) > TELEPORT_METERS:
				# Bounce or teleport: snap and start a fresh ribbon in the new
				# direction. Never smooth across a discontinuity.
				record.trail = []
				record.trail_timer = 0.0
				record.velocity = measured
			elif prior.length() <= 0.5:
				record.velocity = measured
			else:
				record.velocity = prior.lerp(measured, 0.6)
		record.sample = pos
		record.visual = pos
		record.sample_age = 0.0
		record.sample_time = sample_time
		node.position = pos
	record.weapon = item.weapon
	samples += 1
	node.mesh = rocket_mesh if item.weapon == 1 else generic_mesh
	var forward: Vector3 = item.dir.normalized()
	var up := Vector3.RIGHT if absf(forward.dot(Vector3.UP)) > 0.99 else Vector3.UP
	node.basis = Basis.looking_at(forward, up)
	record.heading = forward
	node.set_meta("owner", item.owner)
	node.set_meta("weapon", item.weapon)

func _spawn(id: int) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "Projectile_%d" % id
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ribbon := MeshInstance3D.new()
	ribbon.name = "Exhaust_%d" % id
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ribbon.top_level = true
	ribbon.mesh = ImmediateMesh.new()
	var trail_material := StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.vertex_color_use_as_albedo = true
	trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ribbon.material_override = trail_material
	ribbon.visible = false
	marker.add_child(ribbon)
	# Child, not a sibling: the marker budget/counts stay exactly as they were.
	add_child(marker)
	markers[id] = marker

func _retire(id: int) -> void:
	if markers.has(id):
		markers[id].free()
		markers.erase(id)
	flight.erase(id)
	launch_origins.erase(id)

## Bounded presentation travel between authoritative samples. The offset is
## capped in both time and distance, so a stopped or destroyed projectile cannot
## fly on, and every fresh sample snaps it back to authority.
func _advance_flight(delta: float) -> void:
	for id: int in markers.keys():
		var node: MeshInstance3D = markers[id]
		if not is_instance_valid(node): continue
		var record: Dictionary = flight.get(id, {})
		if record.is_empty(): continue
		record.sample_age = minf(float(record.sample_age) + delta, EXTRAPOLATE_MAX)
		var offset: Vector3 = record.velocity * float(record.sample_age)
		if offset.length() > EXTRAPOLATE_MAX_METERS: offset = offset.normalized() * EXTRAPOLATE_MAX_METERS
		record.visual = record.sample + offset
		var speed: float = record.velocity.length()
		if speed > 0.5:
			var target: Vector3 = record.velocity / speed
			var heading: Vector3 = record.heading
			if heading.dot(target) < 0.9999:
				heading = heading.slerp(target, 1.0 - exp(-delta * 9.0))
				if heading.length_squared() > 0.000001:
					record.heading = heading.normalized()
					var up := Vector3.RIGHT if absf(record.heading.dot(Vector3.UP)) > 0.99 else Vector3.UP
					node.basis = Basis.looking_at(record.heading, up)
		node.position = record.visual
		_update_trail(node, record, delta)

## Exhaust ribbon: a bounded ring of recent presentation points drawn as one
## tapering, fading card in world space. Presentation only.
func _update_trail(node: MeshInstance3D, record: Dictionary, delta: float) -> void:
	var ribbon: MeshInstance3D = node.get_child(0) if node.get_child_count() > 0 else null
	if ribbon == null: return
	var trail: Array = record.trail
	var point: Vector3 = record.visual
	record.trail_timer = float(record.trail_timer) + delta
	if trail.is_empty() or trail[-1].distance_to(point) >= TRAIL_MIN_STEP:
		trail.append(point)
		record.trail_timer = 0.0
		while trail.size() > TRAIL_POINTS: trail.pop_front()
	elif float(record.trail_timer) > TRAIL_STALE:
		# The projectile stopped reporting movement: fade the ribbon out.
		trail.clear()
	if trail.size() < 2 or trail[0].distance_to(trail[-1]) < 0.08:
		ribbon.visible = false
		return
	var mesh: ImmediateMesh = ribbon.mesh
	mesh.clear_surfaces()
	var tint: Color = TRAIL_TINTS[clampi(int(record.weapon), 0, TRAIL_TINTS.size() - 1)]
	var eye := Vector3.UP
	if is_instance_valid(get_viewport()) and get_viewport().get_camera_3d() != null:
		eye = get_viewport().get_camera_3d().global_position
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(trail.size() - 1):
		var tail: Vector3 = trail[index]
		var head: Vector3 = trail[index + 1]
		var span: Vector3 = head - tail
		if span.length_squared() < 0.000001: continue
		var side: Vector3 = span.cross(eye - (head + tail) * 0.5)
		if side.length_squared() < 0.000001: side = Vector3.RIGHT
		side = side.normalized()
		var weight: float = float(index + 1) / float(trail.size() - 1)
		var width: float = lerpf(TRAIL_WIDTH_TAIL, TRAIL_WIDTH_HEAD, weight)
		var alpha: float = lerpf(0.04, 0.52, weight * weight)
		mesh.surface_set_color(Color(tint.r, tint.g, tint.b, alpha))
		mesh.surface_add_vertex(tail - side * TRAIL_WIDTH_TAIL)
		mesh.surface_add_vertex(head - side * width)
		mesh.surface_add_vertex(head + side * width)
		mesh.surface_add_vertex(tail - side * TRAIL_WIDTH_TAIL)
		mesh.surface_add_vertex(head + side * width)
		mesh.surface_add_vertex(tail + side * TRAIL_WIDTH_TAIL)
	mesh.surface_end()
	ribbon.visible = true

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func clear_round() -> void:
	for node: Node in markers.values(): node.free()
	markers.clear()
	flight.clear()
	launch_origins.clear()
	authoritative.clear()
	clock = 0.0
	samples = 0
