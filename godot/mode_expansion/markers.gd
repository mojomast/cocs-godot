extends Node3D
var labels: Dictionary = {}

func clear_round() -> void:
	for item: Label3D in labels.values(): item.queue_free()
	labels.clear()

func apply(markers: Array[Dictionary]) -> void:
	var present: Array[String] = []
	for entry: Dictionary in markers:
		var id: String = entry.id
		present.append(id)
		if not labels.has(id):
			var label := Label3D.new()
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.font_size = 40
			label.outline_size = 8
			label.pixel_size = 0.012
			label.no_depth_test = true
			add_child(label)
			labels[id] = label
		var item: Label3D = labels[id]
		item.position = Vector3(float(entry.x), float(entry.y), float(entry.z))
		item.text = entry.label
		item.modulate = entry.color
	for id: String in labels.keys():
		if id not in present:
			labels[id].queue_free()
			labels.erase(id)
