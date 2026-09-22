extends "res://world/session.gd"
## Lightweight session host for the debug-panel contract test. It deliberately
## does not connect, load a map or run the ordinary _ready composition; the test
## drives on_lobby/on_started/on_snapshot with synthetic public frames.
const FixtureClient = preload("res://tests/debug/fixture_client.gd")

func _init() -> void:
	client.free()
	client = FixtureClient.new()

func _ready() -> void:
	for node: Node in [camera, label, selector, client, presentation, pickups, combat, combat_label, sun, environment]:
		add_child(node)
	for control: Control in [label, selector, combat_label]:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	client.set_process(false)
	presentation.set_process(false)
