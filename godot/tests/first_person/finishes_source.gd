extends SceneTree
## Public actor fields captured through the real source WebSocket journey.
const Rig = preload("res://first_person/rig.gd")
const Catalog = preload("res://first_person/generated/finishes.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path := ProjectSettings.globalize_path("res://").path_join("../port/native-finishes/evidence/source-journey.json")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if report.is_empty(): push_error("Missing source journey"); quit(1); return
	var camera := Camera3D.new()
	root.add_child(camera)
	var rig := Rig.new()
	root.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	var frames: Array = report.actors
	for index: int in frames.size():
		rig.apply_actor(frames[index], true)
		var selected := "finish-ion" if index == 2 else ""
		if rig.finish.active != selected:
			push_error("Native rig disagrees with source actor finish at stage " + str(index))
			quit(1)
			return
		for slot: Dictionary in rig.finish.slots:
			var expected: Color = slot.base
			if not selected.is_empty():
				var linear: Array = Catalog.PALETTES[selected].linear[slot.role]
				expected = Color(linear[0],linear[1],linear[2])
			if not (slot.material as StandardMaterial3D).albedo_color.is_equal_approx(expected):
				push_error("Native source palette mismatch stage " + str(index))
				quit(1)
				return
	print("FIRST_PERSON_SOURCE_FINISH source WS stock -> saved profile only -> rematch ion; native materials match")
	rig.free()
	camera.free()
	quit(0)
