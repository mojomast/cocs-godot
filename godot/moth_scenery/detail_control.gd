extends OptionButton
## Optional visible settings control. Add to the viewer's existing UI container,
## then bind_scenery() after each create(). Choice survives map switches.
const Scenery = preload("res://moth_scenery/scenery.gd")
var _scenery: WeakRef

func _init() -> void:
	name = "MothSceneryDetail"
	add_item("Scenery detail: Off", Scenery.Detail.OFF)
	add_item("Scenery detail: Low", Scenery.Detail.LOW)
	add_item("Scenery detail: Full", Scenery.Detail.FULL)
	select(Scenery.Detail.FULL)
	tooltip_text = "Full: mounted panels, trims and local ambient motes.\nLow: essential mounted accents. Off: release all scenery geometry."
	item_selected.connect(_apply)

func bind_scenery(scenery: Node3D) -> void:
	_scenery = weakref(scenery)
	_apply(selected)

func _apply(index: int) -> void:
	if _scenery == null: return
	var scenery: Object = _scenery.get_ref()
	if scenery != null: scenery.set_detail(get_item_id(index))
