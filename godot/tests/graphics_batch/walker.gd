extends SceneTree
const Walker = preload("res://exploration/walker.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("EXPLORATION_WALKER: " + label)

func box(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var mesh := BoxShape3D.new()
	mesh.size = size
	shape.shape = mesh
	body.add_child(shape)
	body.position = at
	parent.add_child(body)

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var world := Node3D.new()
	root.add_child(world)
	box(world, Vector3(0,-0.5,0), Vector3(30,1,30))
	box(world, Vector3(0,2,-4), Vector3(8,4,0.5))
	var walker := Walker.new()
	world.add_child(walker)
	walker.set_physics_process(false)
	walker.set_spawn(Vector3(0,0.1,0))
	for frame in range(30):
		await physics_frame
		walker.step(1.0/60.0, Vector2.ZERO)
	check(walker.is_on_floor(), "capsule settles on native ground")
	var start: Vector3 = walker.position
	for frame in range(80):
		await physics_frame
		walker.step(1.0/60.0, Vector2(0,1))
	check(walker.position.z < start.z - 2, "native forward movement")
	check(walker.position.z > -3.5, "solid wall collision")
	walker.reset_to_spawn()
	for frame in range(10):
		await physics_frame
		walker.step(1.0/60.0, Vector2.ZERO)
	await physics_frame
	walker.step(1.0/60.0, Vector2.ZERO, false, true)
	for frame in range(10):
		await physics_frame
		walker.step(1.0/60.0, Vector2.ZERO)
	check(walker.position.y > 0.5, "grounded jump")
	walker.position.y = -50
	await physics_frame
	walker.step(1.0/60.0, Vector2.ZERO)
	check(walker.position == walker.spawn_position, "fall reset")
	walker.velocity = Vector3(4,0,3)
	walker._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not walker.controls_active() and walker.velocity.x == 0 and walker.velocity.z == 0, "focus clears movement and capture")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "pointer released")
	walker.set_spawn(Vector3(1,2,3), TAU+0.5, 9)
	check(is_equal_approx(walker.rotation.y,0.5) and is_equal_approx(walker.camera.rotation.x,1.45), "finite clamped spawn look")
	walker.set_spawn(Vector3(NAN,0,0))
	check(walker.position.is_finite(), "malformed spawn ignored")
	world.queue_free()
	await process_frame
	print("EXPLORATION_WALKER_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"native_physics":true}))
	quit(1 if failures else 0)
