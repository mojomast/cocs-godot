extends CharacterBody3D
## Native-only exploration controller. Never used by authoritative combat scenes.
const WALK_SPEED := 6.0
const SPRINT_SPEED := 10.0
const GRAVITY := 20.0
const JUMP_SPEED := 6.5
const LOOK_GAIN := 0.002
var camera := Camera3D.new()
var spawn_position := Vector3(0, 1, 0)
var spawn_yaw := 0.0
var spawn_pitch := 0.0
var application_focused := true
var jump_latched := false
var reset_count := 0

func _init() -> void:
	name = "Explorer"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	camera.name = "Camera"
	camera.position.y = 1.6
	camera.near = 0.06
	camera.far = 2000.0
	camera.fov = 78.0
	camera.current = true
	add_child(camera)
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(46.0)
	floor_stop_on_slope = true
	safe_margin = 0.02

func set_spawn(value: Vector3, yaw: float = 0.0, pitch: float = 0.0) -> void:
	if not value.is_finite() or not is_finite(yaw) or not is_finite(pitch): return
	spawn_position = value
	spawn_yaw = wrapf(yaw, -PI, PI)
	spawn_pitch = clampf(pitch, -1.45, 1.45)
	reset_to_spawn()

func reset_to_spawn() -> void:
	position = spawn_position
	rotation = Vector3(0, spawn_yaw, 0)
	camera.rotation = Vector3(spawn_pitch, 0, 0)
	velocity = Vector3.ZERO
	reset_count += 1

func controls_active() -> bool:
	return is_inside_tree() and application_focused and get_window().has_focus() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func release_pointer() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	velocity.x = 0
	velocity.z = 0
	jump_latched = Input.is_physical_key_pressed(KEY_SPACE)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		application_focused = false
		release_pointer()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		application_focused = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			release_pointer()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_R and controls_active():
			reset_to_spawn()
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if application_focused and get_window().has_focus():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and controls_active():
		rotation.y = wrapf(rotation.y - event.relative.x * LOOK_GAIN, -PI, PI)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * LOOK_GAIN, -1.45, 1.45)

func step(delta: float, direction: Vector2, sprint: bool = false, jump: bool = false) -> void:
	if not is_finite(delta) or delta <= 0 or not direction.is_finite(): return
	var axes := direction.limit_length(1.0)
	var forward := basis * Vector3(axes.x, 0, -axes.y)
	var speed := SPRINT_SPEED if sprint else WALK_SPEED
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	if is_on_floor():
		velocity.y = JUMP_SPEED if jump else 0.0
	else:
		velocity.y -= GRAVITY * minf(delta, 0.1)
	move_and_slide()
	if not position.is_finite() or position.y < spawn_position.y - 40.0:
		reset_to_spawn()

func _physics_process(delta: float) -> void:
	var active := controls_active()
	var direction := Vector2.ZERO
	var jump_down := Input.is_physical_key_pressed(KEY_SPACE)
	if active:
		direction = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)))
	step(delta, direction, active and Input.is_physical_key_pressed(KEY_SHIFT), active and jump_down and not jump_latched)
	jump_latched = jump_down

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
