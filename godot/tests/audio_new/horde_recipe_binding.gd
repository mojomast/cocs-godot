extends SceneTree
## Real three-family Horde _ready and AV start with the wire connect stubbed.
## Source Horde uses its locked map; Cinderwake/Nacre use reviewed recipes.
const Source = preload("res://tests/audio_new/horde_source_no_network.gd")
const Drydock = preload("res://tests/audio_new/horde_drydock_no_network.gd")
const Nacre = preload("res://tests/audio_new/horde_nacre_no_network.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for script: GDScript in [Source, Drydock, Nacre]:
		var scene = script.new()
		root.add_child(scene)
		assert(scene.phase == 0 and scene.current_id != "")
		var id: String = scene.current_id
		var arena: Dictionary = scene.av_arena()
		assert(arena.get("id") == id and arena.get("bounds") is Dictionary,
			"Horde AV must use the reviewed source/recipe arena for " + id)
		assert(scene.av_start({"roundRevision":1}), "Horde AV round cannot start on " + id)
		assert(scene.audiovisual.weather._arena.get("id") == id,
			"weather received a different arena from the loaded Horde composition")
		scene.current_id = "unpublished-arena"
		assert(scene.av_arena().is_empty(), "an unknown recipe cannot be synthesized")
		scene.current_id = id
		scene.free()
	print("HORDE_AUDIO_RECIPE_OK source=meridian-exchange drydock=cinderwake-drydock identity=nacre-engine")
	await create_timer(0.5).timeout
	quit(0)
