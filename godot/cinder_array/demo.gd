extends Node3D

const Map = preload("res://cinder_array/map.gd")
const Hud = preload("res://cinder_array/hud.gd")
const Walker = preload("res://exploration/walker.gd")

var map: Node3D
var walker: CharacterBody3D
var camera: Camera3D
var hud: CanvasLayer
var smoke_frames := 0

func _ready() -> void:
	map = Map.new()
	add_child(map)
	var spawn: Dictionary = map.get_spawn()
	walker = Walker.new()
	add_child(walker)
	walker.set_spawn(spawn.position, spawn.yaw, spawn.pitch)
	camera = walker.camera
	camera.fov = 76
	camera.far = 320
	camera.current = true
	hud = Hud.new()
	add_child(hud)
	hud.update_location(map.get_location(spawn.position), spawn.position.y)

func _physics_process(_delta: float) -> void:
	if walker != null:
		map.enforce_boundary(walker)
		hud.update_location(map.get_location(walker.position), walker.position.y)
	if "--smoke" in OS.get_cmdline_user_args():
		smoke_frames += 1
		if smoke_frames == 90:
			var diagnostics: Dictionary = map.get_diagnostics()
			diagnostics["walker_attached"] = walker != null
			diagnostics["camera_finite"] = camera.global_transform.is_finite()
			print("CINDER_SMOKE ", JSON.stringify(diagnostics))
			get_tree().quit(0 if diagnostics.built and diagnostics.camera_finite and diagnostics.walker_attached else 1)
