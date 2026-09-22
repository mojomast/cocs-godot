extends SceneTree
## External release-runtime probe; never exported into the production PCK.
const MAPS := ["meridian-exchange", "verdant-reliquary", "ember-crucible", "tidal-citadel", "sunscar-convoy", "asterion-relay", "monsoon-foundry", "ion-speedway", "aurora-stadium"]
const SCENES := ["world/session", "sports/demo", "objectives/demo", "lattice/board", "lattice/world_demo", "zone_modes/demo", "combined_arms/demo", "arms_race/demo", "horde/demo"]
var assertion_ran := false

func assertion_witness() -> bool:
	assertion_ran = true
	return true

func fail(message: String) -> void:
	push_error("PACKAGE_INSPECT_FAILED " + message)
	quit(1)

func _initialize() -> void:
	call_deferred("inspect")

func inspect() -> void:
	assert(assertion_witness())
	if OS.has_feature("editor") or OS.is_debug_build() or assertion_ran:
		fail("Expected release runtime with assertions disabled")
		return
	if DirAccess.dir_exists_absolute("res://tests") or DirAccess.dir_exists_absolute("res://content/probes"):
		fail("Test fixtures or GLB probes shipped in production")
		return
	var catalog = load("res://world/catalog.gd").new()
	if not catalog.open() or catalog.entries.keys() != MAPS:
		fail("Nine-map identity catalog mismatch")
		return
	for id: String in MAPS:
		if catalog.resolve_map(id).is_empty():
			fail("Missing/corrupt map " + id)
			return
	for scene: String in SCENES:
		var resource = load("res://" + scene + ".tscn")
		if not resource is PackedScene:
			fail("Missing scene " + scene)
			return
		var script = load("res://" + scene + ".gd")
		if not script is GDScript or not script.can_instantiate():
			fail("Missing compiled script " + scene)
			return
	var moth = load("res://moth/library.gd")
	var manifest: Dictionary = moth.manifest()
	var planes := 0
	for bucket: String in ["textures", "normals", "sky"]:
		for key: String in manifest.get(bucket, {}):
			var method := "texture" if bucket == "textures" else ("normal" if bucket == "normals" else "sky")
			if not moth.call(method, key) is Texture2D:
				fail("Missing Moth resource " + bucket + "/" + key)
				return
			planes += 1
	for key: String in manifest.get("effects", {}):
		var effect: Dictionary = moth.effect(key)
		if effect.is_empty():
			fail("Missing Moth effect " + key)
			return
		planes += effect.frames.size()
	for key: String in manifest.get("materials", {}):
		if moth.material_lut(key).is_empty():
			fail("Missing Moth LUT " + key)
			return
		planes += 2
	if planes != 101:
		fail("Moth resource inventory mismatch")
		return
	for index in range(10):
		if not load("res://first_person/generated/weapon-%d.glb" % index) is PackedScene:
			fail("Missing first-person weapon " + str(index))
			return
	print("PACKAGE_GRAPHICS_OK moth_planes=101 first_person_weapons=10")
	print("PACKAGE_INSPECT_OK ", JSON.stringify({"maps":MAPS, "scenes":SCENES.size(), "editor":OS.has_feature("editor"), "debug":OS.is_debug_build(), "assertion_ran":assertion_ran, "tests_in_pck":false, "probes_in_pck":false}))
	quit(0)
