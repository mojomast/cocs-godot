extends SceneTree
const Structures = preload("res://campaign/structure_art.gd")
func _initialize() -> void:
	var instance: Node3D = load("res://campaign/art/structures/receiver-shaft-0.glb").instantiate()
	var parts: Array = []
	var collector := Structures.new()
	collector._collect_meshes(instance,Transform3D.IDENTITY,parts)
	var data: Array = []
	for part: Dictionary in parts:
		var faces: PackedVector3Array = part.transform * part.mesh.get_faces()
		for point: Vector3 in faces: data.append([point.x,point.y,point.z])
	var file := FileAccess.open(OS.get_environment("EDGE_IMPORTED"),FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	instance.free()
	collector.free()
	quit()
