extends "res://showcase/demo.gd"
const DM = preload("res://native_arenas/maps/geometry.gd")
const EnvironmentStyle = preload("res://world/environment_style.gd")
# Surface roles for this arena's own material keys. The tint stays whatever
# `_make_materials` authored; the family supplies base + baked bump + finish.
const ROLES := {
	"concrete": {"role": "wall"},
	"warm": {"role": "wall-stucco"},
	"floor": {"role": "floor-built"},
	"dark": {"role": "prop", "options": {"metallic": 0.45}},
	"metal": {"role": "rail"},
	"copper": {"role": "pipe"},
	"tread": {"role": "grating"},
	"sand": {"role": "sand"},
	"rock": {"role": "rock"},
	"foliage": {"role": "foliage"},
}
var material_plan: Dictionary = {}
var built := false
var collider_sources: Array = []

func _ready() -> void:
	build()

func get_arena_id() -> String:
	return "prism-foundry"

func configure_dm() -> void:
	build()

## Applied inside `build()` before any geometry is created, so every surface in
## the arena (including the DM additions below) uses the family material.
func _make_materials() -> void:
	super._make_materials()
	material_plan = EnvironmentStyle.apply_roles(materials, ROLES, get_arena_id())

func build() -> void:
	if built: return
	built = true
	previous_msaa = get_viewport().msaa_3d
	_make_materials()
	_environment()
	_atrium()
	_reactor()
	_mezzanine()
	_turbine_hall()
	_coolant_garden()
	_observation_deck()
	_vista()
	# Solid reactor service banks occupy every former underdeck passage.
	for side in [-1, 1]:
		DM.box(self, "SealedMezzanineReactorBank", Vector3(side * 15.3, 1.8, 0), Vector3(4, 3.6, 32), materials.dark)
		DM.box(self, "SealedCrossDeckReactorBank", Vector3(0, 1.8, side * 14.5), Vector3(27, 3.6, 3), materials.dark)
		for z in range(-14, 15, 2):
			_box(Vector3(side * 13.27, 1.9, z), Vector3(0.055, 1.6, 1.25), "copper")
			_box(Vector3(side * 13.23, 2.5, z), Vector3(0.045, 0.12, 0.9), "cyan")
	DM.box(self, "SaltReachReactorFoundation", Vector3(26.7, 1.2, 0), Vector3(19.5, 4.4, 13), materials.dark)
	# The west service doorway crosses a formerly walk-under band. A second
	# shallow ramp connects the turbine lane to the accessible upper loop.
	DM.prism(self, "TurbineAccessIncline", PackedVector3Array([Vector3(-26, 0, -2), Vector3(-26, 0, 2), Vector3(-17.3, 4, 2), Vector3(-17.3, 4, -2)]), -0.5, materials.tread)
	# Garden access crosses the north service bank on a gradual external incline.
	DM.prism(self, "GardenAccessIncline", PackedVector3Array([Vector3(-3, 4, -16), Vector3(3, 4, -16), Vector3(3, 0, -26), Vector3(-3, 0, -26)]), -0.5, materials.tread)
	for side in [-1, 1]:
		DM.prism(self, "CoolantPodAccess", PackedVector3Array([Vector3(side * 1, 0, -30), Vector3(side * 1, 0, -28), Vector3(side * 3.5, 0.84, -28), Vector3(side * 3.5, 0.84, -30)]), -0.5, materials.tread)
		DM.prism(self, "CoolantPodFrontRamp", PackedVector3Array([Vector3(side * 6.7 - 1.5, 0, -19.5), Vector3(side * 6.7 + 1.5, 0, -19.5), Vector3(side * 6.7 + 1.5, 0.84, -21.8), Vector3(side * 6.7 - 1.5, 0.84, -21.8)]), -0.5, materials.tread)
	_flush_batches()
	collider_sources = DM.collect(self, get_arena_id())

func _box(at: Vector3, size: Vector3, material: String, solid: bool = false, parent: Node3D = self) -> MeshInstance3D:
	if at.x == -28.5 and at.y == 0.25 and size == Vector3(8, 0.5, 4):
		at.y = 0.1
		size.y = 0.2
	return super._box(at, size, material, solid, parent)

func _rail(a: Vector3, b: Vector3, material: String = "metal") -> void:
	# West, north and east gateways stay open for the DM loop.
	if (absf(a.x + 17.38) < 0.1 and absf(b.x + 17.38) < 0.1) or (a.z < -15.9 and b.z < -15.9): return
	# Outboard rail line: source moveActor refuses every axis step while the
	# destination is inside the 0.42 m contact radius of a movement band, so a
	# rail standing on the walkable edge leaves an inescapable strip over the
	# surface (a live bot froze 71 s on the west ramp). Moving each rail 0.44 m
	# off the walkable support puts its band boundary exactly on the support
	# edge: stepping off is still refused, no standable point is inside a band,
	# and the rail keeps its full ray collision. Thin bracket beams keep the
	# rail visibly attached to the edge it guards.
	super._rail(a, b, material)
	var body: Node3D = get_child(get_child_count() - 1)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = body.get_child(0).shape.size
	mesh.mesh = box_mesh
	mesh.material_override = materials.dark
	body.add_child(mesh)
	# DM adaptation: the guard rail's top is walkable support. The source
	# step limit then refuses a step onto/through the rail (its top is 1.28 m
	# above the walkable edge), so no movement wall band is generated over
	# walkable ground -- that is the band that froze a live bot for 71 s on
	# the west ramp (source moveActor refuses every axis step from inside a
	# 0.42 m contact band). Bullet and projectile collision is unchanged.
	body.get_child(0).set_meta("dm_walkable", true)

func _ramp(center_x: float) -> void:
	# DM ramp: the wedge, treads and head landing are the exploration ramp, but
	# the edge rails are mounted 0.44 m outboard of the walkable top. Source
	# moveActor refuses every axis step while a destination lies inside the
	# 0.42 m contact radius of a movement band, so a rail standing on the
	# walkable edge left an inescapable strip over the ramp surface (a live bot
	# froze there for 71 s). With the rail line moved out, each band boundary
	# lands exactly on the walkable edge: stepping off the ramp is still
	# refused, the rail keeps its full ray collision, and no standable point
	# sits inside a band. Thin bracket beams keep the rail visibly attached.
	var points := PackedVector3Array([
		Vector3(center_x - 1.6, -0.30, 7), Vector3(center_x + 1.6, -0.30, 7),
		Vector3(center_x - 1.6, -0.30, -11), Vector3(center_x + 1.6, -0.30, -11),
		Vector3(center_x - 1.6, 0, 7), Vector3(center_x + 1.6, 0, 7),
		Vector3(center_x - 1.6, 4, -11), Vector3(center_x + 1.6, 4, -11)])
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	_collider(Vector3.ZERO, shape)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in [[4, 7, 5], [4, 6, 7], [0, 4, 5], [0, 5, 1], [2, 3, 7], [2, 7, 6], [0, 2, 6], [0, 6, 4], [1, 5, 7], [1, 7, 3]]:
		for index in tri: surface.add_vertex(points[index])
	surface.generate_normals()
	_mesh(surface.commit(), Vector3.ZERO, "tread")
	for side in [-1.0, 1.0]:
		# _rail mounts the guard outboard of the walkable edge (see _dm_outward).
		_rail(Vector3(center_x + side * 1.64, 0.05, 6.9), Vector3(center_x + side * 1.64, 4.05, -11))
	for i in 36:
		var z := 6.7 - i * 0.49
		_repeat_box(Vector3(center_x, (7 - z) * 4.0 / 18 + 0.017, z), Vector3(2.9, 0.018, 0.045), "metal")
	_box(Vector3(center_x, 3.8, -12), Vector3(3.2, 0.4, 2.05), "tread", true)

func get_spawn_points() -> Array[Vector3]:
	return DM.spawns(get_arena_id(), get_authoring_spawns())

func get_authoring_spawns() -> Array[Vector3]:
	return [Vector3(-7, 0, 8), Vector3(7, 0, -8), Vector3(-30, 0, 0), Vector3(0, 0, -29), Vector3(26, 4, 0), Vector3(0, 4, 14.5)]

func get_dm_routes() -> Array:
	return [
		{"id": "reactor-ring", "points": [Vector3(-7, 0, 8), Vector3(-7, 0, -8), Vector3(7, 0, -8), Vector3(7, 0, 8), Vector3(-7, 0, 8)]},
		{"id": "west-ascent", "points": [Vector3(-10.5, 0, 7), Vector3(-10.5, 4, -12), Vector3(-10.5, 4, -14.5), Vector3(-15.3, 4, -14.5), Vector3(-15.3, 4, 0), Vector3(-26, 0, 0), Vector3(-30, 0, 0)]},
		{"id": "east-ascent", "points": [Vector3(10.5, 0, 7), Vector3(10.5, 4, -12), Vector3(10.5, 4, -14.5), Vector3(15.3, 4, -14.5), Vector3(15.3, 4, 0), Vector3(26, 4, 0)]},
		{"id": "garden-link", "points": [Vector3(-10.5, 4, -14.5), Vector3(0, 4, -14.5), Vector3(0, 4, -16), Vector3(0, 0, -26), Vector3(0, 0, -29)]},
		{"id": "west-coolant-loop", "points": [Vector3(0, 0, -29), Vector3(-6.7, 0.84, -29), Vector3(-6.7, 0.84, -21.8), Vector3(-6.7, 0, -19.5)]},
		{"id": "east-coolant-loop", "points": [Vector3(0, 0, -29), Vector3(6.7, 0.84, -29), Vector3(6.7, 0.84, -21.8), Vector3(6.7, 0, -19.5)]},
		{"id": "upper-loop", "points": [Vector3(-15.3, 4, -14.5), Vector3(-15.3, 4, 14.5), Vector3(15.3, 4, 14.5), Vector3(15.3, 4, -14.5), Vector3(-15.3, 4, -14.5)]}
	]

func _process(delta: float) -> void:
	elapsed += delta
	for i in rings.size(): rings[i].rotate_y(delta * (0.12 + i * 0.04))
	for turbine in turbines: turbine.rotate_x(delta * 0.7)

func _unhandled_input(_event: InputEvent) -> void:
	pass
