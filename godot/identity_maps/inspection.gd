extends Node3D
## Deliberately an inspection scene, not a substitute combat controller.
const MapBuilder = preload("res://identity_maps/map.gd")
const Style = preload("res://identity_maps/style.gd")
var map: Node3D
var environment: WorldEnvironment
var sun: DirectionalLight3D
var horizon: Node3D
var camera := Camera3D.new()
var caption := Label.new()
var current_map := 0
var current_view := 0

func _ready() -> void:
	add_child(camera)
	camera.current = true
	camera.fov = 72
	camera.far = 180
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(caption)
	caption.position = Vector2(18,18)
	caption.add_theme_font_size_override("font_size",20)
	environment = WorldEnvironment.new()
	add_child(environment)
	sun = DirectionalLight3D.new()
	add_child(sun)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			var index: int = MapBuilder.IDS.find(arg.trim_prefix("--map="))
			if index >= 0: current_map = index
	show_map()

func show_map() -> void:
	if is_instance_valid(map):
		remove_child(map)
		map.queue_free()
	map = MapBuilder.new()
	add_child(map)
	map.build(MapBuilder.IDS[current_map])
	if is_instance_valid(horizon): remove_child(horizon); horizon.queue_free()
	horizon = Node3D.new()
	add_child(horizon)
	Style.configure_environment(MapBuilder.IDS[current_map], environment, sun)
	Style.decorate(MapBuilder.IDS[current_map], map.recipe, horizon, map.materials)
	current_view = 0
	show_view()

func show_view() -> void:
	var view: Dictionary = map.recipe.cameras[current_view]
	camera.position = Vector3(view.at[0],view.at[1],view.at[2])
	camera.look_at(Vector3(view.target[0],view.target[1],view.target[2]))
	caption.text = "PROTOTYPE INSPECTION — NOT A PLAYABLE RELEASE\n%s · %s\nTab: next map   1–5: fixed cameras   Esc: quit" % [map.recipe.name,view.id]

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE: get_tree().quit()
	if event.keycode == KEY_TAB:
		current_map = (current_map + 1) % MapBuilder.IDS.size()
		show_map()
	if event.keycode >= KEY_1 and event.keycode <= KEY_5:
		current_view = event.keycode - KEY_1
		show_view()
