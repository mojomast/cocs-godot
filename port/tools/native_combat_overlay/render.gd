extends SceneTree

# Explicit synthetic visual fixture, not a live gameplay recording.
const Overlay = preload("res://world/combat_overlay.gd")

func _initialize() -> void:
	call_deferred("render_preview")

func render_preview() -> void:
	root.size = Vector2i(960, 640)
	var background := ColorRect.new()
	background.color = Color(0.04, 0.08, 0.11)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var heading := Label.new()
	heading.position = Vector2(40, 36)
	heading.text = "NATIVE COMBAT FEEDBACK\nSynthetic visual preview · not gameplay evidence\nReticle + confirmed hit + incoming damage edge pulse"
	root.add_child(heading)
	var overlay := Overlay.new()
	root.add_child(overlay)
	overlay.update_feedback(true, 0.2, 0.35)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): output = arg.trim_prefix("--capture=")
	if output.is_empty():
		quit(2)
		return
	quit(root.get_texture().get_image().save_png(output))
