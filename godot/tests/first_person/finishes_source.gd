extends SceneTree
## Public actor fields captured through the real source WebSocket journey.
const Rig = preload("res://first_person/rig.gd")
const Catalog = preload("res://first_person/generated/finishes.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path := ProjectSettings.globalize_path("res://").path_join("../port/native-finishes/evidence/source-journey.json")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source-journey="): path = arg.trim_prefix("--source-journey=")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if report.is_empty(): push_error("Missing source journey"); quit(1); return
	if report.get("actors", []).size() != 3 or report.actors[0].get("finish") != null or report.actors[1].get("finish") != null or report.actors[2].get("finish") != "finish-ion":
		push_error("Unexpected source finish journey")
		quit(1)
		return
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
			var base: Color = slot.base
			var expected: Color = base.srgb_to_linear()
			if not selected.is_empty():
				var linear: Array = Catalog.PALETTES[selected].linear[slot.role]
				expected = Color(linear[0],linear[1],linear[2])
			var material: StandardMaterial3D = slot.material
			if not material.albedo_color.srgb_to_linear().is_equal_approx(expected):
				push_error("Native source palette mismatch stage " + str(index))
				quit(1)
				return
			var base_emission: Color = slot.emission
			var emission_expected: Color = expected if not selected.is_empty() else base_emission.srgb_to_linear()
			if slot.role == "glow" and not material.emission.srgb_to_linear().is_equal_approx(emission_expected):
				push_error("Native source emission mismatch stage " + str(index))
				quit(1)
				return
	print("FIRST_PERSON_SOURCE_FINISH source WS stock -> saved profile only -> rematch ion; native materials match")
	rig.free()
	camera.free()
	quit(0)
