extends Node
## Popup-free detail control shared by every native world composition.
var level := 2
var scenery: WeakRef
var label := Label.new()
var remaining := 0.0

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	layer.add_child(label)
	label.position = Vector2(20,68)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.hide()

func bind_scenery(node: Node3D) -> void:
	scenery = weakref(node)
	node.set_detail(level)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		level = (level + 1) % 3
		if scenery != null and scenery.get_ref() != null: scenery.get_ref().set_detail(level)
		label.text = "Moth scenery: %s · F8 cycles detail" % ["Off","Low","Full"][level]
		label.show()
		remaining = 3.0
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	remaining = maxf(0,remaining-delta)
	if remaining == 0: label.hide()
