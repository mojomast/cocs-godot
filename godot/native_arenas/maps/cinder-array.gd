extends "res://cinder_array/map.gd"
const DM = preload("res://native_arenas/maps/geometry.gd")
var dm_built := false
var collider_sources: Array = []

func get_arena_id() -> String:
	return "cinder-array"

func configure_dm() -> void:
	build()

func build() -> void:
	if dm_built: return
	dm_built = true
	super.build()
	# A second tactical chord turns the scenic circuit into a three-lane DM loop.
	DM.prism(self, "CoolingCrosslink", PackedVector3Array([Vector3(-40, 12, -7.5), Vector3(-40, 12, -2.5), Vector3(16, 12, -2.5), Vector3(16, 12, -7.5)]), 0.5, materials.dark)
	DM.prism(self, "TransferCrosslinkRamp", PackedVector3Array([Vector3(-28, 7, 20), Vector3(-23, 7, 20), Vector3(-23, 12, -1), Vector3(-28, 12, -1)]), 0.5, materials.deck)
	DM.box(self, "TransferCrosslinkLanding", Vector3(-25.5, 6.25, -3), Vector3(5, 11.5, 4), materials.deck, true)
	for p in [Vector3(-28, 8, 27), Vector3(21, 13, -3), Vector3(-27, 17, -30.5), Vector3(-14, 13, -6.7), Vector3(2, 13, -3.3)]:
		DM.box(self, "ReactorServiceCover", p, Vector3(2.6, 2, 1.8), materials.orange)
	collider_sources = DM.collect(self, get_arena_id())

func _profile(connection: Dictionary) -> Array[Vector3]:
	if connection.name == "BoreFloor":
		return [Vector3(26, 12, -31), Vector3(14, 16, -31), Vector3(0, 16, -31), Vector3(-8, 12, -31)]
	return super._profile(connection)

func _bore() -> void:
	var profile: Array[Vector3] = connections[2].profile
	for i in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		DM.prism(self, "SealedBasaltBore%d" % i, PackedVector3Array([a + Vector3(0, -0.6, -3.5), a + Vector3(0, -0.6, 3.5), b + Vector3(0, -0.6, 3.5), b + Vector3(0, -0.6, -3.5)]), 0.5, materials.rock)
		for side in [-1, 1]:
			geo.beam("BoreCausewayGuide", a + Vector3(0, 0.05, side * 3.2), b + Vector3(0, 0.05, side * 3.2), 0.12, 0.12, materials.teal)
	_text("DMCausewayIdentity", "04 / SEALED BASALT CAUSEWAY", Vector3(7, 18, -34.6), 0.02, Color("c6e5df"))

func _rail(a: Vector3, b: Vector3) -> void:
	# Crosslink gateways on the west/east platforms and transfer deck.
	if (a.y > 11.9 and a.y < 12.1 and b.y > 11.9 and b.y < 12.1 and minf(a.z, b.z) < -2 and maxf(a.z, b.z) > -8): return
	if a.y == 7 and b.y == 7 and minf(a.x, b.x) < -22 and maxf(a.x, b.x) > -29 and minf(a.z, b.z) < 20: return
	super._rail(a, b)
	var side := Vector3(-(b - a).z, 0, (b - a).x).normalized() * 0.095
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sign_value in [-1, 1]:
		Geometry.quad(st, a + side * sign_value, b + side * sign_value, b + side * sign_value + Vector3.UP * 1.28, a + side * sign_value + Vector3.UP * 1.28)
	st.generate_normals()
	geo.add_mesh("SolidSafetyPanel", st.commit(), materials.dark)

func get_spawn_points() -> Array[Vector3]:
	return DM.spawns(get_arena_id(), get_authoring_spawns())

func get_authoring_spawns() -> Array[Vector3]:
	return [Vector3(-24, 7, 28), Vector3(25, 12, -8), Vector3(26, 12, -30), Vector3(-8, 12, -31), Vector3(-29, 16, -26), Vector3(-41, 12, -5)]

func get_dm_routes() -> Array:
	var routes: Array = []
	for connection in connections: routes.append({"id": connection.name, "points": connection.profile})
	routes.append({"id": "cooling-crosslink", "points": [Vector3(-40, 12, -5), Vector3(16, 12, -5)]})
	routes.append({"id": "transfer-chord", "points": [Vector3(-25.5, 7, 20), Vector3(-25.5, 12, -1), Vector3(-25.5, 12, -5)]})
	routes.append({"id": "observatory-console-flank", "points": [Vector3(-36, 16, -30), Vector3(-33.5, 16, -29), Vector3(-31, 16, -27)]})
	return routes
