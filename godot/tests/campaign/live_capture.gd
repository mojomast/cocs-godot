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
var input_boundaries: Array = []

class CaptureClick extends Node:
	var session: Node
	var pending := false
	signal applied
	func _process(_delta: float) -> void:
		if not pending: return
		pending = false
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		session._unhandled_input(click)
		if is_instance_valid(session.first_person): session.first_person.refresh()
		session.campaign_hud._process(0.0)
		applied.emit()

var capture_click: CaptureClick

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
	capture_click = CaptureClick.new()
	capture_click.session = session
	capture_click.process_priority = 10000
	root.add_child(capture_click)
	session.client.connect("input_reset", func(reason: String) -> void:
		input_boundaries.append({"reason":reason,"epoch":session.client.input_epoch,"atMs":Time.get_ticks_msec()}))
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
	var attempts := 0
	var draw_ms := 0
	if name in ["gameplay", "long-subtitle"]:
		# process_frame precedes client polling: clicking there can immediately be
		# cancelled by an already queued TTL reset. Click after that poll, in a
		# late process callback (before canvas submission), and refresh presenters for
		# this same rendered frame. Never alter epochs, focus, freshness or TTL.
		for attempt: int in range(4):
			attempts += 1
			root.grab_focus()
			capture_click.pending = true
			await capture_click.applied
			var draw_start := Time.get_ticks_msec()
			await RenderingServer.frame_post_draw
			draw_ms = Time.get_ticks_msec() - draw_start
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and session.can_capture_pointer() and is_instance_valid(session.first_person) and session.first_person.rig.showing: break
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
		require(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and session.can_capture_pointer(), name + ": capture must obey live focus/freshness/lifecycle eligibility")
		require(session.client.last_ack > 0, name + ": no real input ACK")
	var image := root.get_texture().get_image()
	var rig_pixels := {"opaque":0,"matched":0,"occluded":0}
	if name in ["gameplay", "long-subtitle"] and is_instance_valid(session.first_person):
		var weapon: Image = session.first_person.rig.viewport.get_texture().get_image()
		rig_pixels = compare_weapon_pixels(image, weapon, true)
		if name == "long-subtitle" and rig_pixels.opaque < 100 and rig_pixels.occluded > 100:
			# The deliberately oversized scrolling subtitle can cover the whole
			# narrow gun at UI150, leaving an unstable handful of edge pixels.
			# Require a substantive 100-pixel sample in the supplemental view
			# instead of grading an almost fully occluded silhouette. Keep the
			# full-UI screenshot, and separately
			# prove actual composition with only the occluding HUD hidden.
			# Image readback may cross the authority's unchanged input TTL. Use
			# the same late-frame user click path as the primary capture.
			for attempt: int in range(4):
				root.grab_focus()
				capture_click.pending = true
				await capture_click.applied
				session.campaign_hud.hide()
				await RenderingServer.frame_post_draw
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and session.can_capture_pointer() and session.first_person.rig.showing: break
			require(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and session.can_capture_pointer() and session.first_person.rig.showing, name + ": supplemental capture remains input-eligible")
			var proof := root.get_texture().get_image()
			var proof_weapon: Image = session.first_person.rig.viewport.get_texture().get_image()
			var proof_pixels := compare_weapon_pixels(proof, proof_weapon, false)
			session.campaign_hud.show()
			require(proof.save_png(output.path_join(name + "-weapon-proof.png")) == OK, "Save supplemental weapon composition proof")
			require(proof_pixels.opaque > 100 and proof_pixels.matched > proof_pixels.opaque * 0.8, name + ": HUD-free supplemental weapon composition")
			rig_pixels["supplemental"] = proof_pixels
		else:
			require(rig_pixels.opaque > 10 and rig_pixels.matched > rig_pixels.opaque * 0.8, name + ": rendered weapon pixels must appear in final screenshot")
	var path := output.path_join(name + ".png")
	require(image.save_png(path) == OK, "Could not save " + path)
	var expected := Vector2i(760,520) if profile == "compact" else Vector2i(1280,800)
	require(image.get_size() == expected, name + ": physical capture dimensions differ from requested profile")
	captures.append({"scenario":name,"scripted":true,"path":path,"map":session.current_id,"profile":profile,
		"rigPixels":rig_pixels,
		"explicitCaptureAttempts":attempts,"drawMs":draw_ms,"inputBoundaries":input_boundaries.duplicate(true),
		"lighting":lighting,
		"camera":[session.camera.position.x,session.camera.position.y,session.camera.position.z],"yaw":session.yaw,"pitch":session.pitch,
		"focused":session.application_focused,"windowFocused":root.has_focus(),"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"eligible":session.can_capture_pointer(),
		"physicalSize":[image.get_width(),image.get_height()],"logicalSize":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],
		"uiScale":settings.values.ui_scale,"phase":session.phase,"campaignPhase":session.campaign.state.get("phase", "briefing"),
		"starts":session.round_starts,"epoch":session.client.input_epoch,"acks":session.client.last_ack,
		"robotsInFrustum":robot_count,"groundRingsInFrustum":rings,"widgets":widgets,"newFailures":failures.size()-before})

func compare_weapon_pixels(image: Image, weapon: Image, mask_hud: bool) -> Dictionary:
	var result := {"opaque":0,"matched":0,"occluded":0}
	# CPU resizing and the GPU TextureRect sampler differ at subpixel edges.
	# Match within one physical pixel, retaining the color and 80% coverage gates.
	if weapon.get_size() != image.get_size(): weapon.resize(image.get_width(), image.get_height(), Image.INTERPOLATE_BILINEAR)
	for y: int in range(1, weapon.get_height() - 1, 2):
		for x: int in range(1, weapon.get_width() - 1, 2):
			var pixel := weapon.get_pixel(x, y)
			if pixel.a < 0.99: continue
			var logical := Vector2(x, y) * root.get_visible_rect().size / Vector2(image.get_size())
			if logical.y >= root.get_visible_rect().size.y - 40 or (mask_hud and session.campaign_hud.bottom.get_global_rect().grow(2).has_point(logical)):
				result.occluded += 1
				continue
			result.opaque += 1
			var matched := false
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var actual := image.get_pixel(x + dx, y + dy)
					if absf(pixel.r - actual.r) + absf(pixel.g - actual.g) + absf(pixel.b - actual.b) < 0.12: matched = true
			if matched: result.matched += 1
	return result

static func world_lights(tree_root: Node, target: World3D) -> Dictionary:
	var census := {"environments":[],"suns":[],"separateWorlds":[],"unresolved":[]}
	for kind: String in ["WorldEnvironment", "DirectionalLight3D"]:
		for node: Node in tree_root.find_children("*", kind, true, false):
			var viewport := node.get_viewport()
			var world: World3D = viewport.find_world_3d() if viewport != null else null
			if world == null or target == null:
				census.unresolved.append(str(node.get_path()))
			elif world == target:
				census["environments" if kind == "WorldEnvironment" else "suns"].append(node)
			else:
				# A name/path is not an exemption. Only a proven different effective
				# World3D may be excluded (e.g. the isolated first-person SubViewport).
				census.separateWorlds.append({"node":str(node.get_path()),"kind":kind,
					"worldID":world.get_instance_id(),"viewport":str(viewport.get_path()),
					"ownWorld":viewport is SubViewport and viewport.own_world_3d})
	return census

func inspect_lighting(stage_name: String) -> Dictionary:
	var target: World3D = session.camera.get_world_3d()
	var census := world_lights(root, target)
	var environments: Array = census.environments
	var suns: Array = census.suns
	require(census.unresolved.is_empty(), stage_name + ": all lighting must have a resolved effective World3D")
	require(environments.size() == 1 and suns.size() == 1, stage_name + ": exactly one persistent campaign sky and sun required")
	if environments.size() != 1 or suns.size() != 1: return {"environments":environments.size(),"suns":suns.size(),"separateWorlds":census.separateWorlds}
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
	return {"environments":1,"suns":1,"worldID":target.get_instance_id(),"separateWorlds":census.separateWorlds,"instanceIDs":identity,"sunEnergy":sun.light_energy,"shadows":sun.shadow_enabled,
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
