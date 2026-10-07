extends SceneTree
## Queued engine gate. -- --require-assets makes missing generated art a failure.
const Adapter = preload("res://vehicle_assets/attachment.gd")
const Puma = preload("res://vehicles/puma.gd")
const Chassis = preload("res://combined_arms/chassis.gd")
const Weather = preload("res://ambience/weather_look.gd")
const Fleet = preload("res://combined_arms/fleet.gd")
const MUZZLES := {"puma":[Vector3(-0.82, 1.18, 0.2), Vector3(0.82, 1.18, 0.2)], "titan":[Vector3(0, 1.5, 1.6)], "scout":[Vector3(0, 0.9, 0.6)]}
const DIMENSIONS := {"puma":Vector3(2.1,1.7,3.6),"titan":Vector3(3.0,2.2,5.4),"scout":Vector3(1.1,1.3,2.2)}
var failures := 0
var total_triangles := 0

func check(ok: bool, label: String) -> void:
	print("VEHICLE_ASSET ", "PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var require_assets := "--require-assets" in OS.get_cmdline_user_args()
	for kind: String in MUZZLES:
		var host: Node3D = Puma.new() if kind == "puma" else Chassis.new(kind)
		root.add_child(host)
		var installed := Adapter.install(host, kind)
		var present := ResourceLoader.exists("res://vehicle_assets/generated/%s-lod0.glb" % kind)
		check(installed == present, kind + " all assets accepted or procedural fallback")
		if require_assets: check(installed, kind + " generated art required")
		if not installed:
			check(host.wheels.size() == (16 if kind == "titan" else 4), kind + " fallback wheels")
			check(host.turret.get_child_count() > 0, kind + " fallback gun")
			host.free()
			continue
		check(not host is PhysicsBody3D, kind + " presentation-only root")
		var counts := [0,0,0]
		var bounds: Array = [AABB(),AABB(),AABB()]
		var started := [false,false,false]
		for target: Node3D in [host, host.turret] + host.wheels:
			var authored := 0
			for child: Node in target.get_children():
				if child is MeshInstance3D and child.visible:
					authored += 1
					var lod := 0 if child.visibility_range_begin == 0 else (1 if child.visibility_range_begin == 24 else 2)
					check(child.transform.is_equal_approx(Transform3D.IDENTITY), kind + " joint-local attachment")
					for surface in child.mesh.get_surface_count():
						var arrays: Array = child.mesh.surface_get_arrays(surface)
						counts[lod] += arrays[Mesh.ARRAY_INDEX].size()/3
						for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
							if not vertex.is_finite(): check(false, kind + " nonfinite imported geometry")
							var point: Vector3 = target.position+vertex
							if not started[lod]:
								bounds[lod] = AABB(point,Vector3.ZERO)
								started[lod] = true
							else: bounds[lod] = bounds[lod].expand(point)
			check(authored == 3, kind + " three rigid LODs per mount")
		for lod in 3:
			var size: Vector3 = DIMENSIONS[kind]
			var box: AABB = bounds[lod]
			var epsilon := 0.011 if kind == "scout" else 0.0001
			check(box.position.x >= -size.x/2-epsilon and box.end.x <= size.x/2+epsilon and box.position.y >= -0.0001 and box.end.y <= size.y+0.0001 and box.position.z >= -size.z/2-0.0001 and box.end.z <= size.z/2+0.0001,kind+" imported neutral OBB/ground bounds LOD%d" % lod)
			check(counts[lod] <= [100000,36000,16000][lod],kind+" measured triangle cap LOD%d" % lod)
			total_triangles += counts[lod]
			print("VEHICLE_IMPORTED_BUDGET ",JSON.stringify({"kind":kind,"lod":lod,"triangles":counts[lod],"min":str(box.position),"max":str(box.end)}))
		for angle: float in [0.0, 0.8, -2.1]:
			var state := {"yaw":angle, "turretYaw":0.7}
			host.position = Vector3(13, 7, -9)
			host.rotation_order = EULER_ORDER_XYZ
			host.rotation = Vector3(-0.2, angle, 0.3)
			host.turret.rotation.y = 0.7
			Adapter.apply_source_pose(host, state)
			check(is_equal_approx(host.turret.rotation.y, 0.7), kind + " source-relative turret yaw")
			var turret_art: MeshInstance3D
			for child: Node in host.turret.get_children():
				if child is MeshInstance3D and child.visible and child.visibility_range_begin == 0.0:
					turret_art = child
					break
			check(turret_art != null, kind + " authored turret art")
			if turret_art == null: continue
			for muzzle: Vector3 in MUZZLES[kind]:
				var expected := host.position + Basis(Vector3.UP, angle + 0.7) * muzzle
				var actual: Vector3 = turret_art.global_transform * (muzzle - Adapter.PIVOTS[kind])
				check(actual.distance_to(expected) < 0.00001, kind + " source muzzle with body bend")
		var weather := Weather.new()
		var accent_bindings: Array = host.get_meta("vehicle_accents", [])
		check(not accent_bindings.is_empty(), kind + " team material channel imported")
		for binding: Dictionary in accent_bindings:
			var mesh: MeshInstance3D = binding.node.get_ref()
			weather._bind_material(mesh, binding.surface, mesh.get_active_material(binding.surface))
		Adapter.set_team(host, Color.RED)
		for binding: Dictionary in accent_bindings:
			var mesh: MeshInstance3D = binding.node.get_ref()
			check(mesh.get_active_material(binding.surface).albedo_color == Color.RED, kind + " weather clone receives team")
		weather.clear()
		for binding: Dictionary in accent_bindings:
			check(binding.base.albedo_color == Color.RED, kind + " dry restore retains team")
		host.free()
	check(total_triangles <= 456000,"aggregate imported production cap")
	if require_assets:
		var fleet := Fleet.new()
		root.add_child(fleet)
		var vehicles: Array = []
		for i in 64:
			vehicles.append({"id":i,"kind":["puma","titan","scout"][i%3],"x":float(i%8)*8,"y":0.0,"z":float(i/8)*8,"yaw":0.0,"roll":0.0,"pitchBody":0.0,"health":100.0,"respawnTimer":0.0,"turretYaw":0.0,"vx":0.0,"vz":0.0,"driver":null})
		var before := Time.get_ticks_usec()
		check(fleet.apply_state({"time":1.0,"actors":[],"vehicles":vehicles}),"controlled 64-vehicle native roster accepted")
		var references: Array[WeakRef] = []
		for vehicle: Dictionary in vehicles:
			var node: Node3D = fleet.vehicle_node(vehicle.id)
			check(node != null and node.get_meta("authored_vehicle","") == vehicle.kind,"stress instance installed authored art")
			references.append(weakref(node))
		check(not fleet.apply_state({"actors":[],"vehicles":vehicles+[vehicles[0]]}),"65 vehicles rejected atomically")
		check(fleet.nodes.size()+fleet.secondary.size() == 64,"oversized roster leaves accepted ownership intact")
		fleet.clear_round()
		await process_frame
		for reference: WeakRef in references: check(reference.get_ref() == null,"cleared stress instance retired")
		print("VEHICLE_STRESS ",JSON.stringify({"instances":64,"elapsedUsec":Time.get_ticks_usec()-before,"classification":"controlled headless lifecycle; not wire/GPU/frame-rate evidence"}))
		fleet.free()
	quit(1 if failures else 0)
