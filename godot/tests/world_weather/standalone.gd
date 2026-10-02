extends SceneTree
const Lifecycle = preload("res://sports/av_lifecycle.gd")
class Host extends Node3D:
	var world := preload("res://world/viewer.gd").new()
	func _ready() -> void:
		add_child(world)
		world.set_process(false)

func _initialize() -> void:
	call_deferred("run")
	create_timer(30).timeout.connect(func() -> void: push_error("Standalone weather watchdog"); quit(1))

func run() -> void:
	var host := Host.new()
	root.add_child(host)
	var adapter := Lifecycle.new()
	host.add_child(adapter)
	for id: String in ["sunscar-convoy", "ion-speedway", "aurora-stadium"]:
		assert(host.world.load_map(id))
		var original: Environment = host.world.environment.environment
		if is_instance_valid(adapter.service): adapter.service.free()
		adapter.configure(host, host.world.camera, host.world.catalog.resolve_map(id), "puma-race", "ws://127.0.0.1:1")
		adapter.service.apply_settings({"mute":true})
		adapter.begin({"roundRevision":2}, id)
		assert(adapter.service.weather.look.diagnostics().materials > 0)
		assert(host.world.environment.environment == adapter.service.weather.look._owned)
		adapter.service.weather.look.clear()
		assert(host.world.environment.environment == original)
	host.free()
	print("WORLD_WEATHER_STANDALONE_OK worlds=3")
	quit()
