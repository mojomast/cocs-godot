extends SceneTree
const DM = preload("res://native_arenas/maps/geometry.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var output := "res://native_arenas/generated/colliders.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var maps: Array = []
	for id in ["prism-foundry", "aurora-basin", "cinder-array"]:
		var map := load("res://native_arenas/maps/" + id + ".gd").new() as Node3D
		root.add_child(map)
		map.build()
		if map.collider_sources.is_empty():
			push_error("Native DM collider export failed: " + id)
			quit(1)
			return
		var spawns: Array = []
		for p in map.get_authoring_spawns(): spawns.append(DM.vector(p))
		var routes: Array = []
		for route in map.get_dm_routes():
			var points: Array = []
			for p in route.points: points.append(DM.vector(p))
			routes.append({"id": route.id, "points": points})
		maps.append({"id": id, "colliders": map.collider_sources, "spawns": spawns, "routes": routes})
		map.free()
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(maps))
	file.close()
	print("NATIVE_DM_COLLIDERS_EXPORTED ", output)
	quit()
