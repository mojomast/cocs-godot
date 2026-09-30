extends SceneTree
## External graphical driver; usable with --main-pack without exporting tests.
## Every gameplay/results frame comes from the owned real campaign authority.
var session: Node
var settings: Node
var output := ""
var control_url := ""
var profile := "wide"
var failures: Array[String] = []
var captures: Array = []
var banner: Label
var finished := false
var started_ms := 0
var atmosphere_ids: Dictionary = {}

func _initialize() -> void:
	started_ms = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-output="): output = arg.trim_prefix("--capture-output=")
		if arg.begins_with("--capture-control="): control_url = arg.trim_prefix("--capture-control=")
		if arg.begins_with("--capture-profile="): profile = arg.trim_prefix("--capture-profile=")
	call_deferred("run")

func _process(_delta: float) -> bool:
	if not finished and Time.get_ticks_msec() - started_ms > 210000:
		failures.append("Capture fixture watchdog expired")
		finish()
	return false

func require(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("CAMPAIGN_CAPTURE_CHECK ", message)

func wait_for(predicate: Callable, description: String, seconds: float = 25) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if is_instance_valid(session) and not str(session.startup_error).is_empty(): break
		await process_frame
	require(false, "Timed out: " + description)
	return false

func settle() -> void:
	for frame: int in range(5): await process_frame
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw

func stage(name: String) -> bool:
	var request := HTTPRequest.new()
	root.add_child(request)
	request.timeout = 10
	var queued := request.request(control_url + "/stage/" + name, [], HTTPClient.METHOD_POST)
	if queued != OK:
		require(false, "Could not queue trusted fixture stage " + name)
		request.queue_free()
		return false
	var reply: Array = await request.request_completed
	request.queue_free()
	require(int(reply[1]) == 200, "Trusted fixture stage failed: " + name)
	return int(reply[1]) == 200

func run() -> void:
	if output.is_empty() or not control_url.begins_with("http://127.0.0.1:"):
		push_error("Capture fixture requires its owned output/control arguments")
		quit(1)
		return
	settings = root.get_node_or_null("LocalSettings")
	require(settings != null, "Real LocalSettings autoload is required")
	if settings == null:
		finish()
		return
	root.size = Vector2i(760, 520) if profile == "compact" else Vector2i(1280, 800)
	settings.set_value("ui_scale", 150 if profile == "compact" else 100, false)
	root.grab_focus()
	var scene: PackedScene = load("res://campaign/demo.tscn")
	if scene == null:
		require(false, "Pack/source does not contain the real campaign scene")
		finish()
		return
	session = scene.instantiate()
	root.add_child(session)
	current_scene = session
	var layer := CanvasLayer.new()
	layer.layer = 1000
	root.add_child(layer)
	banner = Label.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_font_size_override("font_size", 10)
	banner.add_theme_color_override("font_color", Color.YELLOW)
	banner.add_theme_color_override("font_shadow_color", Color.BLACK)
	banner.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(banner)
	if not session.startup_error.is_empty():
		require(false, session.startup_error)
		finish()
		return
	# Observe the production briefing camera; never repair it in the fixture.
	require(session.camera.position.y > session.world.height_at(session.camera.position.x, session.camera.position.z) + 1, "Production briefing camera must be above terrain")
	await capture("briefing")
	await capture_actions("briefing-actions")
	session.launch_campaign()
	if not await wait_for(func() -> bool: return session.phase == 3 and session.received_pose and session.client.last_ack > 0, "real start/snapshot/ACK"):
		finish()
		return
	await stage("gameplay")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await capture("gameplay")
	await stage("long-subtitle")
	await capture("long-subtitle")
	session.release_pointer()
	session.campaign_hud.comms.scroll_vertical = int(session.campaign_hud.comms.get_v_scroll_bar().max_value)
	await capture("long-subtitle-tail")
	require(session.campaign_hud.subtitle.get_global_rect().end.y <= session.campaign_hud.comms.get_global_rect().end.y + 1, "Full comms tail must be reachable inside its scroll viewport")
	# Exercise the actual Settings button rather than painting an overlay.
	session.campaign_hud.settings.pressed.emit()
	await capture("settings-overlay")
	require(settings.overlay_open(), "Settings button opens the real overlay")
	settings.close_panel()
	require(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "Closing Settings must not silently recapture")
	await stage("death")
	if not await wait_for(func() -> bool: return session.campaign.state.get("phase") == "dead", "authoritative death results"):
		finish()
		return
	await capture("death")
	await capture_actions("death-actions")
	var old_starts: int = session.round_starts
	session.campaign_hud.primary.pressed.emit()
	if not await wait_for(func() -> bool: return session.round_starts > old_starts and session.phase == 3 and session.received_pose, "normal checkpoint retry fresh start"):
		finish()
		return
	await stage("result")
	if not await wait_for(func() -> bool: return session.phase == 4 and session.campaign.state.get("phase") == "level-complete", "normal level-complete results"):
		finish()
		return
	await capture("result")
	await capture_actions("result-actions")
	if session.current_id == "crown-array":
		old_starts = session.round_starts
		var old_epoch: int = session.client.input_epoch
		session.campaign_hud.primary.pressed.emit()
		if not await wait_for(func() -> bool: return session.phase == 4 and session.campaign.state.get("phase") == "campaign-complete", "final Continue fresh-start plus ending results"):
			finish()
			return
		require(session.round_starts == old_starts + 1 and session.client.input_epoch > old_epoch, "Ending must cross a real fresh start/epoch boundary")
		require(session.client.round_finished and not session.campaign_hud.primary.visible, "Ending is latched with no phantom Continue")
		await capture("ending")
	finish()

func rect_data(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func scroller(node: Node) -> ScrollContainer:
	var parent := node.get_parent()
	while parent != null:
		if parent is ScrollContainer: return parent
		parent = parent.get_parent()
	return null

func shown(node: Control) -> bool:
	return node.is_visible_in_tree() and (not node is Label or not node.text.is_empty())

func painted_rect(node: Control) -> Rect2:
	var rect := node.get_global_rect()
	var parent := node.get_parent()
	while parent != null:
		if parent is Control and parent.clip_contents: rect = rect.intersection(parent.get_global_rect())
		parent = parent.get_parent()
	return rect

func ui_checks(name: String) -> Dictionary:
	var hud: Control = session.campaign_hud
	var viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var widgets := {"objective":hud.objective,"detail":hud.detail,"notice":hud.notice,"status":hud.status,
		"subtitle":hud.subtitle,"vitals":hud.vitals,"waypoint":hud.waypoint,"crosshair":hud.crosshair,
		"card":hud.card,"heading":hud.heading,"body":hud.body,"primary":hud.primary,"restart":hud.restart,
		"settings":hud.settings,"leave":hud.leave,"comms":hud.comms,"boss":hud.boss}
	var records := {}
	for key: String in widgets:
		var node: Control = widgets[key]
		if not shown(node): continue
		var rect := node.get_global_rect()
		var scroll := scroller(node)
		records[key] = {"rect":rect_data(rect),"paintedRect":rect_data(painted_rect(node)),"scrollable":scroll != null}
		if node is Label:
			records[key]["lines"] = node.get_line_count()
			records[key]["text"] = node.text
		if settings.overlay_open(): continue # underlying controls are intentionally occluded
		if scroll == null:
			require(viewport.grow(1).encloses(rect), name + ": " + key + " outside viewport")
		else:
			var clip := scroll.get_global_rect()
			require(viewport.grow(1).encloses(clip), name + ": modal scroll viewport outside window")
			require(rect.position.x >= clip.position.x - 1 and rect.end.x <= clip.end.x + 1, name + ": " + key + " horizontally clipped")
	# All named pairs are independent information/action surfaces, not intended
	# background/child intersections. Modal underlying text must not bleed through
	# its border; scrolling the modal's own content remains intentional.
	var pairs := [["objective","settings"],["objective","leave"],["detail","settings"],
		["subtitle","vitals"],["subtitle","crosshair"],["status","crosshair"],
		["objective","crosshair"],["detail","crosshair"],["waypoint","crosshair"],
		["waypoint","subtitle"],["card","subtitle"],["card","vitals"],["card","waypoint"],
		["comms","crosshair"],["comms","vitals"],["comms","waypoint"],["boss","crosshair"]]
	if not settings.overlay_open():
		for pair: Array in pairs:
			var a: Control = widgets[pair[0]]
			var b: Control = widgets[pair[1]]
			if shown(a) and shown(b): require(not painted_rect(a).intersects(painted_rect(b)), name + ": overlap " + pair[0] + "/" + pair[1])
	if settings.overlay_open():
		require(not hud.crosshair.visible and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, name + ": overlay retains crosshair/capture")
		require(viewport.grow(1).encloses(settings.panel.get_global_rect()), name + ": Settings outside viewport")
	# Campaign currently has subtitles rather than lobby chat. If a shared overlay
	# starts exposing chat here, catch its collision with the live crosshair too.
	for child: Node in root.find_children("*", "Control", true, false):
		var node := child as Control
		if str(node.name).to_lower().contains("chat") and node.is_visible_in_tree() and shown(hud.crosshair):
			require(not node.get_global_rect().intersects(hud.crosshair.get_global_rect()), name + ": chat/crosshair overlap")
	if name == "long-subtitle": require(hud.subtitle.get_line_count() > 1, "Long subtitle must wrap")
	if name.ends_with("-actions"):
		var scroll := scroller(hud.primary)
		var allowed: Rect2 = scroll.get_global_rect() if scroll != null else hud.card.get_global_rect()
		require(allowed.grow(1).encloses(hud.primary.get_global_rect()) and viewport.grow(1).encloses(hud.primary.get_global_rect()), name + ": primary action not fully reachable")
	return records

func capture_actions(name: String) -> void:
	var button: Control = session.campaign_hud.primary
	var scroll := scroller(button)
	if scroll != null:
		await process_frame
		scroll.ensure_control_visible(button)
	await capture(name)
	if scroll != null: scroll.scroll_vertical = 0

func capture(name: String) -> void:
	banner.text = "SCRIPTED AUTHORITY FIXTURE | " + name
	await settle()
	if name in ["gameplay", "long-subtitle"]:
		# Slow software frames can trigger the legitimate 250 ms input TTL. A
		# scripted explicit click after that boundary may recapture; production
		# focus/input policy is never bypassed or disabled for screenshots.
		for attempt: int in range(4):
			root.grab_focus()
			await process_frame
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			session._unhandled_input(click)
			await process_frame
			await RenderingServer.frame_post_draw
			if is_instance_valid(session.first_person) and session.first_person.rig.showing: break
	var before := failures.size()
	var widgets := ui_checks(name)
	var lighting := inspect_lighting(name)
	var robot_count := 0
	for visual: Node3D in session.presentation.actors.values():
		if visual.visible and visual.get_script().resource_path == "res://campaign/robot_visual.gd" and session.camera.is_position_in_frustum(visual.global_position):
			robot_count += 1
			if name in ["gameplay", "long-subtitle"]: require(float(visual.snapshot.get("protection", 0)) <= 0, name + ": frozen fixture robot must not retain spawn-protection bubble")
	var rings := 0
	if "ground_tells" in session:
		for entry: Dictionary in session.ground_tells.rings.values():
			if is_instance_valid(entry.node) and entry.node.visible and session.camera.is_position_in_frustum(Vector3(entry.x, session.world.height_at(entry.x, entry.z), entry.z)): rings += 1
	if name in ["gameplay","long-subtitle"]:
		require(robot_count > 0, name + ": no actual robot in camera frustum")
		require(rings > 0, name + ": no actual authority ground telegraph in camera frustum")
		require(is_instance_valid(session.first_person) and session.first_person.rig.showing, name + ": actual first-person rig missing")
		require(session.client.last_ack > 0, name + ": no real input ACK")
	var image := root.get_texture().get_image()
	var path := output.path_join(name + ".png")
	require(image.save_png(path) == OK, "Could not save " + path)
	var expected := Vector2i(760,520) if profile == "compact" else Vector2i(1280,800)
	require(image.get_size() == expected, name + ": physical capture dimensions differ from requested profile")
	captures.append({"scenario":name,"scripted":true,"path":path,"map":session.current_id,"profile":profile,
		"lighting":lighting,
		"camera":[session.camera.position.x,session.camera.position.y,session.camera.position.z],"yaw":session.yaw,"pitch":session.pitch,
		"focused":session.application_focused,"windowFocused":root.has_focus(),"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"eligible":session.can_capture_pointer(),
		"physicalSize":[image.get_width(),image.get_height()],"logicalSize":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],
		"uiScale":settings.values.ui_scale,"phase":session.phase,"campaignPhase":session.campaign.state.get("phase", "briefing"),
		"starts":session.round_starts,"epoch":session.client.input_epoch,"acks":session.client.last_ack,
		"robotsInFrustum":robot_count,"groundRingsInFrustum":rings,"widgets":widgets,"newFailures":failures.size()-before})

func inspect_lighting(stage_name: String) -> Dictionary:
	var environments := root.find_children("*", "WorldEnvironment", true, false)
	var suns := root.find_children("*", "DirectionalLight3D", true, false)
	require(environments.size() == 1 and suns.size() == 1, stage_name + ": exactly one persistent campaign sky and sun required")
	if environments.size() != 1 or suns.size() != 1: return {"environments":environments.size(),"suns":suns.size()}
	var sky_node := environments[0] as WorldEnvironment
	var sun := suns[0] as DirectionalLight3D
	var env: Environment = sky_node.environment
	require(session.world.is_ancestor_of(sky_node) and session.world.is_ancestor_of(sun), stage_name + ": lighting must belong to the real world, not the fixture")
	var atmosphere: Node = session.world.get_node_or_null("CampaignEnvironment")
	require(atmosphere != null and atmosphere.map_id == session.current_id, stage_name + ": daylight profile must match the active chapter")
	var identity := [sky_node.get_instance_id(), sun.get_instance_id()]
	if atmosphere_ids.has(session.current_id): require(atmosphere_ids[session.current_id] == identity, stage_name + ": start/retry must preserve the map lighting instances")
	else: atmosphere_ids[session.current_id] = identity
	require(env != null and env.background_mode == Environment.BG_SKY and env.sky != null, stage_name + ": sky background missing")
	if env == null or env.sky == null: return {"environments":1,"suns":1,"valid":false}
	require(session.camera.get_world_3d().environment == env, stage_name + ": campaign sky must be the effective world environment")
	require(env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR and env.ambient_light_energy >= 0.35, stage_name + ": daylight ambient fill missing")
	require(sun.visible and sun.light_energy >= 0.5 and sun.shadow_enabled, stage_name + ": daylight shadow sun missing")
	var material := env.sky.sky_material as ProceduralSkyMaterial
	require(material != null and material.sky_top_color.get_luminance() > 0.35, stage_name + ": sky palette must be daylight")
	return {"environments":1,"suns":1,"instanceIDs":identity,"sunEnergy":sun.light_energy,"shadows":sun.shadow_enabled,
		"ambientEnergy":env.ambient_light_energy,"skyTop":material.sky_top_color.to_html() if material != null else "invalid"}

func finish() -> void:
	if finished: return
	finished = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(session): session.client.disconnect_server()
	var report := {"passed":failures.is_empty(),"scripted":true,"failures":failures,"captures":captures,
		"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name()}
	var file := FileAccess.open(output.path_join("capture-report.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t"))
	else: failures.append("Could not save capture report")
	print("CAMPAIGN_CAPTURE_OK" if failures.is_empty() else "CAMPAIGN_CAPTURE_FAILED")
	quit(0 if failures.is_empty() else 1)
