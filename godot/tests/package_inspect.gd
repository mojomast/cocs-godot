extends SceneTree
## External release-runtime probe; never exported into the production PCK.
const MAPS := ["meridian-exchange", "verdant-reliquary", "ember-crucible", "tidal-citadel", "sunscar-convoy", "asterion-relay", "monsoon-foundry", "ion-speedway", "aurora-stadium"]
const SCENES := ["world/session", "sports/demo", "objectives/demo", "assault/demo", "lattice/board", "lattice/world_demo", "zone_modes/demo", "combined_arms/demo", "arms_race/demo", "horde/demo", "horde_maps/demo", "native_arenas/demo", "native_arenas/identity_horde_demo"]
const NATIVE_SCENES := ["showcase/demo", "aurora_basin/demo", "cinder_array/demo", "particle_lab/demo", "shader_lab/demo"]
var assertion_ran := false

func assertion_witness() -> bool:
	assertion_ran = true
	return true

# Source-derived Career catalog shape. Mirrors career/service.gd valid_catalog
# plus the known gear/attachment families so a truncated or missing PCK entry
# cannot pass as a shipped Arsenal.
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
		# Source finishes/reticles intentionally have no equipment slot.
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

func fail(message: String) -> void:
	push_error("PACKAGE_INSPECT_FAILED " + message)
	quit(1)

func audio_inventory() -> Dictionary:
	var counts := {"music_samples": 0, "announcer_takes": 0, "announcer_phrases": 0, "moth_beds": 0}
	var music: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://audio/music/manifest.json"))
	var speech: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://audio/announcer/manifest.json"))
	var moth: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://audio/moth/manifest.json"))
	if not music is Dictionary or not music.get("samples") is Array or not speech is Dictionary or not speech.get("clips") is Array or not moth is Dictionary:
		return {}
	var ids := {}
	for sample: Variant in music.samples:
		if not sample is Dictionary or not sample.get("file") is String or not sample.get("id") is String: return {}
		if ids.has(sample.id) or not sample.get("sha256") is String or sample.sha256.length() != 64: return {}
		ids[sample.id] = true
		var stream: Variant = load("res://audio/music/" + sample.file)
		if not stream is AudioStreamOggVorbis or stream.get_length() <= 0: return {}
		if sample.get("loopStart") != null and sample.get("loopEnd") != null:
			if float(sample.loopStart) < 0 or float(sample.loopEnd) <= float(sample.loopStart) or float(sample.loopEnd) > stream.get_length() + 0.05: return {}
		counts.music_samples += 1
	var phrases := {}
	var takes := {}
	for clip: Variant in speech.clips:
		if not clip is Dictionary or not clip.get("file") is String or not clip.get("cue") is String: return {}
		if takes.has(clip.file) or not clip.get("sha256") is String or clip.sha256.length() != 64: return {}
		takes[clip.file] = true
		phrases[clip.cue] = true
		var stream: Variant = load("res://audio/announcer/" + clip.file)
		if not stream is AudioStreamWAV or stream.get_length() <= 0: return {}
		counts.announcer_takes += 1
	counts.announcer_phrases = phrases.size()
	if not moth.get("file") is String or moth.get("sha256") != "d518d47b8f4e1722d47a5a5261921edb8d9063bbe6645adc71e54f5509dc829e": return {}
	var bed: Variant = load("res://audio/moth/" + moth.file)
	if not bed is AudioStreamWAV or bed.get_length() < 10.5: return {}
	counts.moth_beds = 1
	if counts.music_samples != 37 or counts.announcer_takes != 36 or counts.announcer_phrases != 12: return {}
	return counts

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
	for scene: String in NATIVE_SCENES:
		if not load("res://" + scene + ".tscn") is PackedScene:
			fail("Missing native scene " + scene)
			return
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
	var derived: Dictionary = moth.derived_manifest()
	if derived.get("version") != 1 or derived.get("derived", {}).is_empty():
		fail("Missing derived Moth material manifest")
		return
	for key: String in derived.derived:
		if not moth.derived_texture(key) is Texture2D:
			fail("Missing derived Moth material " + key)
			return
	print("PACKAGE_MOTH_DERIVED_OK ", derived.derived.size())
	for index in range(10):
		if not load("res://first_person/generated/weapon-%d.glb" % index) is PackedScene:
			fail("Missing first-person weapon " + str(index))
			return
	var native_catalog = load("res://native_arenas/catalog.gd").new()
	if not native_catalog.open():
		fail("Native arena catalog failed: " + native_catalog.error)
		return
	for id: String in ["prism-foundry", "aurora-basin", "cinder-array"]:
		if native_catalog.resolve_map(id).is_empty() or not load("res://native_arenas/maps/" + id + ".gd") is GDScript:
			fail("Missing native arena resources " + id)
			return
	# Cinderwake Horde map recipe: a runtime FileAccess JSON the export filter
	# must include; the Nacre identity-horde scene is asserted by SCENES above.
	var horde_script: Variant = load("res://horde_maps/catalog.gd")
	if not horde_script is GDScript:
		fail("Horde map catalog script missing")
		return
	var horde_catalog = horde_script.new()
	if not horde_catalog.open() or not horde_catalog.entries.has("cinderwake-drydock"):
		fail("Horde map catalog failed: " + str(horde_catalog.error))
		return
	print("PACKAGE_HORDE_MAPS_OK ", JSON.stringify({"maps": horde_catalog.entries.keys()}))
	# Source-operator catalog (the released presentation default).
	var source_catalog: Variant = load("res://source_operators/generated/catalog.gd")
	if not source_catalog is GDScript:
		fail("Source operator catalog missing")
		return
	var operators: Dictionary = source_catalog.get_script_constant_map().get("OPERATORS", {})
	if operators.size() < 9:
		fail("Source operator catalog incomplete: " + str(operators.size()))
		return
	print("PACKAGE_SOURCE_CATALOG_OK ", JSON.stringify({"operators": operators.size()}))
	# Career catalog shape (source-derived, read at runtime by the Career autoload).
	if not career_catalog_ok():
		fail("Career catalog shape mismatch")
		return
	print("PACKAGE_CAREER_OK ")
	var audio := audio_inventory()
	if audio.is_empty():
		fail("Packaged music, announcer or Moth resource inventory invalid")
		return
	print("PACKAGE_AUDIO_OK ", JSON.stringify(audio))
	# Autoload scripts must resolve and compile from the exported PCK.
	for path: String in ["res://debug/diagnostics.gd", "res://ui/local_settings.gd", "res://career/service.gd"]:
		var autoload_script: Variant = load(path)
		if not autoload_script is GDScript or not autoload_script.can_instantiate():
			fail("Autoload resource missing: " + path)
			return
	print("PACKAGE_AUTOLOAD_OK ")
	for path: String in ["combat_shields/controller", "combat_particles/manager", "weapon_effects/controller", "combat_pickup_assets/pickup_visual"]:
		var resource = load("res://" + path + ".gd")
		if not resource is GDScript or not resource.can_instantiate():
			fail("Missing combat resource " + path)
			return
	print("PACKAGE_GRAPHICS_OK moth_planes=101 first_person_weapons=10")
	print("PACKAGE_COMBAT_EXPANSION_OK native_arenas=3 combat_resources=4")
	print("PACKAGE_INSPECT_OK ", JSON.stringify({"maps":MAPS, "scenes":SCENES.size(), "horde_maps":horde_catalog.entries.keys(), "editor":OS.has_feature("editor"), "debug":OS.is_debug_build(), "assertion_ran":assertion_ran, "tests_in_pck":false, "probes_in_pck":false}))
	quit(0)
