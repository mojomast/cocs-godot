extends Node
## Optional passive adapter for existing native session/mode roots.
## Add this child after the root's _ready, or as a scene child (deferred binding).
const Rig = preload("res://first_person/rig.gd")
var session: Node
var rig := Rig.new()
var _last_phase := -999
var _last_actor := -999
var _last_angles := Vector2.ZERO
var _had_angles := false
var _base_fov := 75.0

func _ready() -> void:
	call_deferred("bind_session", get_parent())

func bind_session(target: Node) -> void:
	if session != null: return
	if target == null or not "camera" in target or not "client" in target or not "presentation" in target: return
	session = target
	_base_fov = session.camera.fov
	add_child(rig)
	rig.attach_to(session.camera)
	session.client.events.connect(_events)
	session.client.started.connect(func(_frame: Dictionary) -> void: clear_round())
	session.client.results.connect(func(_frame: Dictionary) -> void: clear_round())
	session.client.connection_error.connect(func(_message: String) -> void: clear_round())
	refresh()

func refresh() -> void:
	if not is_instance_valid(session): return
	var phase: int = session.phase
	var id: int = session.client.actor_id
	if phase != _last_phase or id != _last_actor:
		clear_round()
		_last_phase = phase
		_last_actor = id
	# Existing session owns focus, capture, snapshot freshness and lifecycle policy.
	var allowed: bool = phase == 3 and id >= 0 and Rig.identity(session.presentation.local_actor.get("id")) == id and session.client.peer.get_ready_state() == WebSocketPeer.STATE_OPEN and not session.client.spectating and session.received_pose and session.application_focused and not session.snapshot_watch.stale() and session.presentation.lifecycle.can_control()
	if allowed and session.has_method("can_capture_pointer"):
		allowed = session.can_capture_pointer()
	allowed = allowed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	rig.apply_actor(session.presentation.local_actor, allowed)
	var aiming := false
	if allowed:
		if session.has_method("aim_requested"):
			aiming = session.aim_requested() == true
		elif session.has_method("weapon_aim_active"):
			aiming = session.weapon_aim_active() == true
		elif "aiming" in session:
			aiming = session.aiming == true
		else:
			aiming = session.presentation.local_actor.get("aiming", session.presentation.local_actor.get("ads", false)) == true
	rig.apply_aim(aiming)
	session.camera.fov = float(rig.get_aim_state(_base_fov).fov)
	var angles := Vector2(session.camera.rotation.y, session.camera.rotation.x)
	if allowed and _had_angles:
		rig.apply_look_delta(Vector2(wrapf(angles.x - _last_angles.x, -PI, PI), angles.y - _last_angles.y))
	_last_angles = angles
	_had_angles = allowed

func _events(items: Array) -> void:
	refresh() # Consume events even when the current frame is hidden/stale/unfocused.
	rig.apply_events(items, session.client.actor_id)

func _process(_delta: float) -> void:
	refresh()

func clear_round() -> void:
	rig.reset()
	if is_instance_valid(session) and is_instance_valid(session.camera):
		session.camera.fov = _base_fov
	_had_angles = false

func get_aim_state(base_fov: float = 75.0) -> Dictionary:
	return rig.get_aim_state(base_fov)

func get_muzzle_count() -> int:
	return rig.get_muzzle_count()

func get_muzzle_world_transform(index: int = 0) -> Transform3D:
	return rig.get_muzzle_world_transform(index)

func get_muzzle_screen_position(index: int = 0) -> Vector2:
	return rig.get_muzzle_screen_position(index)
