extends SceneTree
const Demo = preload("res://objectives/demo.gd")
class Transport extends "res://net/client.gd":
	var sent: Array = []
	func send_input(controls: Dictionary) -> Error:
		sent.append(controls.duplicate(true))
		return OK
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var demo := Demo.new()
	demo.client.free()
	var transport := Transport.new()
	demo.client = transport
	root.add_child(demo)
	demo.set_process(false)
	var press := InputEventKey.new()
	press.keycode = KEY_E
	press.physical_keycode = KEY_E
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	check(not demo.controls_released(), "held interaction blocks fresh capture")
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	check(demo.controls_released(), "release permits deliberate capture")
	demo.phase = 3
	demo.received_pose = true
	demo.presentation.lifecycle.apply({"health":100,"dead":0}, false)
	demo.snapshot_watch.observe()
	demo.snapshot_watch.advance(2)
	check(not demo.can_capture_pointer(), "stale cannot capture")
	demo._process(0.02)
	check(not transport.sent.is_empty(), "neutral cadence continues")
	var controls: Dictionary = transport.sent.back()
	check(controls.x == 0 and controls.z == 0 and controls.interact == false and controls.fire == false, "stale controls neutral")
	demo.snapshot_watch.observe()
	demo.presentation.lifecycle.apply({"health":0,"dead":0}, false)
	check(not demo.can_capture_pointer(), "zero health remains dead")
	demo._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not demo.application_focused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "focus loss releases")
	demo._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "focus return no recapture")
	demo.phase = 4
	var count := transport.sent.size()
	demo._process(0.02)
	check(transport.sent.size() == count, "results send no active inputs")
	demo.on_started({})
	check(not demo.received_pose and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "round reset waits for fresh pose and click")
	demo.on_error("Synthetic error")
	check(demo.objectives.markers.is_empty() and demo.phase == -1, "error clears objective and controls")
	demo.free()
	print("OBJECTIVE_CONTROL_TESTS checks=", checks, " failures=", failures, " synthetic=true")
	quit(1 if failures else 0)
