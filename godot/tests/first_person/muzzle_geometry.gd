extends SceneTree
## The imported barrel stations, not a camera-space placeholder, define the
## muzzle's physical position and orientation through pose changes.
const Rig = preload("res://first_person/rig.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func step(rig: Node, frames: int) -> void:
	for frame: int in frames: rig.advance(1.0 / 60.0)

func measure(rig: Node, camera: Camera3D, label: String) -> void:
	var view_to_world: Transform3D = camera.get_camera_transform() * rig.weapon_camera.get_camera_transform().affine_inverse()
	for index: int in rig.get_muzzle_count():
		var tip: Node3D = rig.anchors["Muzzle%d" % index]
		var world_tip: Transform3D = rig.get_muzzle_world_transform(index)
		var expected: Transform3D = view_to_world * tip.global_transform
		var pixel: Vector2 = rig.get_muzzle_screen_position(index)
		var context := "%s barrel %d" % [label, index]
		check(world_tip.is_finite(), context + " finite world transform")
		check(world_tip.origin.distance_to(expected.origin) < 0.00001, context + " follows authored station")
		check((-world_tip.basis.z).angle_to(-expected.basis.z) < 0.0001, context + " preserves barrel orientation")
		check(camera.unproject_position(world_tip.origin).distance_to(pixel) < 0.05, context + " projects onto visible muzzle")
		# A point ahead of the real barrel must project along the transformed
		# barrel axis as well; an origin-only camera-space fake cannot pass.
		var ahead := world_tip * Vector3(0, 0, -0.1)
		var visual_ahead: Vector3 = tip.global_transform * Vector3(0, 0, -0.1)
		check(camera.unproject_position(ahead).distance_to(rig.weapon_camera.unproject_position(visual_ahead)) < 0.05,
			context + " barrel axis projects into the same pixels")

func run() -> void:
	root.size = Vector2i(1280, 800)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(13, 2, -8)
	camera.rotation = Vector3(-0.13, 0.34, 0.02)
	camera.h_offset = 0.025
	camera.v_offset = -0.018
	world.add_child(camera)
	camera.current = true
	var rig := Rig.new()
	root.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	rig.reduced_motion = true
	var actor := {"id":7, "health":100, "weapon":0}
	for weapon: int in 10:
		actor.weapon = weapon
		rig.apply_actor(actor, true)
		step(rig, 12)
		measure(rig, camera, "weapon %d hip" % weapon)
		var hip_target := camera.project_position(Vector2(root.size) * 0.5, 35.0)
		for index: int in rig.get_muzzle_count():
			var hip_barrel: Transform3D = rig.get_muzzle_world_transform(index)
			check((-hip_barrel.basis.z).angle_to((hip_target - hip_barrel.origin).normalized()) < deg_to_rad(8.0),
				"weapon %d hip barrel %d points toward distant crosshair" % [weapon, index])
		rig.apply_aim(true)
		step(rig, 120)
		check(rig.get_aim_state().ready, "weapon %d settled ADS" % weapon)
		measure(rig, camera, "weapon %d ADS" % weapon)
		# The authoritative eye ray and the physical muzzle need not coincide
		# nearby, but must converge toward the same distant crosshair target.
		var target := camera.project_position(Vector2(root.size) * 0.5, 35.0)
		for index: int in rig.get_muzzle_count():
			var muzzle: Transform3D = rig.get_muzzle_world_transform(index)
			var toward_target := (target - muzzle.origin).normalized()
			check((-muzzle.basis.z).angle_to(toward_target) < deg_to_rad(8.0),
				"weapon %d ADS barrel %d aims toward distant crosshair" % [weapon, index])
		var old: Transform3D = rig.get_muzzle_world_transform()
		rig.apply_events([{"type":"shot", "id":weapon + 1, "time":float(weapon + 1), "actor":7, "weapon":weapon}], 7)
		step(rig, 1)
		measure(rig, camera, "weapon %d recoil" % weapon)
		check(old.origin.distance_to(rig.get_muzzle_world_transform().origin) > 0.00001,
			"weapon %d recoil moves physical muzzle" % weapon)
		step(rig, 100)
		measure(rig, camera, "weapon %d recovered" % weapon)
	# The break-action muzzle must move with its own hinge, beyond pivot recoil.
	actor.weapon = 3
	rig.apply_actor(actor, true)
	step(rig, 12)
	var closed: Transform3D = rig.pivot.global_transform.affine_inverse() * rig.anchors.Muzzle0.global_transform
	actor.reloading = true
	actor.reloadDuration = 2.0
	actor.reloadTimer = 1.0
	rig.apply_actor(actor, true)
	step(rig, 12)
	var opened: Transform3D = rig.pivot.global_transform.affine_inverse() * rig.anchors.Muzzle0.global_transform
	check(closed.origin.distance_to(opened.origin) > 0.001 or (-closed.basis.z).angle_to(-opened.basis.z) > 0.05,
		"scattergun barrel station articulates relative to the receiver")
	measure(rig, camera, "scattergun open action")
	rig.reset()
	check(rig.get_muzzle_count() == 0 and rig.get_muzzle_world_transform() == Transform3D.IDENTITY,
		"hidden rig exposes no stale muzzle")
	rig.free()
	world.free()
	print("FIRST_PERSON_MUZZLE_GEOMETRY ", JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
