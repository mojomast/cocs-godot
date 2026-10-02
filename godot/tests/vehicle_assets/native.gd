extends SceneTree
## Queued engine gate. -- --require-assets makes missing generated art a failure.
const Adapter = preload("res://vehicle_assets/attachment.gd")
const Puma = preload("res://vehicles/puma.gd")
const Chassis = preload("res://combined_arms/chassis.gd")
const Weather = preload("res://ambience/weather_look.gd")
const MUZZLES := {"puma":[Vector3(-0.82, 1.18, 0.2), Vector3(0.82, 1.18, 0.2)], "titan":[Vector3(0, 1.5, 1.6)], "scout":[Vector3(0, 0.9, 0.6)]}
var failures := 0

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
		for target: Node3D in [host, host.turret] + host.wheels:
			var authored := 0
			for child: Node in target.get_children():
				if child is MeshInstance3D and child.visible:
					authored += 1
					check(child.transform.is_equal_approx(Transform3D.IDENTITY), kind + " joint-local attachment")
					for surface in child.mesh.get_surface_count():
						var arrays: Array = child.mesh.surface_get_arrays(surface)
						for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
							if not vertex.is_finite(): check(false, kind + " nonfinite imported geometry")
			check(authored == 3, kind + " three rigid LODs per mount")
		for angle: float in [0.0, 0.8, -2.1]:
			var state := {"yaw":angle, "turretYaw":0.7}
			host.position = Vector3(13, 7, -9)
			host.rotation_order = EULER_ORDER_XYZ
			host.rotation = Vector3(-0.2, angle, 0.3)
			Adapter.apply_source_pose(host, state)
			for muzzle: Vector3 in MUZZLES[kind]:
				var expected := host.position + Basis(Vector3.UP, angle + 0.7) * muzzle
				var actual: Vector3 = host.turret.global_transform * (muzzle - Adapter.PIVOTS[kind])
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
	quit(1 if failures else 0)
