extends "res://tests/horde/blackwater_headless.gd"
## Ordinary native InputEvents, with explicit chain AND boss-defeat receipts.
## Fixture strategy only: no Match/actor/director access, no seeded progression.
var requested_goal := "chain"
var next_reload := 0.0
var next_power := 0.0
var actual_warden := -1
var actual_warden_defeated := false
var capture_directory := ""
var capture_key := ""
var capture_busy := false
var capture_frames := 0
var video_started := -1.0
var next_video := 0.0
var offered_at := -1.0
var observed_offer := -1

func _ready() -> void:
	super()
	requested_goal = goal
	if requested_goal == "boss": wall_limit = 930.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-directory="): capture_directory = arg.trim_prefix("--capture-directory=")
	var settings: Node = get_node_or_null("/root/LocalSettings")
	if settings != null: settings.set_value("ui_scale",150 if "--compact" in OS.get_cmdline_user_args() else 100,false)
	if not capture_directory.is_empty(): get_window().grab_focus()
	if not capture_directory.is_empty(): DirAccess.make_dir_recursive_absolute(capture_directory)

func choose_native_upgrade() -> void:
	if capture_directory.is_empty(): super(); return
	if session.horde.offer_pending and observed_offer != session.horde.offer_wave:
		observed_offer = session.horde.offer_wave
		offered_at = float(Time.get_ticks_usec())/1000000.0
	# Leave the real offer readable long enough for a captured rendered frame.
	if offered_at>=0 and float(Time.get_ticks_usec())/1000000.0-offered_at>=2.0: super()

func capture_frame(tag: String, video: bool) -> void:
	if capture_busy: return
	capture_busy = true
	await RenderingServer.frame_post_draw
	if not is_inside_tree(): return
	var file := "%05d-%s.png" % [capture_frames,tag]
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(capture_directory.path_join(file))
	print("BLACKWATER_CAPTURE ",JSON.stringify({"file":file,"error":error,"video":video,
		"wall_seconds":float(Time.get_ticks_usec()-started_usec)/1000000.0,"source_time":session.latest.get("time"),
		"viewport":[image.get_width(),image.get_height()],"logical_viewport":[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y],
		"ui_scale":get_window().content_scale_factor,"hud":session.horde_label.text,
		"mission_rect":[session.horde_label.position.x,session.horde_label.position.y,session.horde_label.size.x,session.horde_label.size.y],
		"choices_rect":[session.choice_layer.offset.x,session.choice_layer.offset.y,session.choice_scroll.size.x,session.choice_scroll.size.y],
		"choices_visible":session.choice_panel.visible}))
	capture_frames += 1
	capture_busy = false

func capture_tick() -> void:
	if capture_directory.is_empty() or session.phase!=3 or not session.received_pose: return
	if not session.weapon_controls_active():
		# Exercise the production click-to-capture path in a focused rendered window.
		mouse(true); mouse(false)
	var now := float(Time.get_ticks_usec())/1000000.0
	if video_started<0: video_started = now
	var state: Dictionary = session.horde.state
	var mission: Dictionary = session.latest.get("blackwater",{})
	var key_now := "%s-%s-%s-%s-%s-%s" % [state.get("wave"),mission.get("serial"),mission.get("active"),state.get("stage",{}).get("gateMask"),session.horde.offer_pending,last_warden_phase]
	var video := now-video_started<=60.0 and now>=next_video
	if not capture_busy and (key_now!=capture_key or video):
		capture_key = key_now
		if video: next_video = now+0.25
		capture_frame("journey",video)

func observe_events(events: Array) -> void:
	super(events)
	for item: Variant in events:
		if item is Dictionary and item.get("type") == "horde-warden-arrived": actual_warden = int(item.get("actor", -1))

func visible_enemy(actor: Dictionary) -> bool:
	var target := Vector3(float(actor.x),float(actor.y)+1.2,float(actor.z))
	var query := PhysicsRayQueryParameters3D.create(session.camera.position,target,1)
	return session.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func nearest_enemy(player: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for actor: Dictionary in session.latest.get("actors",[]):
		if actor.get("isNpc") != true or float(actor.get("health",0))<=0 or not visible_enemy(actor): continue
		var distance := Vector2(float(actor.x)-float(player.x),float(actor.z)-float(player.z)).length()
		if distance < best_distance: best_distance = distance; best = actor
	return best if not best.is_empty() else super(player)

func move_towards(target: Vector2, player: Dictionary, enemy: Dictionary = {}) -> float:
	if route_key.begins_with("combat") and not enemy.is_empty() and visible_enemy(enemy):
		var distance := Vector2(float(enemy.x)-float(player.x),float(enemy.z)-float(player.z)).length()
		if distance < 24:
			aim_at(enemy,player)
			for code: int in [KEY_W,KEY_S,KEY_A,KEY_D,KEY_SHIFT]: key(code,false)
			return 0.0
	return super(target,player,enemy)

func _process(delta: float) -> void:
	if done: return
	capture_tick()
	for actor: Dictionary in session.latest.get("actors",[]):
		if int(actor.get("id",-1)) == actual_warden and actual_warden>=0 and float(actor.get("health",1))<=0: actual_warden_defeated = true
	var state: Dictionary = session.horde.state
	var mission: Dictionary = session.latest.get("blackwater",{})
	if chain_complete(state,mission):
		if requested_goal == "chain":
			finish(true,"four source-earned stations and both arrivals with native receipts")
			return
		if actual_warden_defeated and state.get("phase") == "won" and last_warden_phase>=3 and boss_tell and boss_voice:
			finish(true,"source victory, wave-ten Warden defeated, three phases, native tell and voice")
			return
	# Parent fixture's boss goal stops at phase three, before defeat. Keep its
	# ordinary control path but require the stronger receipt above.
	goal = "full-journey"
	super(delta)
	goal = requested_goal
	if done or session.phase!=3 or not session.weapon_controls_active(): return
	var player: Dictionary = session.presentation.local_actor
	if player.is_empty() or float(player.get("health",0))<=0: return
	var now := float(session.latest.get("time",0))
	var ammo: Array = player.get("ammo",[])
	var weapon := int(player.get("weapon",0))
	# Parent only reloads in its combat branch. Repairs also need R: the source
	# finite pool can run dry while defending a station.
	if weapon>=0 and weapon<ammo.size() and (ammo[weapon] is float or ammo[weapon] is int):
		if float(ammo[weapon])<=0 and now>=next_reload:
			key(KEY_R,false); key(KEY_R,true); key(KEY_R,false)
			next_reload = now+0.5
	var enemy := nearest_enemy(player)
	if not enemy.is_empty() and Vector2(float(enemy.x)-float(player.x),float(enemy.z)-float(player.z)).length()<5.5 and now>=next_power:
		key(KEY_Q,true); key(KEY_Q,false)
		next_power = now+0.5

func finish(ok: bool, message: String) -> void:
	goal = requested_goal
	print("BLACKWATER_BOSS_DEFEAT_RECEIPT ",JSON.stringify({"id":actual_warden,"defeated":actual_warden_defeated}))
	super(ok,message)
