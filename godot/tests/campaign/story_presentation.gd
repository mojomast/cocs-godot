extends SceneTree
const Model = preload("res://campaign/model.gd")
const Director = preload("res://campaign/story_director.gd")
const Puppy = preload("res://campaign/puppy_visual.gd")
const Widgets = preload("res://campaign/story_widgets.gd")

class StorySession extends Node:
	var application_focused := true
	var phase := 3
	var action_pending := false
	var startup_error := ""
	var campaign = preload("res://campaign/model.gd").new()

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
	var decoded: Variant = JSON.parse_string(JSON.stringify(first))
	assert(Model.valid_story(decoded), "Wire JSON roundtrip must accept integer-valued counts")
	decoded.pets = 2.0
	decoded.entities[0].reactionSerial = 5.0
	assert(Model.valid_story(decoded), "JSON numeric counts can be floats")
	for invalid: Variant in [INF, NAN, -1, 1.5, 2147483648.0]:
		decoded.pets = invalid
		assert(not Model.valid_story(decoded))
	decoded.pets = 2.0
	decoded.entities[0].reactionSerial = 1.25
	assert(not Model.valid_story(decoded))
	director.apply(first, "rootfall-verge")
	var patch: Node3D = director.actors.patch
	assert(patch is Puppy and patch.position == Vector3(2, 1, -3))
	assert(patch.get("reaction") == 0, "Initial/resync serial is a baseline, not a pet")
	assert(not patch.has_node("CollisionShape3D"), "The puppy never participates in combat physics")
	assert(patch.get("body") != null and patch.get("head") != null and patch.get("tail") != null and patch.get("ears").size() == 2)
	assert(Puppy.coat("b77847") == Puppy.coat("b77847"), "Shared coat material is cached")
	assert(Puppy.sphere("b77847") == Puppy.sphere("b77847"))
	assert(Puppy.sphere("b77847").radial_segments == 12 and Puppy.sphere("b77847").rings == 6)
	for pose: String in ["idle", "sit", "walk", "happy", "work"]:
		patch.call("set_pose", pose)
		for n: int in range(20):
			patch.call("_process", 0.05)
			for paw: Node3D in patch.get("paws"):
				var bottom: Vector3 = paw.global_transform * Vector3(0, -0.13, 0)
				assert(bottom.y >= 0.99, "Paws stay at or above authoritative ground in %s" % pose)
		if pose == "walk":
			assert((patch.get("paws")[0] as Node3D).position.y > 0.13 or (patch.get("paws")[1] as Node3D).position.y > 0.13, "Walking animates feet without moving the authoritative root")
	director.apply(first, "rootfall-verge")
	assert(patch.get("reaction") == 0)
	var accepted: Dictionary = JSON.parse_string(JSON.stringify(story([puppy(5)])))
	accepted.entities[0].reactionSerial = 5.0
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
	director.apply(story([puppy(6)]), "rootfall-verge")
	assert(director.actors.patch.reaction > 0, "A fresh accepted pet after reappearance animates")
	inactive.reactionSerial = 6
	director.apply(story([inactive]), "rootfall-verge")
	director.apply(story([puppy(7)]), "rootfall-verge")
	assert(director.actors.patch.reaction == 0, "A serial change while hidden is baseline on return")
	director.apply(accepted, "siltwake-crossing")
	assert(director.actors.patch.reaction == 0, "Chapter start never falsely replays a pet")
	var operator := {"id":"mara", "kind":"operator", "name":"Mara", "character":"chatgpt", "x":-2.0, "y":1.0, "z":-3.0, "yaw":0.0, "pose":"wave", "active":true, "reactionSerial":0}
	director.apply(story([puppy(), operator]), "siltwake-crossing")
	var friendly: Node3D = director.actors.mara
	assert(is_equal_approx(friendly.position.y, 1.9) and is_equal_approx(friendly.get("source").position.y, -0.9))
	var nodes: Dictionary = friendly.get("nodes")
	assert(nodes.has("armUpperR") and nodes.has("forearmR") and nodes.has("weapon"))
	assert(not nodes.weapon.visible and friendly.get("world_weapon") == null, "Friendly operator is disarmed without changing shared rig")
	director._process(0.016)
	assert(nodes.armUpperR.quaternion != friendly.get("rig").bind.armUpperR.basis.get_rotation_quaternion(), "Wave uses the actual source upper-arm joint")
	# Actual imported mesh bounds in world coordinates, excluding hidden weapon.
	var lowest := INF
	for mesh: MeshInstance3D in friendly.get("source").find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree(): continue
		var bounds := mesh.get_aabb()
		for x: float in [bounds.position.x, bounds.end.x]:
			for y: float in [bounds.position.y, bounds.end.y]:
				for z: float in [bounds.position.z, bounds.end.z]:
					lowest = minf(lowest, (mesh.global_transform * Vector3(x, y, z)).y)
	assert(lowest >= 0.86 and lowest <= 1.22, "Actual operator sole bounds stay near supported feet y=1")
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
	assert(widgets.caption.position.y + widgets.caption.size.y < 480 - 100, "Compact caption clears bottom comms/vitals band")
	var stub := StorySession.new()
	stub.campaign.state = {"phase":"playing"}
	root.add_child(stub)
	widgets.session = stub
	widgets.refresh()
	assert(widgets.caption.visible)
	stub.application_focused = false
	widgets.refresh()
	assert(not widgets.caption.visible and not widgets.prompt.visible, "Focus loss hides story immediately")
	stub.application_focused = true
	stub.startup_error = "Disconnected"
	widgets.refresh()
	assert(not widgets.caption.visible, "Transport error hides story before the next snapshot")
	stub.free()
	widgets.session = null
	widgets.observe({}, false)
	assert(not widgets.prompt.visible and not widgets.caption.visible)
	director.clear_round()
	assert(director.actors.is_empty() and director.last_serial.is_empty())
	widgets.free()
	director.free()
	print("CAMPAIGN_STORY_PRESENTATION_OK")
	quit()
