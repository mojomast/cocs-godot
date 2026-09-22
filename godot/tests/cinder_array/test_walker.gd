extends CharacterBody3D
## Private integration stand-in. Production demo loads res://exploration/walker.gd.
## Physics dimensions and motion contract match the controller requested by the lead.

var camera: Camera3D
var spawn_position := Vector3.ZERO
var spawn_yaw := 0.0
var spawn_pitch := 0.0
var automatic := false
var wish_direction := Vector3.ZERO
var speed := 6.0

func _ready() -> void:
	name = "CinderTestWalker"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.9
	add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 1.6
	add_child(camera)
	floor_max_angle = deg_to_rad(45)
	floor_snap_length = 0.35
	floor_constant_speed = true
	safe_margin = 0.01

func set_spawn(point: Vector3, yaw: float = 0.0, pitch: float = 0.0) -> void:
	spawn_position = point
	spawn_yaw = yaw
	spawn_pitch = pitch
	reset_to_spawn()

func reset_to_spawn() -> void:
	position = spawn_position
	rotation.y = spawn_yaw
	if camera != null: camera.rotation.x = spawn_pitch
	velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if automatic: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if event.keycode == KEY_R: reset_to_spawn()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * 0.0023
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.0023, -1.4, 1.4)

func _physics_process(delta: float) -> void:
	var direction := wish_direction
	var moving_speed := speed
	if not automatic:
		var input := Vector2.ZERO
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			input = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
			moving_speed = 10 if Input.is_physical_key_pressed(KEY_SHIFT) else 6
			if Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor(): velocity.y = 7.0
		direction = basis * Vector3(input.x, 0, input.y).normalized()
	velocity.x = direction.x * moving_speed
	velocity.z = direction.z * moving_speed
	if not is_on_floor(): velocity.y -= 22.0 * delta
	elif velocity.y < 0: velocity.y = -0.2
	move_and_slide()
