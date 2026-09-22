extends SceneTree
## Isolate physical-key release timing used by the live result observer.
func _initialize() -> void:
	call_deferred("check")

func event(pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.keycode = KEY_E
	key.pressed = pressed
	Input.parse_input_event(key)

func check() -> void:
	event(true)
	await process_frame
	await process_frame
	if not Input.is_physical_key_pressed(KEY_E):
		push_error("Ordinary parsed E did not become physically held")
		quit(1)
		return
	event(false)
	var immediate := Input.is_physical_key_pressed(KEY_E)
	await process_frame
	await process_frame
	var settled := Input.is_physical_key_pressed(KEY_E)
	print("COMPLETION_INPUT_TIMING ", JSON.stringify({"synthetic":true,"held_immediately_after_release_event":immediate,"held_after_two_frames":settled}))
	quit(1 if settled else 0)
