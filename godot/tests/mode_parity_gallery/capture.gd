extends SceneTree
## Screenshot-only observer. The live scenes, authority and their effects are not
## modified; Horde's staged source damage is sent by the external test harness.
const Menu = preload("res://ui/main_menu.tscn")
const Native = preload("res://native_arenas/demo.tscn")
const Horde = preload("res://native_arenas/identity_horde_demo.tscn")
const SourceHorde = preload("res://horde/demo.tscn")
var capture_size := Vector2i(1280, 800)
var scene_kind := ""
var map_id := "prism-foundry"
var output := ""
var expected_bots := 0
var scene: Node
var click_tail: Node
var local_shots := 0

class CaptureClickTail extends Node:
	var session: Node
	var active := false
	var fire := false
	var tracking_actor := -1
	func _process(_delta: float) -> void:
		if active and is_instance_valid(session) and session.can_capture_pointer():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			session.combat_actions.captured()
			session.first_person.refresh()
		if tracking_actor >= 0:
			var visual: Node3D = session.presentation.actors.get(tracking_actor)
			if not is_instance_valid(visual):
				for corpse: Dictionary in session.corpses:
					if int(corpse.actor) == tracking_actor: visual = corpse.node
			if is_instance_valid(visual):
				session.camera.look_at(visual.global_position + Vector3.UP * 0.75)
		# The same input packet as the normal controls loop, sent after its sample.
		# Under llvmpipe a rendered frame can exceed the authority's 250 ms
		# stale-input TTL, so a single synthetic mouse press can be cancelled.
		if fire: session.client.send_input({"yaw":session.yaw,"pitch":session.pitch,"fire":true})

func _initialize() -> void:
	call_deferred("run")

func abort(reason: String) -> void:
	print("GALLERY_FAIL ", reason)
	quit(1)

func shot(name: String, extra: Dictionary = {}) -> bool:
	if scene_kind != "menu" and is_instance_valid(scene) and scene.can_capture_pointer() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# The observer's simulated click runs after the HUD process. Let the
		# ordinary HUD re-read current focus before this same frame is drawn.
		var hud: Node = scene.get_node_or_null("GameHUD")
		if hud != null: hud._process(0.0)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := output.path_join(name + ".png")
	if image.get_width() != capture_size.x or image.get_height() != capture_size.y or image.save_png(path) != OK:
		abort("Could not save %s at %dx%d" % [name,capture_size.x,capture_size.y])
		return false
	print("GALLERY_SHOT ", JSON.stringify({"name":name,"path":path,"size":[image.get_width(),image.get_height()]}.merged(extra)))
	return true

func detail(name: String, center: Vector2) -> bool:
	# An explicitly labelled crop of the original frame, never a second staged
	# composition. Nearest-neighbour enlargement preserves the source pixels.
	var full := Image.load_from_file(output.path_join(name + ".png"))
	var bounds := Vector2i(440, 320)
	var left := clampi(int(center.x) - bounds.x / 2, 0, full.get_width() - bounds.x)
	var top := clampi(int(center.y) - bounds.y / 2, 0, full.get_height() - bounds.y)
	var crop := full.get_region(Rect2i(Vector2i(left, top), bounds))
	crop.resize(880, 640, Image.INTERPOLATE_NEAREST)
	var path := output.path_join(name + "-detail.png")
	if crop.save_png(path) != OK:
		abort("Could not save pixel-exact cropped detail")
		return false
	print("GALLERY_SHOT ", JSON.stringify({"name":name + "-detail","path":path,"size":[880,640],
		"source":name + ".png","crop":[left,top,bounds.x,bounds.y],"nearest_neighbour":true}))
	return true

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="): scene_kind = arg.trim_prefix("--scene=")
		if arg.begins_with("--map="): map_id = arg.trim_prefix("--map=")
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg.begins_with("--bots="): expected_bots = int(arg.trim_prefix("--bots="))
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			if parts.size() == 2: capture_size = Vector2i(int(parts[0]), int(parts[1]))
	if output.is_empty() or scene_kind not in ["menu", "native-dm", "horde"]:
		abort("Select menu/native-dm/horde and an absolute output directory")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		abort("Cannot create capture directory")
		return
	root.size = capture_size
	root.msaa_3d = Viewport.MSAA_DISABLED # llvmpipe; no shipped quality change
	scene = (Menu if scene_kind == "menu" else Native if scene_kind == "native-dm" else Horde if map_id == "nacre-engine" else SourceHorde).instantiate()
	root.add_child(scene)
	current_scene = scene # diagnostics reads the actual playing scene
	if scene_kind == "native-dm" or scene_kind == "horde":
		click_tail = CaptureClickTail.new()
		click_tail.session = scene
		click_tail.process_priority = 1000
		root.add_child(click_tail)
	if scene_kind == "menu": await capture_menu()
	elif scene_kind == "native-dm": await capture_dm()
	else: await capture_horde()

func capture_menu() -> void:
	await process_frame
	scene.select_category("native")
	scene.select_route("native-dm")
	scene.slider_rows["bots"].value = 24
	for child: Node in scene.params_box.get_children():
		if child is CheckButton and "Diagnostics" in child.text:
			child.button_pressed = true
	if scene.start.disabled or int(scene.selections.get("bots", -1)) != 24 or scene.selections.get("diagnostics") != true:
		abort("Menu did not accept 24 bots and diagnostics")
		return
	await process_frame
	if not await shot("menu-native-24", {"scene":"main-menu", "route":"native-dm", "bots":24,"diagnostics":true}): return
	print("GALLERY_DONE menu")
	quit(0)

func live(timeout_ms: int = 120000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if int(scene.phase) == -1:
			abort("Scene error: " + str(scene.label.text))
			return false
		if int(scene.phase) == 3 and scene.received_pose and scene.presentation.applied >= 5:
			return true
	abort("No authoritative live pose within deadline (phase %s)" % scene.phase)
	return false

func focus_player() -> bool:
	root.grab_focus()
	click_tail.active = true
	for i in 100:
		await process_frame
		if not root.has_focus(): root.grab_focus()
		scene.application_focused = root.has_focus()
		if scene.can_capture_pointer():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			scene.combat_actions.captured()
			scene.first_person.refresh()
			if scene.first_person.rig.showing: return true
	return false

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func capture_dm() -> void:
	if not await live(): return
	if scene.bot_count != expected_bots:
		abort("Authority-selected bot count changed")
		return
	var deadline := Time.get_ticks_msec() + 50000
	while scene.presentation.actors.size() < expected_bots + 1 and Time.get_ticks_msec() < deadline:
		await process_frame
	if scene.presentation.actors.size() != expected_bots + 1:
		abort("Expected %d real actors, got %d" % [expected_bots + 1, scene.presentation.actors.size()])
		return
	if not await focus_player():
		abort("First-person rig and pointer capture unavailable")
		return
	# Aim at the native map's authored central lane, without changing the public
	# actor position or pretending that camera motion is source movement.
	var target := Vector3(0, 3.5, 0)
	var delta: Vector3 = target - scene.camera.position
	scene.yaw = atan2(-delta.x, -delta.z)
	scene.pitch = atan2(delta.y, Vector2(delta.x, delta.z).length())
	for i in 5: await process_frame
	if "--diagnostics" in OS.get_cmdline_user_args():
		var diagnostics: Node = root.get_node_or_null("Diagnostics")
		if diagnostics == null or diagnostics.readout == null:
			abort("Menu diagnostics overlay was not attached")
			return
		diagnostics.refresh()
		if "Actors %d · Bots %d" % [expected_bots + 1, expected_bots] not in diagnostics.readout.text:
			abort("Diagnostics did not show the authority roster: " + diagnostics.readout.text)
			return
		if not await shot("dm-diagnostics", {"scene":"native-dm","map":scene.current_id,"actors":expected_bots+1,"bots":expected_bots,"first_person":true}): return
		key(KEY_TAB, true)
		for i in 8: await process_frame
		var board: Node = scene.get_node("Scoreboard")
		if not board.panel.visible or board.actor_count != expected_bots + 1:
			abort("Scoreboard did not render the live roster")
			return
		if not await shot("dm-roster", {"scene":"native-dm","map":scene.current_id,"scoreboard_actors":board.actor_count}): return
		key(KEY_TAB, false)
	else:
		var effects: Node = scene.combat.weapon_effects
		if not is_instance_valid(effects):
			abort("Weapon effects were not configured")
			return
		scene.client.events.connect(func(items: Array) -> void:
			for event: Dictionary in items:
				if event.get("type") == "shot" and int(event.get("actor", -1)) == scene.client.actor_id:
					local_shots += 1)
		var before: int = effects.flashes
		click_tail.fire = true
		var fired := false
		for i in 180:
			await process_frame
			if effects.flashes <= before or local_shots < 1 or not scene.first_person.rig.showing: continue
			fired = true
			if not await shot("dm-barrel-fire", {"scene":"native-dm","map":scene.current_id,"bots":expected_bots,"local_shots":local_shots,"fired_events":effects.flashes - before}): return
			break
		click_tail.fire = false
		if not fired:
			abort("No authoritative firing effect reached the visible barrel")
			return
	print("GALLERY_DONE native-dm")
	scene.client.disconnect_server()
	quit(0)

func capture_horde() -> void:
	if not await live(): return
	var deadline := Time.get_ticks_msec() + 90000
	var target: Dictionary = {}
	var point := Vector3.ZERO
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var actors: Array = scene.latest.get("actors", [])
		var me: Dictionary = scene.presentation.local_actor
		if me.is_empty(): continue
		var available: Array[Dictionary] = []
		for actor: Dictionary in actors:
			if actor.get("isNpc") == true and float(actor.get("health", 0)) > 0:
				available.append(actor)
		if available.size() < 2 or not scene.combat.effects_active: continue
		available.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return Vector2(float(a.x) - float(me.x), float(a.z) - float(me.z)).length_squared() < Vector2(float(b.x) - float(me.x), float(b.z) - float(me.z)).length_squared())
		for actor: Dictionary in available:
			var chest := Vector3(float(actor.x), float(actor.y) + 1.2, float(actor.z))
			var distance: float = scene.camera.global_position.distance_to(chest)
			if distance > 18.0 or distance < 2.5: continue
			# NPC visual meshes aren't colliders. Reject enemies concealed by the
			# actual map collision, rather than aiming the gallery at a wall.
			var query := PhysicsRayQueryParameters3D.create(scene.camera.global_position, chest)
			var hit: Dictionary = scene.camera.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and scene.camera.global_position.distance_to(hit.position) < distance - 0.5: continue
			target = actor
			point = chest
			print("GALLERY_VISIBLE_NPC ", JSON.stringify({"actor":int(target.id),"distance":distance,"position":[chest.x,chest.y,chest.z]}))
			break
		if not target.is_empty(): break
	if target.is_empty():
		abort("No unobstructed Horde enemy within 18m")
		return
	if not await focus_player():
		abort("Horde first-person rig and pointer capture unavailable")
		return
	click_tail.tracking_actor = int(target.id)
	for i in 2: await process_frame
	var visual: Node3D = scene.presentation.actors.get(click_tail.tracking_actor)
	if not is_instance_valid(visual):
		abort("Selected Horde enemy disappeared before staging")
		return
	point = visual.global_position + Vector3.UP * 0.75
	if not await shot("horde-before", {"scene":"horde","map":scene.current_id,"target":int(target.id),"enemies":int(scene.horde.state.get("enemiesAlive", 0))}): return
	var detail_center: Vector2 = scene.camera.unproject_position(point)
	if not detail("horde-before", detail_center): return
	print("GALLERY_READY ", JSON.stringify({"actor":int(target.id),"map":scene.current_id}))
	deadline = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not scene.corpses.is_empty() and is_instance_valid(scene.combat.blood_fx):
			var blood: Dictionary = scene.combat.blood_fx.snapshot()
			if int(blood.get("death_bursts", 0)) >= 1:
				if not await shot("horde-impact", {"scene":"horde","map":scene.current_id,"target":int(target.id),"corpses":scene.corpses.size(),"death_bursts":int(blood.death_bursts),"active_emitters":int(blood.get("active_emitters",0)),"staged_source_damage":true}): return
				if not detail("horde-impact", detail_center): return
				for i in 3: await process_frame
				if not await shot("horde-death", {"scene":"horde","map":scene.current_id,"target":int(target.id),"corpses":scene.corpses.size(),"death_bursts":int(blood.death_bursts),"staged_source_damage":true}): return
				if not detail("horde-death", detail_center): return
				print("GALLERY_DONE horde")
				scene.client.disconnect_server()
				quit(0)
				return
	abort("No received Horde death, fall and blood burst within deadline")
