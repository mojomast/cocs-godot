extends Node3D
## Test-only map contract stub. Never used by the production path or smoke.
var builds := 0

func build() -> void:
	builds += 1

func get_arena_id() -> String:
	return "prism-foundry"

func get_spawn_points() -> Array[Vector3]:
	return [Vector3(500, 500, 500)] # Must never become the gameplay camera pose.
