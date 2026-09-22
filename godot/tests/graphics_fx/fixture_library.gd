extends RefCounted

static func resources() -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/graphics_fx/frames.json"))
	var result := {}
	for key: String in data:
		var frames: Array[Texture2D] = []
		for frame: Dictionary in data[key].frames:
			var image := Image.create_from_data(int(frame.width), int(frame.height), false, Image.FORMAT_RGBA8, Marshalls.base64_to_raw(frame.data))
			frames.append(ImageTexture.create_from_image(image))
		result[key] = {"frames":frames, "fps":data[key].fps}
	return result

static func events() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/graphics_fx/events.json"))
