extends "res://aurora_basin/map.gd"
const DM = preload("res://native_arenas/maps/geometry.gd")
var dm_built := false
var collider_sources: Array = []

func _ready() -> void:
	build()

func get_arena_id() -> String:
	return "aurora-basin"

func configure_dm() -> void:
	build()

func terrain_height(x: float, z: float) -> float:
	# A shallow snow datum removes the exploration loop's 32cm cliff lip.
	# Distant sculpted ridges remain outside the visible combat berms.
	var radius := Vector2(x, z).length()
	return lerpf(-0.15, super.terrain_height(x, z), smoothstep(62, 73, radius))

func build() -> void:
	if dm_built: return
	dm_built = true
	super.build()
	for i in skywalk_points.size() - 1:
		var a := skywalk_points[i]
		var b := skywalk_points[i + 1]
		var sa := _side(skywalk_points, i) * DECK_WIDTH * 0.5
		var sb := _side(skywalk_points, i + 1) * DECK_WIDTH * 0.5
		var slab_bottom := Vector3.DOWN * 0.35
		DM.prism(self, "CrownIceButtress%03d" % i, PackedVector3Array([a - sa + slab_bottom, a + sa + slab_bottom, b + sb + slab_bottom, b - sb + slab_bottom]), -0.5, materials.ice)
	var crown := PackedVector3Array()
	for i in 64: crown.append(Vector3(16 + cos(i * TAU / 64) * 6, 8.36, -34 + sin(i * TAU / 64) * 6))
	DM.prism(self, "VistaIceButtress", crown, -0.5, materials.ice)
	# Bounded, human-scale ice cover breaks the long lake sight lines.
	for p in [Vector3(-12, 0.94, 5), Vector3(10, 0.94, 7), Vector3(17, 0.94, -14), Vector3(-15, 0.94, -15)]:
		DM.box(self, "SealedIceSupplyPod", p, Vector3(3.2, 1.8, 2.4), materials.ice)
	DM.box(self, "PressureRidgeSolidCore", Vector3(-3, 1.54, -6), Vector3(2.5, 3, 2.5), materials.ice)
	# Visible low ice berms make the combat bounds explicit.
	for sign_value in [-1, 1]:
		DM.box(self, "ArenaIceBerm", Vector3(sign_value * 42, 1.2, 0), Vector3(1, 3, 85), materials.ice)
		DM.box(self, "ArenaIceBerm", Vector3(0, 1.2, sign_value * 42), Vector3(85, 3, 1), materials.ice)
	collider_sources = DM.collect(self, get_arena_id())

func _guard_line(label: String, edge: PackedVector3Array) -> void:
	var before := get_child_count()
	super._guard_line(label, edge)
	for i in range(before, get_child_count()):
		var child := get_child(i)
		if child is StaticBody3D:
			var mesh := MeshInstance3D.new()
			var shape: BoxShape3D = child.get_child(0).shape
			var box_mesh := BoxMesh.new()
			box_mesh.size = shape.size
			mesh.mesh = box_mesh
			mesh.material_override = materials.metal
			child.add_child(mesh)

func get_spawn_points() -> Array[Vector3]:
	return DM.spawns(get_arena_id(), get_authoring_spawns())

func get_authoring_spawns() -> Array[Vector3]:
	return [Vector3(-23, 0.105, 29), Vector3(20, 0.08, 19), Vector3(29, 0.08, -4), Vector3(-24, 0.08, -19), Vector3(16, 9, -34), Vector3(-6, 0.038, 15)]

func get_dm_routes() -> Array:
	return [{"id": "crown-ascent", "points": Array(skywalk_points)}, {"id": "lake-circuit", "points": Array(route_points)}, {"id": "landing-link", "points": Array(landing_points)}, {"id": "eastern-snow-flank", "points": [Vector3(39, -0.15, -6), Vector3(40.3, -0.15, -2), Vector3(40.3, -0.15, 12), Vector3(35, -0.15, 18), Vector3(23, 0.08, 18)]}]
