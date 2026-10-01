extends "res://campaign/demo.gd"
## Rendering-only authority replay. No sockets, wall-clock interpolation or input.
func _process(_delta: float) -> void:
 pass

func render_local_translation(_now: float) -> void:
 pass

func apply_local_snapshot_pose(eye: Vector3, _now: float, _reseeded: bool) -> void:
 camera.position = eye
