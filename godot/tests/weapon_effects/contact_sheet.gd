extends SceneTree
## Assemble real rendered PNGs using Godot's image loader; no extra dependencies.
func _initialize() -> void:
	var directory := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-out="): directory = arg.trim_prefix("--evidence-out=")
	if directory.is_empty(): quit(1); return
	for size: String in ["960x640","1280x800"]:
		for pose: String in ["hip","ads-stub"]:
			var sheet := Image.create(960,1600,false,Image.FORMAT_RGBA8)
			sheet.fill(Color("0b1118"))
			for weapon: int in 10:
				var image := Image.load_from_file(directory.path_join("%s-%02d-%s.png" % [size,weapon,pose]))
				image.convert(Image.FORMAT_RGBA8)
				image.resize(480,320,Image.INTERPOLATE_LANCZOS)
				sheet.blit_rect(image,Rect2i(0,0,480,320),Vector2i((weapon%2)*480,(weapon/2)*320))
			sheet.save_png(directory.path_join("contact-%s-%s.png" % [size,pose]))
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("metrics.json")))
	var summary := {"framing_records":0,"maximum_visual_tip_projection_error_px":0.0,"maximum_tracer_start_error_px":0.0,"maximum_authoritative_endpoint_delta_m":0.0,"source_replays":[],"near_wall":[]}
	for record: Dictionary in records:
		if record.has("tracer_start_error_px"):
			summary.framing_records += 1
			summary.maximum_visual_tip_projection_error_px = maxf(summary.maximum_visual_tip_projection_error_px,record.visual_tip_projection_error_px)
			summary.maximum_tracer_start_error_px = maxf(summary.maximum_tracer_start_error_px,record.tracer_start_error_px)
			summary.maximum_authoritative_endpoint_delta_m = maxf(summary.maximum_authoritative_endpoint_delta_m,record.authoritative_endpoint_delta_m)
		if record.has("source_weapon"): summary.source_replays.append(record)
		if record.get("fixture") == "near-wall-semantic": summary.near_wall.append(record)
	FileAccess.open(directory.path_join("summary.json"),FileAccess.WRITE).store_string(JSON.stringify(summary,"\t")+"\n")
	print(JSON.stringify(summary))
	quit()
