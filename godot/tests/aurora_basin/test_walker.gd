extends CharacterBody3D
## Private baseline-only controller/physics probe. The final scene prefers the
## lead's res://exploration/walker.gd dynamically; this script owns no input map.
var camera: Camera3D
var _spawn := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var test_driving := false
var test_direction := Vector3.ZERO
var travelled := 0.0

func _ready() -> void:
	floor_max_angle = deg_to_rad(45.0)
	floor_snap_length = 0.38
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	camera = Camera3D.new()
	camera.position.y = 1.6
	camera.current = true
	add_child(camera)

func set_spawn(at: Vector3, yaw := 0.0, pitch := 0.0) -> void:
	_spawn = at
	_yaw = yaw
	_pitch = pitch
	reset_to_spawn()

func reset_to_spawn() -> void:
	position = _spawn
	rotation.y = _yaw
	if camera: camera.rotation.x = _pitch
	velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if test_driving: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * 0.0023
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.0023, -1.45, 1.45)
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if event.physical_keycode == KEY_R: reset_to_spawn()
		if event.physical_keycode == KEY_SPACE and is_on_floor(): velocity.y = 6.5

func _physics_process(delta: float) -> void:
	var direction := test_direction
	if not test_driving:
		var input := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		direction = basis * input.normalized()
	var speed := 10.0 if not test_driving and Input.is_physical_key_pressed(KEY_SHIFT) else 6.0
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor(): velocity.y -= 20.0 * delta
	elif velocity.y < 0: velocity.y = 0
	var before := position
	move_and_slide()
	travelled += position.distance_to(before)
