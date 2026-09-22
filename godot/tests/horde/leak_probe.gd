extends SceneTree
const Product = preload("res://horde/demo.tscn")
const Replacement = preload("res://tests/horde/leak_subclass.gd")

func _initialize() -> void:
	call_deferred("probe")

func probe() -> void:
	var legacy := "--replace-script" in OS.get_cmdline_user_args()
	var before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var product := Product.instantiate()
	if legacy: product.set_script(Replacement)
	root.add_child(product)
	await process_frame
	await process_frame
	root.remove_child(product)
	product.free()
	await process_frame
	var after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	print("HORDE_LEAK_PROBE ", JSON.stringify({"root_script_replaced":legacy,"before":before,"after":after,"delta":after-before}))
	quit(1 if after != before else 0)
