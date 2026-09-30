extends SceneTree
const Model = preload("res://campaign/model.gd")
const Director = preload("res://campaign/story_director.gd")
const Puppy = preload("res://campaign/puppy_visual.gd")
const Widgets = preload("res://campaign/story_widgets.gd")

func _initialize() -> void:
	call_deferred("run")

func puppy(serial: int = 0) -> Dictionary:
	return {"id":"patch", "kind":"puppy", "name":"Patch", "x":2.0, "y":1.0, "z":-3.0, "yaw":0.0, "pose":"sit", "active":true, "reactionSerial":serial}

func story(entries: Array, caption: Variant = null, prompt: Variant = null) -> Dictionary:
	return {"version":1, "entities":entries, "caption":caption, "prompt":prompt, "pets":0, "completed":[]}

func run() -> void:
	var director := Director.new()
	root.add_child(director)
	var first := story([puppy(4)])
	assert(Model.valid_story(first))
	director.apply(first, "rootfall-verge")
	var patch: Node3D = director.actors.patch
	assert(patch is Puppy and patch.position == Vector3(2, 1, -3))
	assert(patch.get("reaction") == 0, "Initial/resync serial is a baseline, not a pet")
	assert(not patch.has_node("CollisionShape3D"), "The puppy never participates in combat physics")
	assert(patch.get("body") != null and patch.get("head") != null and patch.get("tail") != null and patch.get("ears").size() == 2)
	assert(Puppy.coat("b77847") == Puppy.coat("b77847"), "Shared coat material is cached")
	director.apply(first, "rootfall-verge")
	assert(patch.get("reaction") == 0)
	var accepted := story([puppy(5)])
	director.apply(accepted, "rootfall-verge")
	assert(patch.get("reaction") > 0, "Only authoritative serial increments animate petting")
	patch.set("reaction", 0.0)
	director.apply(accepted, "rootfall-verge")
	assert(patch.get("reaction") == 0, "Repeated snapshot does not replay accepted pet")
	patch.call("select_distance", 60)
	assert(patch.get("lod") == 2 and patch.get("head").get_node("EyeGlint").visible == false)
	patch.call("select_distance", 2)
	assert(patch.get("lod") == 0)
	var inactive := puppy(5)
	inactive.active = false
	director.apply(story([inactive]), "rootfall-verge")
	assert(director.actors.is_empty())
	director.apply(accepted, "rootfall-verge")
	assert(director.actors.patch.reaction == 0, "An inactive appearance retains its serial baseline")
	director.apply(accepted, "siltwake-crossing")
	assert(director.actors.patch.reaction == 0, "Chapter start never falsely replays a pet")
	var bad := accepted.duplicate(true)
	bad.entities[0].x = INF
	assert(not Model.valid_story(bad))
	bad = accepted.duplicate(true)
	bad.entities.append(puppy())
	assert(not Model.valid_story(bad), "Duplicate story identities are rejected")
	var widgets := Widgets.new()
	root.add_child(widgets)
	widgets.observe(story([puppy()], {"id":"hello", "speaker":"Mara", "text":"Patch remembers you."}, {"entityId":"patch", "action":"pet", "text":"Pet Patch"}), true)
	assert(widgets.prompt.text == "[E] Pet Patch" and widgets.caption.text.contains("Mara"))
	get_root().size = Vector2i(720, 480)
	widgets.layout()
	assert(widgets.prompt.position.x >= 0 and widgets.prompt.position.y > 200)
	widgets.observe({}, false)
	assert(not widgets.prompt.visible and not widgets.caption.visible)
	director.clear_round()
	assert(director.actors.is_empty() and director.last_serial.is_empty())
	widgets.free()
	director.free()
	print("CAMPAIGN_STORY_PRESENTATION_OK")
	quit()
