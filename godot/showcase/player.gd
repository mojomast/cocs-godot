extends CharacterBody3D
## Local exploration only. No session, source input, combat or networking dependency.
signal reset_performed

const EYE_HEIGHT := 1.62
const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.2
const JUMP_SPEED := 6.2
const GRAVITY := 18.0
var camera: Camera3D
var keys: Dictionary = {}
var spawn_position := Vector3(0, 0.08, 15)
var spawn_yaw := 0.0
var controls_enabled := true
var jump_pending := false
var reset_count := 0

func _ready() -> void:
	name = "Explorer"
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(46.0)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	camera = Camera3D.new()
	camera.name = "ExplorationCamera"
	camera.position.y = EYE_HEIGHT
	camera.fov = 76.0
	camera.near = 0.08
	camera.far = 450.0
	add_child(camera)
	camera.make_current()
	reset_to_spawn()

func reset_to_spawn() -> void:
	global_position = spawn_position
	rotation = Vector3(0, spawn_yaw, 0)
	camera.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	clear_controls()
	reset_count += 1
	reset_performed.emit()

func clear_controls() -> void:
	keys.clear()
	jump_pending = false
	velocity.x = 0.0
	velocity.z = 0.0

func release_mouse() -> void:
	clear_controls()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_mouse()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.physical_keycode == KEY_ESCAPE and event.pressed:
			release_mouse()
			return
		if event.physical_keycode == KEY_R and event.pressed and not event.echo:
			reset_to_spawn()
			return
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and controls_enabled:
			keys[event.physical_keycode] = event.pressed
			if event.physical_keycode == KEY_SPACE and event.pressed and not event.echo:
				jump_pending = true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if controls_enabled:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and controls_enabled:
		rotation.y -= event.relative.x * 0.0023
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.0023, -1.45, 1.45)

func _physics_process(delta: float) -> void:
	var axis := Vector2.ZERO
	if controls_enabled:
		axis = Vector2(float(keys.get(KEY_D, false)) - float(keys.get(KEY_A, false)), float(keys.get(KEY_S, false)) - float(keys.get(KEY_W, false))).normalized()
	var direction := global_basis * Vector3(axis.x, 0, axis.y)
	var speed := SPRINT_SPEED if keys.get(KEY_SHIFT, false) else WALK_SPEED
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 32.0)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 32.0)
	if is_on_floor():
		velocity.y = JUMP_SPEED if jump_pending else -0.2
	else:
		velocity.y -= GRAVITY * delta
	jump_pending = false
	move_and_slide()
	if global_position.y < -9.0 or absf(global_position.x) > 65.0 or absf(global_position.z) > 65.0:
		reset_to_spawn()

func _exit_tree() -> void:
	release_mouse()
