extends Node3D
const Basin = preload("res://aurora_basin/map.gd")
const Hud = preload("res://aurora_basin/hud.gd")
var map: Node3D
var walker: CharacterBody3D
var hud: Control
var _smoke := false
var _elapsed := 0.0

func _ready() -> void:
	_smoke = "--smoke" in OS.get_cmdline_user_args()
	get_viewport().msaa_3d = Viewport.MSAA_2X
	map = Basin.new()
	map.name = "Map"
	add_child(map)
	map.build()
	# The lead owns the reusable controller. Resolve it only at runtime so this
	# scene also imports on the baseline before the integration commit exists.
	var walker_path := "res://exploration/walker.gd"
	if not ResourceLoader.exists(walker_path):
		walker_path = "res://tests/aurora_basin/test_walker.gd"
		print("AURORA_CONTROLLER private test fallback (shared integration not present)")
	var walker_script := load(walker_path) as Script
	walker = walker_script.new() as CharacterBody3D
	walker.name = "Walker"
	add_child(walker)
	walker.set_spawn(map.get_spawn(), Basin.SPAWN_YAW, Basin.SPAWN_PITCH)
	walker.camera.fov = 74.0
	walker.camera.near = 0.12
	walker.camera.far = 450.0
	var layer := CanvasLayer.new()
	layer.name = "ExplorationHUD"
	add_child(layer)
	hud = Hud.new()
	hud.map = map
	hud.walker = walker
	layer.add_child(hud)
	if not _smoke: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("AURORA_READY ", JSON.stringify(map.resource_report()))

func _process(delta: float) -> void:
	_elapsed += delta
	if is_instance_valid(walker) and walker.position.y < -8.0: walker.reset_to_spawn()
	if _smoke and _elapsed > 3.0:
		print("AURORA_SMOKE_PASS frames=", Engine.get_frames_drawn())
		get_tree().quit()
