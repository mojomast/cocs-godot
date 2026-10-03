extends SceneTree
const Pack = preload("res://biomes/expansion/scenery_pack.gd")
class Host extends Node3D:
	var recipe: Dictionary
func _initialize() -> void:
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Pack.CATALOG))
	for id: String in catalog.chapters:
		var host := Host.new()
		host.recipe=JSON.parse_string(FileAccess.get_file_as_string("res://campaign/generated/"+id+".json"))
		var pack := Pack.new()
		assert(not pack.build(host,false))
		assert(pack.last_build.status=="fallback" and pack.last_build.code=="missing_import")
		assert(pack.loaded_assets.is_empty() and pack.get_child_count()==0)
		print("ACTUAL_ABSENT_FALLBACK ",id," ",JSON.stringify(pack.last_build))
		pack.free();host.free()
	quit()
