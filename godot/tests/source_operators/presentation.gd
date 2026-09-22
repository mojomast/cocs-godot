extends SceneTree
## Presentation host-ownership integration for the source operator visual:
## actor.y+0.9 placement, remote visibility, snapshot feeding, shot-delta recoil,
## world weapon replacement, LOD switching and synchronous round cleanup.
const Presentation = preload("res://world/presentation.gd")
const Catalog = preload("res://source_operators/generated/catalog.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr(message)

func actor(id: int, overrides: Dictionary = {}) -> Dictionary:
	var value: Dictionary = {"id":id,"character":"claude","team":2,"x":1.0,"y":0.0,"z":2.0,"yaw":0.3,"bodyYaw":0.2,"pitch":0.1,"health":100,"dead":0,"shots":0,"weapon":2,"vx":0.5,"vz":-2.0,"grounded":true,"reloading":true,"eyeHeight":1.45,"ammo":[30,10,5],"frags":1,"deaths":0}
	value.merge(overrides,true)
	return value

func run() -> void:
	var base_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var view := Presentation.new()
	root.add_child(view)
	var remote: Dictionary = actor(1)
	var local: Dictionary = actor(9,{"x":7.0,"y":0.5,"z":8.0})
	view.apply_state({"actors":[remote,local],"mapName":"meridian-exchange"},9)
	check(view.applied == 1,"Snapshot counter")
	check(view.actors.size() == 2,"Both actors exist")
	var node = view.actors[1]
	check(node.position.is_equal_approx(Vector3(1.0,0.9,2.0)),"Remote uses host actor.y+0.9 placement")
	check(is_equal_approx(node.rotation.y,0.2),"Remote body yaw is host-owned")
	check(node.visible,"Remote actor visible")
	check(not view.actors[9].visible,"Local actor hidden")
	check(node.weapon_type == 2,"World weapon follows authoritative weapon id")
	check(is_instance_valid(node.world_weapon),"Exported world weapon instantiated")
	if is_instance_valid(node.world_weapon):
		check(node.world_weapon.get_parent() == node.nodes.gunAnchor,"World weapon mounts on source GunMount")
		check(node.anchor("Muzzle") == node.world_weapon.find_child("Muzzle",true,false),"Muzzle anchor follows the equipped world weapon")
	check(node.nodes.weapon.visible == false,"Built-in source pulse hidden")
	check(view.local_actor.get("id",-1) == 9,"Local actor snapshot exposed")
	check(view.hud_text.contains("HP 100"),"HUD owns local health")
	check(view.eye_position().is_equal_approx(Vector3(7.0,0.5+1.45,8.0)),"Camera eye position")
	# Snapshot-driven pose and post-pose hand pass.
	view.interpolate_remote = true
	node.advance(1.0/60.0)
	var phase_before: float = node.rig.phase
	for frame: int in range(30): node.advance(1.0/60.0)
	check(node.rig.phase != phase_before,"Walking snapshot advances source contact gait")
	check(node.grip_error.size() == 2,"Post-pose hand pass reports both grips")
	for side: String in node.grip_error:
		check(float(node.grip_error[side]) < 0.001,"Grip %s tracks the chassis contact" % side)
	# Genuine increasing shot counts kick; resets and first sightings do not.
	node.recoil = 0.0
	remote.shots = 3
	view.apply_state({"actors":[remote,local]},9)
	check(node.recoil > 0.0,"Increasing authoritative shots kick remote recoil")
	var kicked: float = node.recoil
	remote.shots = 0
	view.apply_state({"actors":[remote,local]},9)
	check(node.recoil == kicked,"Shot counter reset never kicks")
	var fresh: Dictionary = actor(4,{"shots":17})
	view.apply_state({"actors":[remote,local,fresh]},9)
	check(view.actors[4].recoil == 0.0,"First sighting of an already-firing actor does not kick")
	# Reload state feeds the source pose without disturbing the grip solution.
	remote.reloading = true
	remote.ads = true
	remote.vx = 0.0; remote.vz = 0.0
	var reloaded: Dictionary = remote.duplicate(true)
	view.apply_state({"actors":[reloaded,local]},9)
	node.advance(1.0/60.0)
	check(node.grip_error.size() == 2,"Reload snapshot keeps the post-pose hand pass")
	# LOD thresholds remain the source 5.8/18 m values.
	node.select_distance(1.0)
	check(node.lod_level == 0,"Near LOD")
	node.select_distance(10.0)
	check(node.lod_level == 1,"Near-detail LOD")
	node.select_distance(30.0)
	check(node.lod_level == 2,"Far LOD")
	# Unknown characters fall back to an exported identity.
	var fallback_key: String = str(Catalog.OPERATORS.keys()[0])
	view.apply_state({"actors":[remote,actor(5,{"character":"no-such-model","weapon":1}),local]},9)
	check(view.actors[5].character == fallback_key,"Unknown character falls back safely")
	check(view.actors[5].weapon_type == 1,"Fallback actor still receives its world weapon")
	check(is_instance_valid(view.actors[5].source),"Fallback actor keeps a valid source hierarchy")
	# Death hides the remote and revives on a healthy snapshot.
	view.apply_state({"actors":[actor(1,{"health":0,"dead":2.5}),local]},9)
	check(not node.visible and node.rig.dead,"Zero-health remote hides and applies source death")
	view.apply_state({"actors":[remote,local]},9)
	check(node.visible and not node.rig.dead,"Healthy snapshot revives the visual")
	# Unload: clear_round frees every node synchronously.
	var previous_weapon = node.world_weapon
	view.clear_round()
	check(view.actors.is_empty() and view.get_child_count() == 0,"Round clear releases actor nodes")
	check(not is_instance_valid(previous_weapon),"Round clear frees the world weapon")
	check(view.applied == 0 and view.hud_text.contains("Waiting") and view.last_shots.is_empty(),"Round clear resets counters")
	view.free()
	check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == base_nodes,"Presentation test releases all nodes")
	var report: Dictionary = {"passed":failures.is_empty(),"failures":failures}
	var evidence: String = OS.get_environment("OPERATOR_EVIDENCE")
	if not evidence.is_empty():
		FileAccess.open(evidence.path_join("presentation.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
