extends SceneTree

# Numerical image support only; distinct pixels are not an art-parity metric.
func _initialize() -> void:
	var directory := OS.get_cmdline_user_args()[0]
	var report := {}
	for viewer in ["historical", "current"]:
		var before := Image.load_from_file(directory.path_join(viewer + "-before.png"))
		var after := Image.load_from_file(directory.path_join(viewer + "-after.png"))
		assert(before != null and after != null and before.get_size() == after.get_size())
		var changed := 0
		var counts_before := {}
		var counts_after := {}
		var total := 0
		# Exclude the fixed viewer UI; record the whole remaining raster.
		for y in range(120, before.get_height()):
			for x in before.get_width():
				var a := before.get_pixel(x, y).to_rgba32()
				var b := after.get_pixel(x, y).to_rgba32()
				counts_before[a] = counts_before.get(a, 0) + 1
				counts_after[b] = counts_after.get(b, 0) + 1
				if a != b: changed += 1
				total += 1
		report[viewer] = {"pixels_below_ui": total, "changed_pixels": changed,
			"unique_colors_before": counts_before.size(), "unique_colors_after": counts_after.size(),
			"dominant_color_pixels_before": counts_before.values().max(),
			"dominant_color_pixels_after": counts_after.values().max()}
	assert(report.historical.unique_colors_after > report.historical.unique_colors_before)
	print(JSON.stringify(report, "  "))
	var file := FileAccess.open(directory.path_join("image-analysis.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	quit(0)
