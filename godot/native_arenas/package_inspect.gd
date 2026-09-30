extends SceneTree
## Packaged resource probe for the route/package lane.
## Runs from the exported cocs.pck with no project directory and fails if the
## source-operator composition or any identity-map JSON/builder is missing.
const NativeCatalog = preload("res://native_arenas/catalog.gd")
const IDENTITY_IDS := ["lacuna-court", "vermilion-fold", "nacre-engine", "canopy-divide", "basalt-reach"]
const OPERATOR_IDS := ["chatgpt", "claude", "grok", "meta", "gemini", "deepseek", "mistral", "kimi", "qwen"]

func _initialize() -> void:
	call_deferred("inspect")

func fail(message: String) -> void:
	push_error("NATIVE_IDENTITY_PACKAGE_FAILED " + message)
	quit(1)

# Source-derived Career catalog shape (see godot/career/service.gd valid_catalog)
# plus the known gear/attachment families.
static func career_catalog_ok() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://career/catalog.json"))
	if not parsed is Dictionary or parsed.get("schema") != 1:
		return false
	var sources: Variant = parsed.get("sources")
	if not sources is Dictionary or sources.size() < 4:
		return false
	for key: String in sources:
		var value: Variant = sources[key]
		if not value is String or value.length() != 64:
			return false
	var slots: Variant = parsed.get("slots")
	if not slots is Dictionary or not slots.get("gear") is Array or not slots.get("attachment") is Array:
		return false
	var items: Variant = parsed.get("items")
	if not items is Array or items.size() < 1 or items.size() > 128:
		return false
	var kinds := {"gear": 0, "attachment": 0}
	var ids := {}
	for entry: Variant in items:
		if not entry is Dictionary:
			return false
		if entry.get("kind") not in ["gear", "attachment", "finish", "crosshair"]:
			return false
		for field: String in ["id", "unlockId", "name", "description"]:
			if not entry.get(field) is String or (entry[field] as String).is_empty():
				return false
		if not entry.get("slot") is String:
			return false
		if entry.kind in ["gear", "attachment"] and entry.slot.is_empty():
			return false
		if not entry.get("level") is int and not entry.get("level") is float:
			return false
		if not entry.get("modifiers") is Dictionary or not entry.get("spec") is Array:
			return false
		if not entry.get("weapons") is Array or not entry.get("weaponNames") is Array:
			return false
		var key: String = str(entry.kind) + ":" + str(entry.id)
		if ids.has(key):
			return false
		ids[key] = true
		if kinds.has(entry.kind):
			kinds[entry.kind] = int(kinds[entry.kind]) + 1
	return int(kinds["gear"]) >= 23 and int(kinds["attachment"]) >= 22

func inspect() -> void:
	# Source-operator composition (the released presentation default).
	if not load("res://world/presentation.gd") is GDScript:
		fail("world/presentation.gd did not compile")
		return
	var visual: Variant = load("res://source_operators/operator_visual.gd")
	if not visual is GDScript or not visual.can_instantiate():
		fail("source operator visual missing")
		return
	var catalog_script: Variant = load("res://source_operators/generated/catalog.gd")
	if not catalog_script is GDScript:
		fail("source operator catalog missing")
		return
	var operators: Dictionary = catalog_script.get_script_constant_map().get("OPERATORS", {})
	if operators.size() < OPERATOR_IDS.size():
		fail("source operator catalog incomplete: " + str(operators.size()))
		return
	var glbs := 0
	for id: String in OPERATOR_IDS:
		if not load("res://source_operators/generated/" + id + ".glb") is PackedScene:
			fail("source operator model missing: " + id)
			return
		glbs += 1
	print("SOURCE_OPERATOR_PACKAGE_OK ", JSON.stringify({"operators":operators.size(), "glbs":glbs}))
	# Identity-map Deathmatch assets.
	var script: Variant = load("res://identity_maps/map.gd")
	if not script is GDScript or not script.can_instantiate():
		fail("identity builder missing")
		return
	var native_catalog: Variant = NativeCatalog.new()
	if not native_catalog.open_dm():
		fail("catalog: " + str(native_catalog.error))
		return
	if native_catalog.entries.size() != 8:
		fail("roster size " + str(native_catalog.entries.size()))
		return
	var hashes := {}
	for id: String in IDENTITY_IDS:
		var renderer: Variant = load(NativeCatalog.RENDERERS[id])
		if not renderer is GDScript or not renderer.can_instantiate():
			fail("map renderer missing: " + id)
			return
		var data: Dictionary = native_catalog.resolve_envelope(id)
		if data.is_empty():
			fail(id + ": " + str(native_catalog.error))
			return
		hashes[id] = data.geometryHash
	print("NATIVE_IDENTITY_PACKAGE_OK ", JSON.stringify({
		"maps":IDENTITY_IDS, "entries":native_catalog.entries.size(), "hashes":hashes}))
	# Cinderwake Horde map recipe and the Nacre identity-horde scene.
	var horde_script: Variant = load("res://horde_maps/catalog.gd")
	if not horde_script is GDScript:
		fail("Horde map catalog script missing")
		return
	var horde_catalog: Variant = horde_script.new()
	if not horde_catalog.open() or not horde_catalog.entries.has("cinderwake-drydock"):
		fail("Horde map catalog failed: " + str(horde_catalog.error))
		return
	if not load("res://native_arenas/identity_horde_demo.tscn") is PackedScene:
		fail("Nacre identity-horde scene missing")
		return
	print("NATIVE_HORDE_PACKAGE_OK ", JSON.stringify({"maps":horde_catalog.entries.keys()}))
	# Career catalog shape (source-derived, read at runtime by the Career autoload).
	if not career_catalog_ok():
		fail("Career catalog shape mismatch")
		return
	print("CAREER_PACKAGE_OK ")
	# Autoload scripts must resolve and compile from the exported PCK.
	for path: String in ["res://debug/diagnostics.gd", "res://ui/local_settings.gd", "res://career/service.gd"]:
		var autoload_script: Variant = load(path)
		if not autoload_script is GDScript or not autoload_script.can_instantiate():
			fail("Autoload resource missing: " + path)
			return
	print("AUTOLOAD_PACKAGE_OK ")
	quit(0)
