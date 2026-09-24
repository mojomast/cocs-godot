class_name PortProjectiles
extends Node3D

# Presentation only: no prediction, collision, damage, or disappearance explosions.
# Every body is one shared mesh: primary rockets keep the original three-surface
# mesh, unknown projectiles the generic sphere, and each alt-fire type owns a
# distinct body built once in `_init` (segmented cluster drum, mortar teardrop
# with fins, flat proximity-mine disc with a blinking sensor eye, boxy flak
# canister with vents). A marker never allocates its mesh per shot.
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

## The four projectile alt modes from the locked source table (`game/alt-fire.mjs`),
## their source weapon colours and their alt-specific tracer accents.
const ALT_KINDS: Array[String] = ["cluster", "mortar", "mine", "bomb"]
const ALT_WEAPONS := {"cluster":1, "mortar":4, "mine":5, "bomb":7}
const WEAPON_COLORS := {1:Color("ffad61"), 4:Color("72cfff"), 5:Color("ff806b"), 7:Color("ffd166")}
const ALT_ACCENTS := {
	"cluster":Color("ffb066"), "mortar":Color("c9a6ff"),
	"mine":Color("8fd9ff"), "bomb":Color("ff9a7a"),
}
## The source mine blinks its sensor at 7 Hz once armed (`effects-fx.mjs`).
const MINE_BLINK_HZ := 7.0
const MINE_DEFAULT_ARM := 0.45
## Exhaust characters.  smoke: wide, soft, slow fade; spark: hot, tight, flicker;
## pulse: mine idle breathing that turns into the armed blink.
const ALT_TRAILS := {
	"cluster":{"tint":Color("ffb066"), "head":0.050, "tail":0.008, "alpha":0.75, "style":"spark", "fade":0.85},
	"mortar":{"tint":Color("b3a6d6"), "head":0.115, "tail":0.028, "alpha":0.50, "style":"smoke", "fade":0.32},
	"mine":{"tint":Color("8fd9ff"), "head":0.070, "tail":0.012, "alpha":0.50, "style":"pulse", "fade":0.70},
	"bomb":{"tint":Color("9a8f83"), "head":0.135, "tail":0.032, "alpha":0.50, "style":"smoke", "fade":0.30},
}
var markers: Dictionary = {}
var flight: Dictionary = {}
var rocket_mesh: ArrayMesh
var generic_mesh: SphereMesh
var alt_meshes: Dictionary = {}
var mine_eye_mesh: SphereMesh
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

static func positive(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) > 0.0

## Which alt body a snapshot rocket row should use, or "" for a primary/unknown
## projectile. Mirrors the locked source's own `altRocketKind` precedence: the
## behaviour fields first, then the alt identity, then the alt weapon fallback.
## Primary rockets and thrown grenades (no alt flag/identity/fields) stay generic.
static func alt_kind(item: Dictionary) -> String:
	if item.get("mine") == true: return "mine"
	if positive(item.get("bomblets")): return "cluster"
	if positive(item.get("flak")): return "bomb"
	if item.get("alt") != true and item.get("altId") == null: return ""
	var id := str(item.get("altId", ""))
	if id in ALT_KINDS: return id
	var weapon := identity(item.get("weapon"))
	for kind: String in ALT_KINDS:
		if int(ALT_WEAPONS[kind]) == weapon: return kind
	return ""

func _init() -> void:
	build_bodies()

## Shared geometry for every body: built once, reused by all markers, so a shot
## never allocates a mesh or material.
func build_bodies() -> void:
	# Shared low-poly mesh, pointing along local -Z. Three surfaces per rocket.
	rocket_mesh = ArrayMesh.new()
	var body := CylinderMesh.new()
	body.top_radius = 0.085
	body.bottom_radius = 0.085
	body.height = 0.42
	body.radial_segments = 8
	append_part(rocket_mesh, body, Vector3.ZERO, Color(0.65, 0.72, 0.78))
	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 0.085
	nose.height = 0.18
	nose.radial_segments = 8
	append_part(rocket_mesh, nose, Vector3(0, 0, -0.30), Color(1.0, 0.32, 0.08))
	var exhaust := CylinderMesh.new()
	exhaust.top_radius = 0.075
	exhaust.bottom_radius = 0.0
	exhaust.height = 0.65
	exhaust.radial_segments = 8
	append_part(rocket_mesh, exhaust, Vector3(0, 0, 0.535), Color(1.0, 0.66, 0.12))
	generic_mesh = SphereMesh.new()
	generic_mesh.radius = 0.14
	generic_mesh.height = 0.28
	generic_mesh.radial_segments = 8
	generic_mesh.rings = 4
	generic_mesh.material = material(Color(0.35, 0.9, 1.0))
	alt_meshes["cluster"] = build_cluster_body()
	alt_meshes["mortar"] = build_mortar_body()
	alt_meshes["mine"] = build_mine_body()
	alt_meshes["bomb"] = build_bomb_body()
	mine_eye_mesh = SphereMesh.new()
	mine_eye_mesh.radius = 0.045
	mine_eye_mesh.height = 0.09
	mine_eye_mesh.radial_segments = 8
	mine_eye_mesh.rings = 4
	mine_eye_mesh.material = material(ALT_ACCENTS["mine"], true)

## Cluster shell: a segmented tri-tube drum in the source rocket orange with
## emissive accent ribs, a light nose cap and a hot rear ring.
func build_cluster_body() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var drum := CylinderMesh.new()
	drum.top_radius = 0.105
	drum.bottom_radius = 0.105
	drum.height = 0.34
	drum.radial_segments = 10
	append_part(mesh, drum, Vector3(0, 0, 0.02), WEAPON_COLORS[1])
	for z: float in [-0.10, 0.02, 0.14]:
		var rib := CylinderMesh.new()
		rib.top_radius = 0.118
		rib.bottom_radius = 0.118
		rib.height = 0.032
		rib.radial_segments = 10
		append_part(mesh, rib, Vector3(0, 0, z), Color("7a4526"))
	var band := CylinderMesh.new()
	band.top_radius = 0.121
	band.bottom_radius = 0.121
	band.height = 0.026
	band.radial_segments = 10
	append_part(mesh, band, Vector3(0, 0, 0.02), ALT_ACCENTS["cluster"], true)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.0
	cap.bottom_radius = 0.105
	cap.height = 0.16
	cap.radial_segments = 10
	append_part(mesh, cap, Vector3(0, 0, -0.22), Color("ffd8a8"))
	var tail := CylinderMesh.new()
	tail.top_radius = 0.068
	tail.bottom_radius = 0.068
	tail.height = 0.05
	tail.radial_segments = 10
	append_part(mesh, tail, Vector3(0, 0, 0.215), ALT_ACCENTS["cluster"], true)
	return mesh

## Mortar round: a blue plasma teardrop with four violet stabilising fins and a
## soft emissive exhaust cone.
func build_mortar_body() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var core := SphereMesh.new()
	core.radius = 0.13
	core.height = 0.26
	core.radial_segments = 10
	core.rings = 6
	append_part(mesh, core, Vector3(0, 0, -0.03), WEAPON_COLORS[4])
	var shell := CylinderMesh.new()
	shell.top_radius = 0.0
	shell.bottom_radius = 0.10
	shell.height = 0.24
	shell.radial_segments = 10
	append_part(mesh, shell, Vector3(0, 0, -0.22), Color("a8e2ff"))
	var collar := CylinderMesh.new()
	collar.top_radius = 0.10
	collar.bottom_radius = 0.10
	collar.height = 0.10
	collar.radial_segments = 10
	append_part(mesh, collar, Vector3(0, 0, 0.13), Color("3f8fc4"))
	for index: int in 4:
		var angle := PI * 0.25 + index * PI * 0.5
		var fin := BoxMesh.new()
		fin.size = Vector3(0.014, 0.09, 0.14)
		var offset := Vector3(cos(angle) * 0.075, sin(angle) * 0.075, 0.20)
		append_part(mesh, fin, offset, ALT_ACCENTS["mortar"], true, Basis(Vector3(0, 0, 1), angle))
	var glow := CylinderMesh.new()
	glow.top_radius = 0.055
	glow.bottom_radius = 0.0
	glow.height = 0.20
	glow.radial_segments = 10
	append_part(mesh, glow, Vector3(0, 0, 0.32), ALT_ACCENTS["mortar"], true)
	return mesh

## Proximity mine: a wide flat disc in the source grenade red-orange with a dark
## hub and three sensor prongs. It is drawn in the low stance (flat, thin) and the
## blinking eye is a separate marker child so the arm state never mutates a
## shared material.
func build_mine_body() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	# The disc and hub keep the primitive's own +Y axis (no rocket roll): the
	# mine reads flat in the world while the body yaws to face travel.
	var flat := Basis(Vector3.RIGHT, PI / 2.0)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.17
	disc.bottom_radius = 0.15
	disc.height = 0.06
	disc.radial_segments = 12
	append_part(mesh, disc, Vector3(0, -0.02, 0), WEAPON_COLORS[5], false, flat)
	var hub := CylinderMesh.new()
	hub.top_radius = 0.062
	hub.bottom_radius = 0.062
	hub.height = 0.03
	hub.radial_segments = 10
	append_part(mesh, hub, Vector3(0, 0.02, 0), Color("7a3a30"), false, flat)
	for index: int in 3:
		var angle := index * TAU / 3.0 + 0.6
		var prong := BoxMesh.new()
		prong.size = Vector3(0.013, 0.13, 0.013)
		var offset := Vector3(cos(angle) * 0.115, -0.005, sin(angle) * 0.115)
		# Outward horizontal prongs: the base rotation lays the long axis flat,
		# this yaw points it radially away from the hub.
		append_part(mesh, prong, offset, Color("5c4a44"), false, Basis(Vector3.UP, atan2(-cos(angle), -sin(angle))))
	return mesh

## Flak bomb: a boxy yellow canister with a nose cap, vent bands and an emissive
## rear ring so the vented shell reads against both the rocket and the mortar.
func build_bomb_body() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var canister := BoxMesh.new()
	canister.size = Vector3(0.22, 0.22, 0.40)
	append_part(mesh, canister, Vector3.ZERO, WEAPON_COLORS[7])
	var cap := CylinderMesh.new()
	cap.top_radius = 0.0
	cap.bottom_radius = 0.115
	cap.height = 0.14
	cap.radial_segments = 4
	append_part(mesh, cap, Vector3(0, 0, -0.27), Color("fff0bf"))
	for z: float in [-0.09, 0.07]:
		var vent := BoxMesh.new()
		vent.size = Vector3(0.235, 0.045, 0.03)
		append_part(mesh, vent, Vector3(0, 0, z), Color("6d5520"))
	var slit := BoxMesh.new()
	slit.size = Vector3(0.245, 0.016, 0.024)
	append_part(mesh, slit, Vector3(0, 0, -0.01), ALT_ACCENTS["bomb"], true)
	var tail := CylinderMesh.new()
	tail.top_radius = 0.075
	tail.bottom_radius = 0.075
	tail.height = 0.05
	tail.radial_segments = 8
	append_part(mesh, tail, Vector3(0, 0, 0.215), ALT_ACCENTS["bomb"], true)
	return mesh

func material(color: Color, emissive := false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.albedo_color = color
	if emissive:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = 1.35
	return result

## One primitive surface appended to a shared body mesh, rotated from the
## primitive's own +Y axis onto the body's -Z axis and offset in local space.
func append_part(target: ArrayMesh, primitive: PrimitiveMesh, offset: Vector3, color: Color, emissive := false, extra := Basis()) -> void:
	var arrays := primitive.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var rotation := extra * Basis(Vector3.RIGHT, -PI / 2.0)
	for index: int in range(vertices.size()):
		vertices[index] = rotation * vertices[index] + offset
		normals[index] = rotation * normals[index]
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	target.surface_set_material(target.get_surface_count() - 1, material(color, emissive))

## The shared body for a snapshot row: alt body when the row carries an alt
## identity, the original rocket for weapon 1, the generic sphere otherwise.
func body_mesh(item: Dictionary) -> Mesh:
	var kind := str(item.get("kind", ""))
	if not kind.is_empty() and alt_meshes.has(kind): return alt_meshes[kind]
	return rocket_mesh if int(item.weapon) == 1 else generic_mesh

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
			var arm := float(item.get("arm")) if _number(item.get("arm")) else MINE_DEFAULT_ARM
			present[id] = {"pos":pos, "dir":direction, "owner":owner, "weapon":weapon,
				"kind":alt_kind(item), "mine":item.get("mine") == true, "arm":maxf(0.0, arm)}
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
			"sample_age":0.0, "heading":item.dir.normalized(), "trail":[], "trail_timer":0.0,
			"weapon":item.weapon, "kind":"", "arm":MINE_DEFAULT_ARM, "spawn_clock":clock, "armed":false}
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
	# A row can change body identity in place (id reuse or an upgraded snapshot):
	# the shared mesh and the arm budget follow authority, never the old picture.
	if record.kind != item.kind:
		var stale := node.get_node_or_null("Blink")
		if stale is MeshInstance3D: stale.hide()
		record.kind = item.kind
		record.spawn_clock = clock
		record.armed = false
	if item.mine and record.armed == false and clock - float(record.spawn_clock) >= float(record.arm):
		record.armed = true
	record.arm = item.arm
	record.weapon = item.weapon
	samples += 1
	node.mesh = body_mesh(item)
	_orient(node, item, record)
	if str(item.kind) == "mine": _ensure_blink(node, str(item.kind))
	node.set_meta("owner", item.owner)
	node.set_meta("weapon", item.weapon)
	node.set_meta("alt", item.kind)

## Body orientation: rockets, mortar rounds and flak canisters point down their
## flight axis; the mine keeps the source's flat, low stance and only yaws so the
## prongs face travel.
func _orient(node: MeshInstance3D, item: Dictionary, record: Dictionary) -> void:
	var forward: Vector3 = item.dir.normalized()
	record.heading = forward
	if str(item.kind) == "mine":
		node.basis = Basis(Vector3.UP, atan2(-forward.x, -forward.z))
		return
	var up := Vector3.RIGHT if absf(forward.dot(Vector3.UP)) > 0.99 else Vector3.UP
	node.basis = Basis.looking_at(forward, up)

func _spawn(id: int) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "Projectile_%d" % id
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ribbon := _make_ribbon("Exhaust_%d" % id)
	marker.add_child(ribbon)
	# Child, not a sibling: the marker budget/counts stay exactly as they were.
	add_child(marker)
	markers[id] = marker

## The mine's arming eye is the only extra child a marker can own, created lazily
## the first time that marker presents the mine body.
func _ensure_blink(node: MeshInstance3D, kind: String) -> MeshInstance3D:
	var existing := node.get_node_or_null("Blink")
	if existing is MeshInstance3D: return existing
	if kind != "mine": return null
	var blink := MeshInstance3D.new()
	blink.name = "Blink"
	blink.mesh = mine_eye_mesh
	blink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blink.position = Vector3(0, 0.048, 0)
	blink.visible = false
	node.add_child(blink)
	return blink

func _make_ribbon(name_value: String) -> MeshInstance3D:
	var ribbon := MeshInstance3D.new()
	ribbon.name = name_value
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
	return ribbon

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
					if str(record.kind) == "mine":
						node.basis = Basis(Vector3.UP, atan2(-record.heading.x, -record.heading.z))
					else:
						var up := Vector3.RIGHT if absf(record.heading.dot(Vector3.UP)) > 0.99 else Vector3.UP
						node.basis = Basis.looking_at(record.heading, up)
		node.position = record.visual
		if str(record.kind) == "mine": _update_arm(node, record)
		_update_trail(node, record, delta)

## Mine arming presentation: the eye is dark and small while the fuse burns, then
## blinks at the source's 7 Hz once `arm` has elapsed. Pure presentation on the
## existing clock; it never predicts a trigger.
func _update_arm(node: MeshInstance3D, record: Dictionary) -> void:
	var blink := _ensure_blink(node, str(record.kind))
	if blink == null: return
	var armed: bool = clock - float(record.spawn_clock) >= float(record.arm)
	record.armed = armed
	blink.scale = Vector3.ONE * (1.0 if armed else 0.6)
	blink.visible = armed and int(floor(clock * MINE_BLINK_HZ)) % 2 == 0

## Exhaust ribbon: a bounded ring of recent presentation points drawn as one
## tapering, fading card in world space. Alt types get their own width, colour,
## alpha and character (smoke/spark/pulse); there is still exactly one ribbon
## per projectile. Presentation only.
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
	var kind := str(record.kind)
	var traits: Dictionary = ALT_TRAILS.get(kind, {})
	var tint: Color = traits.get("tint", TRAIL_TINTS[clampi(int(record.weapon), 0, TRAIL_TINTS.size() - 1)])
	var head_width: float = float(traits.get("head", TRAIL_WIDTH_HEAD))
	var tail_width: float = float(traits.get("tail", TRAIL_WIDTH_TAIL))
	var strength: float = float(traits.get("alpha", 0.52))
	var fade_power: float = float(traits.get("fade", 1.0))
	var pulse := 1.0
	match str(traits.get("style", "")):
		"smoke":
			# Smoke plumes breathe instead of strobing; the wide, soft card is
			# the mortar arc and the flak plume.
			pulse = 0.75 + 0.25 * sin(clock * 3.1 + float(record.spawn_clock))
		"spark":
			# A hot spark trail flickers on a fast deterministic beat.
			pulse = 0.72 + 0.28 * sin(clock * 26.0)
		"pulse":
			# The mine idles with a slow breath, then blinks hard once armed.
			if bool(record.armed):
				pulse = 1.0 if int(floor(clock * MINE_BLINK_HZ)) % 2 == 0 else 0.12
			else:
				pulse = 0.62 + 0.38 * sin(clock * 2.2)
	if pulse <= 0.02:
		ribbon.visible = false
		return
	var mesh: ImmediateMesh = ribbon.mesh
	mesh.clear_surfaces()
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
		var width: float = lerpf(tail_width, head_width, weight)
		var alpha: float = lerpf(0.04, strength, pow(weight, fade_power)) * pulse
		mesh.surface_set_color(Color(tint.r, tint.g, tint.b, alpha))
		mesh.surface_add_vertex(tail - side * tail_width)
		mesh.surface_add_vertex(head - side * width)
		mesh.surface_add_vertex(head + side * width)
		mesh.surface_add_vertex(tail - side * tail_width)
		mesh.surface_add_vertex(head + side * width)
		mesh.surface_add_vertex(tail + side * tail_width)
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
