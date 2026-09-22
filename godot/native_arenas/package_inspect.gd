extends SceneTree
## Packaged resource probe for the route/package lane.
## Runs from the exported cocs.pck with no project directory and fails if the
## source-operator composition or any identity-map JSON/builder is missing.
const NativeCatalog = preload("res://native_arenas/catalog.gd")
const IDENTITY_IDS := ["lacuna-court", "vermilion-fold", "nacre-engine"]
const OPERATOR_IDS := ["chatgpt", "claude", "grok", "meta", "gemini", "deepseek", "mistral", "kimi", "qwen"]

func _initialize() -> void:
	call_deferred("inspect")

func fail(message: String) -> void:
	push_error("NATIVE_IDENTITY_PACKAGE_FAILED " + message)
	quit(1)

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
	if native_catalog.entries.size() != 6:
		fail("roster size " + str(native_catalog.entries.size()))
		return
	var hashes := {}
	for id: String in IDENTITY_IDS:
		var data: Dictionary = native_catalog.resolve_envelope(id)
		if data.is_empty():
			fail(id + ": " + str(native_catalog.error))
			return
		hashes[id] = data.geometryHash
	print("NATIVE_IDENTITY_PACKAGE_OK ", JSON.stringify({
		"maps":IDENTITY_IDS, "entries":native_catalog.entries.size(), "hashes":hashes}))
	quit(0)
