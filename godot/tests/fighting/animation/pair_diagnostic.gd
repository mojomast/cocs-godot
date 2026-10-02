extends SceneTree
const Visual=preload("res://fighting/visuals/fighter_visual.gd")
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var a:=Visual.new()
	var b:=Visual.new()
	root.add_child(a)
	root.add_child(b)
	assert(a.configure("claude"))
	assert(b.configure("meta"))
	var animation:Animation=b._player.get_animation(b._clip_names["victim_claude_throw_b"])
	for track:int in animation.get_track_count():
		if str(animation.track_get_path(track)).ends_with(":Hips") and animation.track_get_type(track)==Animation.TYPE_POSITION_3D:
			print("HIPKEYS ",animation.track_get_key_count(track))
			for key:int in animation.track_get_key_count(track):
				var t:float=animation.track_get_key_time(track,key)
				if t>.50 and t<.65: print(t," ",animation.track_get_key_value(track,key))
	for frame:float in [14.0,14.5,14.8,15.0,15.2,15.5,16.0]:
		a.present({"animation":"throw_b","animation_frame":frame,"facing":1},0)
		b.present({"animation":"victim_claude_throw_b","animation_frame":frame,"facing":-1,"x":600},0)
		print(JSON.stringify({"frame":frame,"a":str(a.socket_world("GripR")),"b":str(b.socket_world("Chest")),"error":a.socket_world("GripR").distance_to(b.socket_world("Chest")),"a_hand":str(a._skeleton.get_bone_global_pose(a._skeleton.find_bone("RightHand"))),"b_chest":str(b._skeleton.get_bone_global_pose(b._skeleton.find_bone("Chest")))}))
	quit(0)
