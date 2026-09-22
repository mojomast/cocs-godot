extends "res://native_arenas/demo.gd"
const FixtureClient = preload("res://tests/native_arenas/session/fixture_client.gd")
var missing_renderer := false

func _init() -> void:
	super()
	client.free()
	client = FixtureClient.new()

func _ready() -> void:
	build_composition()
	set_process(false)

func renderer_path(_id: String) -> String:
	return "res://tests/native_arenas/session/not_a_map.gd" if missing_renderer else "res://tests/native_arenas/session/fixture_map.gd"
