extends "res://world/viewer.gd"
const WorldCatalog = preload("res://multiplayer_worlds/catalog.gd")
const WorldMap = preload("res://multiplayer_worlds/map.gd")

func _init() -> void:
 catalog = WorldCatalog.new()

func load_map(id: String) -> bool:
 var data: Dictionary = catalog.recipes.get(id,{})
 if data.is_empty():
  label.text = "Unknown authored world " + id
  return false
 var next := WorldMap.new()
 next.name = "SelectedWorld"
 add_child(next)
 if not next.build(data):
  next.queue_free()
  return false
 if is_instance_valid(world):
  remove_child(world)
  world.free()
 world = next
 current_id = id
 var env := Environment.new()
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color("607887")
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color("a8b2b1")
 env.ambient_light_energy = 0.8
 environment.environment = env
 sun.rotation_degrees = Vector3(-45,-24,0)
 sun.light_energy = 1.5
 return true
