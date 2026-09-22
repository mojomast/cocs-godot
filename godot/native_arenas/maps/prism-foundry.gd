extends "res://showcase/demo.gd"
const DM = preload("res://native_arenas/maps/geometry.gd")
var built := false
var collider_sources: Array = []

func _ready() -> void:
	build()

func get_arena_id() -> String:
	return "prism-foundry"

func configure_dm() -> void:
	build()

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
	super._rail(a, b, material)
	var body: Node3D = get_child(get_child_count() - 1)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = body.get_child(0).shape.size
	mesh.mesh = box_mesh
	mesh.material_override = materials.dark
	body.add_child(mesh)

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
