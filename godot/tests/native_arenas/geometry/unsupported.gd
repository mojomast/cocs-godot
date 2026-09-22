extends SceneTree
## This negative fixture must exit 1, in both debug and release builds.
const DM = preload("res://native_arenas/maps/geometry.gd")
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var map := Node3D.new()
	root.add_child(map)
	var body := StaticBody3D.new()
	map.add_child(body)
	var collision := CollisionShape3D.new()
	collision.shape = SphereShape3D.new()
	body.add_child(collision)
	var records := DM.collect(map, "prism-foundry")
	assert(records.is_empty(), "Partial geometry must not escape a rejected shape")
