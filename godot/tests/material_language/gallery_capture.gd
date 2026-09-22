extends SceneTree
## Material-language review capture. Renders the families in SubViewports on
## representative geometry and writes images plus measured A/B numbers.
##
##   godot --path godot --resolution 960x640 --rendering-method gl_compatibility \
##     --script res://tests/material_language/gallery_capture.gd -- \
##     --mode=sheet --size=960x640 --output=/tmp/opencode/out.png
##
## Modes: sheet (8 families), family (one family, three lightings), distance
## (grazing floors for the shimmer check). This is evidence tooling: no gameplay,
## no world mutation, no session.

const Language = preload("res://material_language/library.gd")
const Props = preload("res://material_language/props.gd")
const SheetBuilder = preload("res://material_language/sheet.gd")

var output := "/tmp/opencode/material-language.png"
var mode := "sheet"
var size := Vector2i(1280, 800)
var family := "pearl-ceramic"
var metrics: Dictionary = {}
var ab := true

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--family="): family = arg.trim_prefix("--family=")
		if arg == "--ab=off": ab = false
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
	root.size = size
	root.content_scale_size = size
	# Fixed clock: the captures are evidence, so the accent phase must be the same
	# on every machine and every run.
	Language.set_clock(12.0)
	call_deferred("build")

func label_at(parent: Node, text: String, position: Vector2, font_size: int = 12, color: Color = Color("d4e5ed")) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func build() -> void:
	print("MATERIAL_LANGUAGE_CAPTURE_STAGE mode=%s size=%s phase=build" % [mode, size])
	var background := ColorRect.new()
	background.color = Color("0d151d")
	background.size = Vector2(size)
	root.add_child(background)
	var builder := SheetBuilder.new()
	var result: Dictionary = {}
	match mode:
		"family": result = builder.family_panel(root, size, family)
		"distance": result = builder.distance_panel(root, size)
		_: result = builder.sheet(root, size)
	metrics = result.metrics
	print("MATERIAL_LANGUAGE_CAPTURE_STAGE phase=built tiles=%d" % metrics.get("tiles", []).size())
	for index in 4: await process_frame
	await RenderingServer.frame_post_draw
	print("MATERIAL_LANGUAGE_CAPTURE_STAGE phase=settled")
	var shot := root.get_texture().get_image()
	if shot.get_size() != size:
		push_error("Screenshot resolution differs: %s != %s" % [shot.get_size(), size])
		shot.save_png(output)
		quit(1)
		return
	print("MATERIAL_LANGUAGE_CAPTURE_STAGE phase=screenshot")
	if shot.save_png(output) != OK:
		push_error("Screenshot write failed: " + output)
		quit(1)
		return
	metrics["tiles"] = builder.tile_metrics().tiles
	var coverage := Language.coverage()
	var report := {
		"mode": mode, "size": [size.x, size.y], "output": output,
		"families": Language.families(), "metrics": metrics,
		"cache": Language.cache_stats(), "budget": Language.budget(),
		"coverage": {"counts": coverage.counts, "unused": coverage.unused, "derived_consumers": coverage.derived_keys.size(), "keys": coverage["keys"].size()},
		"ab": await builder.measure_ab(root, size, builder.materials, output.trim_suffix(".png"), ab),
	}
	var file := FileAccess.open(output + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("MATERIAL_LANGUAGE_CAPTURE ", JSON.stringify({"mode": mode, "size": [size.x, size.y], "output": output, "metrics": metrics}))
	quit(0)
