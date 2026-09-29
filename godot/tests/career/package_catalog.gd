extends SceneTree
## Exercise the exact release-probe schema against the generated source catalog.
## This is an editor contract check, not extracted-PCK acceptance.
const ReleaseProbe = preload("res://tests/package_inspect.gd")
const NativeProbe = preload("res://native_arenas/package_inspect.gd")

func _initialize() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://career/catalog.json"))
	var slotless := 0
	for item: Dictionary in catalog.items:
		if item.kind in ["finish", "crosshair"] and item.slot.is_empty(): slotless += 1
	if slotless != 11 or not ReleaseProbe.career_catalog_ok() or not NativeProbe.career_catalog_ok():
		push_error("Package probes rejected source gear/cosmetic catalog")
		quit(1)
		return
	print("CAREER_PACKAGE_CATALOG_OK slotless_cosmetics=11")
	quit(0)
