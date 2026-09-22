extends SceneTree
const Renderer = preload("res://objectives/renderer.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var renderer := Renderer.new()
	root.add_child(renderer)
	for row: Dictionary in rows:
		renderer.apply_state(row.state,0)
		print("GUIDANCE_REPLAY ",JSON.stringify({"key":row.key,"model":renderer.hud_model,"hud":renderer.hud_text,"rendered":renderer.rendered}))
	renderer.free()
	quit()
