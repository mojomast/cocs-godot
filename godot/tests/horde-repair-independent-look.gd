extends SceneTree
## Exercise the exact product update_look method extracted from supplied source
## bytes. Only the capture predicate is stubbed; neither look body is rewritten.

func _initialize() -> void:
	var file := "res://horde/demo.gd"
	var vectors_file := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--demo-source="): file = arg.trim_prefix("--demo-source=")
		if arg.begins_with("--vectors="): vectors_file = arg.trim_prefix("--vectors=")
	var source := FileAccess.get_file_as_string(file)
	var start := source.find("func update_look(")
	var end := source.find("\nfunc ", start + 1)
	assert(start >= 0 and end > start)
	var script := GDScript.new()
	script.source_code = "extends RefCounted\nconst ControlMath = preload(\"res://world/control_math.gd\")\nconst Controls = preload(\"res://horde/controls.gd\")\nconst LOOK_GAIN := 0.002\nvar controls = Controls.new()\nvar yaw := 0.7\nvar pitch := 0.2\nfunc can_capture_pointer() -> bool:\n\treturn true\n" + source.substr(start, end-start)
	assert(script.reload() == OK)
	var subject: RefCounted = script.new()
	var vectors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(vectors_file))
	var failures := 0
	for case: Dictionary in vectors.lookCases:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = case.ads
		subject.controls.record(event, true)
		subject.yaw = case.yaw
		subject.pitch = case.pitch
		subject.update_look(Vector2(case.x, case.y))
		var actual := Vector2(subject.yaw, subject.pitch)
		var ok := actual.is_equal_approx(Vector2(case.expected[0], case.expected[1]))
		print("HORDE_PRODUCT_LOOK ", JSON.stringify({"source":file,"ads":case.ads,"actual":[actual.x,actual.y],"expected":case.expected,"ok":ok}))
		if not ok: failures += 1
	print("HORDE_PRODUCT_LOOK_CHECKS checks=", vectors.lookCases.size(), " failures=", failures)
	quit(1 if failures else 0)
