extends SceneTree
const Robot = preload("res://campaign/robot_visual.gd")
const Operator = preload("res://source_operators/operator_visual.gd")
var session: Node
var map_id := ""
var seconds := 0.0
var done := false

func _initialize() -> void:
	call_deferred("launch")

func launch() -> void:
	var scene_path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): map_id = arg.trim_prefix("--map=")
	match map_id:
		"nacre-engine": scene_path = "res://native_arenas/identity_horde_demo.tscn"
		"cinderwake-drydock": scene_path = "res://horde_maps/demo.tscn"
		"blackwater-reclamation": scene_path = "res://horde_maps/blackwater_demo.tscn"
		"meridian-exchange", "verdant-reliquary", "ember-crucible": scene_path = "res://horde/demo.tscn"
	if scene_path.is_empty():
		push_error("Unknown robot census Horde map " + map_id)
		quit(2)
		return
	var scene: PackedScene = load(scene_path)
	session = scene.instantiate()
	root.add_child(session)
	print("HORDE_CENSUS_SCENE ", JSON.stringify({"map":map_id,"scene":scene_path,"script":session.get_script().resource_path}))

func _process(dt: float) -> bool:
	if done or not is_instance_valid(session): return false
	seconds += dt
	if session.phase == -1:
		finish(false,"session error: " + str(session.label.text))
		return false
	if session.phase != 3: return false
	var state: Dictionary = session.latest
	var npcs: Array = state.get("actors", []).filter(func(a: Dictionary) -> bool: return a.get("isNpc") == true)
	if npcs.size() >= 2:
		var visuals := []
		var ok := true
		var local: Node3D = session.presentation.actors.get(0)
		ok = local != null and local.get_script() == Operator
		for npc: Dictionary in npcs:
			var visual: Node3D = session.presentation.actors.get(int(npc.id))
			var valid: bool = visual != null and visual.get_script() == Robot
			if valid: valid = visual.model_id == str(npc.get("npcModel", "")) and npc.get("health", 0) > 0
			ok = ok and valid
			visuals.append({"id":npc.id,"type":npc.get("npcType"),"model":npc.get("npcModel"),
				"hitScale":npc.get("hitScale"),"health":npc.get("health"),"visual_script":visual.get_script().resource_path if visual != null else "missing",
				"art_batches":visual.art_meshes.get(visual.model_id, {}).size() if valid else 0,
				"visible_cost":visual.visible_cost() if valid else {}})
		print("HORDE_ROBOT_CENSUS ", JSON.stringify({"map":map_id,"local_visual":local.get_script().resource_path if local != null else "missing",
			"authority_epoch":session.horde_client.input_epoch,"source_time":state.get("time"),"npc_count":npcs.size(),"visuals":visuals,"ok":ok}))
		finish(ok,"real network NPC census")
	elif seconds > 16.0:
		finish(false,"wave-one NPC census timed out")
	return false

func finish(ok: bool, message: String) -> void:
	if done: return
	done = true
	print("HORDE_CENSUS_DONE ", JSON.stringify({"map":map_id,"ok":ok,"message":message,"seconds":seconds}))
	call_deferred("cleanup", 0 if ok else 1)

func cleanup(code: int) -> void:
	if is_instance_valid(session): session.queue_free()
	for i: int in 8: await process_frame # Let audio playback handles release after voices stop.
	quit(code)
