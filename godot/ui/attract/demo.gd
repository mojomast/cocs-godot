extends SubViewportContainer
## Silent, cosmetic in-engine menu replay. No session, authority, AI or input.
## Only a cropped patch of one packaged campaign chapter exists at a time.
const Operator = preload("res://source_operators/operator_visual.gd")
const Robot = preload("res://campaign/robot_visual.gd")
const Daylight = preload("res://campaign/environment.gd")
const StoryDirector = preload("res://campaign/story_director.gd")
const CHAPTERS := ["rootfall-verge", "siltwake-crossing", "emberline-ascent", "crown-array"]
const REPLAY_PATH := "res://ui/attract/demo.json"
const MAX_REPLAY_BYTES := 8 * 1024 * 1024
const PATCH_RADIUS := 44.0
const MAX_TRIANGLES := 3200
const FRAME_INTERVAL := 1.0 / 18.0

var mock_scene := false # Headless contract: exercise lifecycle without building GPU geometry.
var active := false
var building := false
var scene_ready := false
var chapter_index := -1
var chapter_time := 0.0
var frame_time := 0.0
var frame_index := 0
var clips: Array = []
var replay_checked := false
var world: Node3D
var camera: Camera3D
var viewport: SubViewport
var actors: Dictionary = {}
var story_director: Node3D
var flash: MeshInstance3D
var flash_light: OmniLight3D
var marker: Vector3
var forward: Vector3
var generation := 0
var terrain_triangles := 0
var flash_until := -1.0
var flash_origin := Vector3.ZERO
var last_event_frame := -1

func _ready() -> void:
	name = "AttractStage"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	stretch = true
	resized.connect(_resize_viewport)
	viewport = SubViewport.new()
	viewport.name = "AttractViewport"
	viewport.own_world_3d = true
	viewport.physics_object_picking = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	_resize_viewport()
	set_process(false)

func _resize_viewport() -> void:
	# The container stretches the image; internal rendering never exceeds 960x540.
	stretch_shrink = maxi(1, ceili(maxf(size.x / 960.0, size.y / 540.0)))

func start() -> void:
	if active: return
	if not mock_scene and not _load_replay(): return
	active = true
	show()
	if world != null: world.process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	if chapter_index < 0: advance_chapter()
	if not mock_scene: viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _load_replay() -> bool:
	if replay_checked: return not clips.is_empty()
	replay_checked = true
	if not FileAccess.file_exists(REPLAY_PATH):
		print("MENU_ATTRACT unavailable: ", REPLAY_PATH)
		return false
	var file := FileAccess.open(REPLAY_PATH, FileAccess.READ)
	if file == null: return false
	var length := file.get_length()
	if length < 20 or length > MAX_REPLAY_BYTES:
		file.close()
		return false
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary or data.get("version") != 1 or data.get("fps") != 12 or not data.get("clips") is Array:
		return false
	if not data.get("provenance") is Dictionary: return false
	if data.provenance.get("scripted") != true or not data.provenance.get("authorityRevision") is String:
		return false
	var entries: Array = data.clips
	if entries.is_empty() or entries.size() > 12: return false
	for clip: Variant in entries:
		if not _valid_clip(clip):
			clips.clear()
			return false
		clips.append(clip)
	return true

static func _valid_clip(clip: Variant) -> bool:
	if not clip is Dictionary: return false
	if clip.get("map") not in CHAPTERS or clip.get("camera") not in ["orbit", "fp"]: return false
	if not clip.get("id") is String or not clip.get("kind") is String: return false
	if not clip.get("focus") is Dictionary or not clip.get("frames") is Array: return false
	for axis: String in ["x", "y", "z"]:
		if not _finite_number(clip.focus.get(axis)): return false
	if not _finite_number(clip.get("duration")) or float(clip.duration) <= 0 or float(clip.duration) > 40: return false
	var frames: Array = clip.frames
	if frames.size() < 2 or frames.size() > 480: return false
	var last := -1.0
	for frame: Variant in frames:
		if not frame is Dictionary or not _finite_number(frame.get("t")) or not frame.get("state") is Dictionary or not frame.get("events") is Array: return false
		if float(frame.t) < 0 or float(frame.t) < last or float(frame.t) > float(clip.duration) or frame.events.size() > 48: return false
		if not frame.state.get("actors") is Array or not frame.state.get("campaign") is Dictionary or frame.state.actors.size() > 24: return false
		for actor: Variant in frame.state.actors:
			if not actor is Dictionary or not actor.get("id") is float and not actor.get("id") is int: return false
			for axis: String in ["x", "y", "z"]:
				if not _finite_number(actor.get(axis)): return false
		for event: Variant in frame.events:
			if not event is Dictionary: return false
		var story: Variant = frame.state.campaign.get("story")
		if story == null: story = {}
		if not story is Dictionary or not story.get("entities", []) is Array or story.get("entities", []).size() > 12: return false
		for entity: Variant in story.get("entities", []):
			if not entity is Dictionary or not entity.get("id") is String: return false
			if entity.get("kind") not in ["operator", "puppy"]: return false
			for axis: String in ["x", "y", "z", "yaw"]:
				if not _finite_number(entity.get(axis)): return false
		last = float(frame.t)
	return true

static func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(value))

func stop() -> void:
	if not active: return
	active = false
	set_process(false)
	if viewport != null: viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if world != null: world.process_mode = Node.PROCESS_MODE_DISABLED
	if building:
		# A settings/focus interruption during incremental construction must not
		# resume an abandoned half-built chapter on a later menu frame.
		generation += 1
		clear_chapter()
		chapter_index = -1
	hide()

func _exit_tree() -> void:
	stop()
	generation += 1
	clear_chapter()

func clear_chapter() -> void:
	if world != null:
		world.free()
		world = null
	actors.clear()
	story_director = null
	flash = null
	flash_light = null
	camera = null
	terrain_triangles = 0
	flash_until = -1.0
	last_event_frame = -1
	building = false
	scene_ready = false

func advance_chapter() -> void:
	generation += 1
	chapter_index = (chapter_index + 1) % maxi(1, clips.size())
	chapter_time = 0.0
	frame_time = 0.0
	frame_index = 0
	clear_chapter()
	if mock_scene:
		scene_ready = true
		return
	building = true
	_build_chapter.call_deferred(generation)

func _build_chapter(serial: int) -> void:
	if not active or serial != generation: return
	var clip: Dictionary = clips[chapter_index]
	var id: String = str(clip.map)
	var path := "res://campaign/generated/" + id + ".json"
	if not FileAccess.file_exists(path):
		print("MENU_ATTRACT unavailable: ", path)
		clips.clear()
		stop()
		return
	var recipe: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not recipe is Dictionary or recipe.get("id") != id:
		print("MENU_ATTRACT unavailable: ", path)
		clips.clear()
		stop()
		return
	var focus: Dictionary = clip.focus
	marker = Vector3(float(focus.x), float(focus.y), float(focus.z))
	var route: Array = recipe.campaign.criticalPath
	var next: Dictionary = route[mini(15, route.size() - 1)]
	forward = Vector3(float(next.x) - marker.x, 0, float(next.z) - marker.z).normalized()
	if forward.length_squared() < 0.01: forward = Vector3.FORWARD
	world = Node3D.new()
	world.name = "Chapter_" + id
	viewport.add_child(world)
	var environment := Daylight.new()
	world.add_child(environment)
	if not environment.build(recipe):
		print("MENU_ATTRACT unavailable: daylight ", id)
		clips.clear()
		stop()
		clear_chapter()
		return
	environment.sun.shadow_enabled = false
	camera = Camera3D.new()
	camera.far = 145
	camera.fov = 64
	world.add_child(camera)
	camera.make_current()
	# Source terrain triangles, cropped near the cast; mesh construction yields
	# periodically so the menu's foreground input remains responsive.
	await _build_terrain(recipe, serial)
	if not active or serial != generation: return
	if terrain_triangles == 0:
		print("MENU_ATTRACT unavailable: no campaign terrain near replay focus for ", id)
		clips.clear()
		stop()
		return
	_build_nearby_cover(recipe)
	_build_cast()
	building = false
	scene_ready = true
	_apply_frame(clip.frames[0], clip.frames[1], 0.0)
	_consume_events(clip.frames[0], 0)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _build_terrain(recipe: Dictionary, serial: int) -> void:
	var palette: Array = recipe.palette
	var colors := {"ground":0,"trail":1,"rock":2,"stone":3,"metal":4,"light":5}
	var materials := {}
	for key: String in colors:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(str(palette[colors[key]]))
		material.roughness = 0.82
		materials[key] = material
	for surface: Dictionary in recipe.arena.terrain.surfaces:
		if serial != generation or not active or terrain_triangles >= MAX_TRIANGLES: return
		var vertices: Array = surface.vertices
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var count := 0
		for triangle: Array in surface.triangles:
			var a: Array = vertices[int(triangle[0])]
			var b: Array = vertices[int(triangle[1])]
			var c: Array = vertices[int(triangle[2])]
			var center := Vector2((float(a[0]) + float(b[0]) + float(c[0])) / 3.0,
				(float(a[2]) + float(b[2]) + float(c[2])) / 3.0)
			if center.distance_to(Vector2(marker.x, marker.z)) > PATCH_RADIUS: continue
			var p := Vector3(float(a[0]), float(a[1]), float(a[2]))
			var q := Vector3(float(b[0]), float(b[1]), float(b[2]))
			var r := Vector3(float(c[0]), float(c[1]), float(c[2]))
			var normal := (q - p).cross(r - p).normalized()
			for point: Vector3 in [p, r, q]:
				tool.set_normal(normal)
				tool.add_vertex(point)
			count += 1
			terrain_triangles += 1
			if count % 320 == 0:
				await get_tree().process_frame
				if serial != generation or not active: return
			if terrain_triangles >= MAX_TRIANGLES: break
		if count > 0 and serial == generation and active:
			var mesh := MeshInstance3D.new()
			mesh.mesh = tool.commit()
			mesh.material_override = materials.get(str(surface.material), materials.ground)
			world.add_child(mesh)
		await get_tree().process_frame

func _build_nearby_cover(recipe: Dictionary) -> void:
	var palette: Array = recipe.palette
	var count := 0
	for block: Dictionary in recipe.arena.blocks:
		if count >= 36: break
		var center := Vector2(float(block.get("x", 0)), float(block.get("z", 0)))
		if center.distance_to(Vector2(marker.x, marker.z)) > PATCH_RADIUS - 4.0: continue
		var height := float(block.get("h", 0))
		if height <= 0: continue
		var box := BoxMesh.new()
		box.size = Vector3(maxf(0.2, float(block.get("w", 1))), height, maxf(0.2, float(block.get("d", 1))))
		var mesh := MeshInstance3D.new()
		mesh.name = "CampaignCover"
		mesh.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(str(palette[4 if block.get("material") == "metal" else 3]))
		mesh.material_override = material
		mesh.position = Vector3(center.x, float(block.get("baseY", 0)) + height * 0.5, center.y)
		world.add_child(mesh)
		count += 1

func _build_cast() -> void:
	# The production director owns Mara, Ivo and Patch, including their authored
	# pose/reaction changes. No companion-only substitute that drops the NPCs.
	story_director = StoryDirector.new()
	world.add_child(story_director)
	flash = MeshInstance3D.new()
	flash.name = "ScriptedMuzzleFlash"
	var ball := SphereMesh.new()
	ball.radius = 0.25
	ball.height = 0.5
	flash.mesh = ball
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("ffad54")
	flash.material_override = glow
	world.add_child(flash)
	flash_light = OmniLight3D.new()
	flash_light.light_color = Color("ffb56f")
	flash_light.omni_range = 5.0
	flash_light.shadow_enabled = false
	world.add_child(flash_light)
	flash.hide()
	flash_light.hide()

func _process(delta: float) -> void:
	if not active or not scene_ready: return
	chapter_time += minf(delta, 0.1)
	if mock_scene: return
	var clip: Dictionary = clips[chapter_index]
	if chapter_time >= float(clip.duration):
		advance_chapter()
		return
	var frames: Array = clip.frames
	while frame_index + 1 < frames.size() and float(frames[frame_index + 1].t) <= chapter_time:
		frame_index += 1
		_consume_events(frames[frame_index], frame_index)
	var current: Dictionary = frames[frame_index]
	var following: Dictionary = frames[mini(frame_index + 1, frames.size() - 1)]
	var span := maxf(0.001, float(following.t) - float(current.t))
	_apply_frame(current, following, clampf((chapter_time - float(current.t)) / span, 0, 1))
	frame_time += delta
	if frame_time >= FRAME_INTERVAL:
		frame_time = fmod(frame_time, FRAME_INTERVAL)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _consume_events(frame: Dictionary, index: int) -> void:
	if index <= last_event_frame: return
	last_event_frame = index
	# The frame's event array is already aggregated by the capture exporter.
	# Select one authored event, once, and place the cosmetic flash at its
	# recorded point or its actual source actor; never synthesize a player shot
	# just because a remote actor took damage.
	for event: Dictionary in frame.events:
		var kind := str(event.get("type", ""))
		if kind not in ["shot", "fire", "projectile", "impact", "hit", "npc-attack"]: continue
		var point: Variant = event.get("pos", event.get("origin"))
		if point is Dictionary and _finite_number(point.get("x")) and _finite_number(point.get("y")) and _finite_number(point.get("z")):
			flash_origin = Vector3(float(point.x), float(point.y), float(point.z))
		elif _finite_number(event.get("x")) and _finite_number(event.get("y")) and _finite_number(event.get("z")):
			flash_origin = Vector3(float(event.x), float(event.y), float(event.z))
		else:
			var owner: Node3D = actors.get(int(event.get("actor", event.get("sourceActor", -1))))
			if owner == null: continue
			flash_origin = owner.position - owner.global_basis.z * 0.7
		flash_until = float(frame.t) + 0.12
		break

func _apply_frame(current: Dictionary, following: Dictionary, weight: float) -> void:
	var now: Dictionary = current.state
	var future: Dictionary = following.state
	var future_actors := {}
	for candidate: Dictionary in future.actors: future_actors[int(candidate.get("id", -1))] = candidate
	var present := {}
	var focus_actor: Node3D
	var focus_snapshot: Dictionary = {}
	for actor: Dictionary in now.actors:
		if not actor.get("x") is float and not actor.get("x") is int: continue
		var id := int(actor.get("id", -1))
		if id < 0 or present.size() >= 12: continue
		present[id] = true
		var visual: Node3D = actors.get(id)
		if visual == null:
			visual = Robot.new() if str(actor.get("npcModel", "")) in Robot.IDS else Operator.new()
			visual.name = "ReplayActor_%d" % id
			world.add_child(visual)
			actors[id] = visual
		visual.call("apply_actor", actor)
		if visual is Robot: visual.call("set_lod", 1)
		var next: Dictionary = future_actors.get(id, actor)
		var origin := Vector3(float(actor.get("x", 0)), float(actor.get("y", 0)), float(actor.get("z", 0)))
		var destination := Vector3(float(next.get("x", origin.x)), float(next.get("y", origin.y)), float(next.get("z", origin.z)))
		# Shared world/presentation.gd places source and robot roots 0.9 above
		# authoritative feet; story operators are offset by their director too.
		visual.position = origin.lerp(destination, weight) + Vector3.UP * 0.9
		visual.rotation.y = lerp_angle(float(actor.get("bodyYaw", actor.get("yaw", 0))), float(next.get("bodyYaw", next.get("yaw", 0))), weight)
		if visual is Operator and float(actor.get("health", 0)) > 0 and (focus_actor == null or id == 0):
			focus_actor = visual
			focus_snapshot = actor
	for id: int in actors.keys():
		if present.has(id): continue
		actors[id].free()
		actors.erase(id)
	var story: Variant = now.campaign.get("story")
	story_director.call("apply", story if story is Dictionary else {}, str(clips[chapter_index].map))
	flash.visible = chapter_time < flash_until
	flash_light.visible = flash.visible
	if flash.visible:
		flash.position = flash_origin
		flash_light.position = flash.position
	var clip: Dictionary = clips[chapter_index]
	var subject: Vector3 = focus_actor.position if focus_actor != null else marker
	var side := Vector3(-forward.z, 0, forward.x)
	var orbit := chapter_time * 0.18
	var eye := subject - forward * (9.0 + 2.0 * sin(orbit)) + side * (7.0 + 3.0 * cos(orbit)) + Vector3.UP * 5.0
	if clip.camera == "fp" and focus_actor != null:
		# Same eye-height and yaw/pitch convention as the real campaign session.
		# Hide only this local body in FP; all other models remain in the shot.
		focus_actor.hide()
		camera.position = subject - Vector3.UP * 0.9 + Vector3.UP * float(focus_snapshot.get("eyeHeight", 1.45))
		camera.rotation_order = EULER_ORDER_YXZ
		camera.rotation = Vector3(float(focus_snapshot.get("pitch", 0)), float(focus_snapshot.get("yaw", 0)), 0)
	else:
		camera.position = eye
		camera.look_at(subject + forward * 2.5 + Vector3.UP * 0.8)
