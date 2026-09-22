extends SceneTree
## External release-runtime probe; never exported into the production PCK.
const MAPS := ["meridian-exchange", "verdant-reliquary", "ember-crucible", "tidal-citadel", "sunscar-convoy", "asterion-relay", "monsoon-foundry", "ion-speedway", "aurora-stadium"]
const SCENES := ["world/session", "sports/demo", "objectives/demo", "lattice/board", "lattice/world_demo", "zone_modes/demo", "combined_arms/demo"]
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
	print("PACKAGE_INSPECT_OK ", JSON.stringify({"maps":MAPS, "scenes":SCENES.size(), "editor":OS.has_feature("editor"), "debug":OS.is_debug_build(), "assertion_ran":assertion_ran, "tests_in_pck":false, "probes_in_pck":false}))
	quit(0)
