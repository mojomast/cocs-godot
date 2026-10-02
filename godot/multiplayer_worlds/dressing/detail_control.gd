extends OptionButton
## Explicit graphics bridge for hosts with no scenery setting service.
const Binder = preload("res://multiplayer_worlds/dressing/binder.gd")
var _root: WeakRef

func _init() -> void:
	name = "NewMapDressingDetail"
	add_item("Map finish: Off", Binder.Detail.OFF)
	add_item("Map finish: Low", Binder.Detail.LOW)
	add_item("Map finish: Full", Binder.Detail.FULL)
	select(Binder.Detail.FULL)
	item_selected.connect(_apply)

func bind_map(root: Node3D) -> void:
	_root = weakref(root)
	_apply(selected)

func _apply(index: int) -> void:
	if _root == null: return
	var root: Object = _root.get_ref()
	if root != null: Binder.set_root_detail(root, get_item_id(index))
