extends SceneTree

const Session = preload("res://world/session.gd")

class AttachedSession extends Session:
	func _ready() -> void:
		# Exercise the real session input methods, without map/network startup.
		set_process(false)

var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("Window focus: " + description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# A hidden, attached Window has an actual unfocused window state. Keeping
	# application_focused true models the observed delayed application notice;
	# this is a deterministic regression, not OS graphical acceptance itself.
	var window := Window.new()
	window.visible = false
	root.add_child(window)
	var session := AttachedSession.new()
	for node: Node in [session.camera,session.label,session.selector,session.environment,session.sun,session.client,session.presentation,session.pickups,session.combat,session.combat_label]:
		session.add_child(node)
	window.add_child(session)
	session.phase = 3
	session.received_pose = true
	session.presentation.lifecycle.status = "alive"
	session.snapshot_watch.observe()
	session.application_focused = true
	session.yaw = 0.5
	session.pitch = 0.2
	check(session.is_inside_tree() and session.get_window() == window, "real attached window")
	check(not window.has_focus(), "unfocused window precondition")
	check(session.application_focused, "application notification still pending")
	check(not session.can_capture_pointer(), "window focus gates capture before application notice")
	session.update_look(Vector2(40, 8))
	check(is_equal_approx(session.yaw, 0.5) and is_equal_approx(session.pitch, 0.2), "look ignored during notice delay")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	session._unhandled_input(click)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "click cannot capture unfocused attached window")
	session._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not session.can_capture_pointer(), "application focus alone cannot override unfocused window")
	window.free()
	print("PORT_WINDOW_FOCUS checks=", checks, " failures=", failures, " attached_unfocused_window=true synthetic_application_latch=true")
	quit(1 if failures else 0)
