extends Node
## Cosmetic only: isolated transparent world, source snapshots/events, no input/aim writes.
##
## Sole final pose compositor: every layer below (aim, switch, slide, inertia,
## recoil, transient punch, reload, the sampled mechanism offset and the kick
## leg) is composed here, and every authored number it composes with is owned by
## the shared, immutable `WeaponPresentationProfile` for the held source weapon.
## Runtime state (recoil, punch, kick age, reload progress) stays on this
## instance; the profile holds none of it.
const Catalog = preload("res://first_person/generated/catalog.gd")
const Profile = preload("res://first_person/profiles/weapon_presentation_profile.gd")
const Handling = preload("res://first_person/handling.gd")
const Finish = preload("res://first_person/finish.gd")
const Art = preload("res://first_person/art_adapter.gd")
const Inertia = preload("res://first_person/inertia.gd")
const Spring = preload("res://animation/critical_spring.gd")
const KickMotion = preload("res://first_person/kick_motion.gd")
const KickRig = preload("res://first_person/kick_rig.gd")
var kick_motion := KickMotion.new()
var inertia := Inertia.new()
var punch_spring := Spring.new()
const MAX_SEEN := 4096
## The sampled mechanism pilot's clip lives in the rig's own `mechanism`
## library; a profile names it (or names nothing and stays procedural).
const MECHANISM_LIBRARY := "mechanism"
const MECHANISM_CLIP := "reload_hardware"
var source_camera: Camera3D
var viewport: SubViewport
var overlay: CanvasLayer
var image: TextureRect
var weapon_camera: Camera3D
var pivot: Node3D
var weapon: Node3D
var hands: Node3D
var flash: Node3D
var kick_leg: Node3D
## Sampled-animation pilot (F05). `mechanism` is a disjoint offset node parented
## to the live weapon: it carries the clip's hardware offset and nothing else,
## so aim, recoil and inertia keep their own procedural channels.
var mechanism: Node3D
var mechanism_player: AnimationPlayer
var mechanism_clip := ""
var mechanism_active := false
var mechanism_cancel := ""
var mechanism_plays := 0
const KICK_SECONDS := KickMotion.DURATION
var kick_age := KICK_SECONDS
var kick_count := 0
var manifest: Dictionary = {}
var scenes: Dictionary = {}
var current_weapon := -1
var actor_id := -1
var showing := false
var reduced_motion := false
var flight_mode := false # Public soloCheats.flight presentation gate.
var speed := 0.0
var slide_target := 0.0
var slide_weight := 0.0
var reloading := false
var reload_progress := 0.0
var recoil := 0.0
# Transient camera punch: a sharp, fast-decaying weapon-pose jolt layered over
# the sustained source-rate recoil. Presentation only, bounded and reset by
# `_clear_motion()`; it never touches the aim camera or any gameplay value.
var punch := 0.0
var punch_sign := 1.0
# Last applied pose response, read by the recoil evidence test. Metres for the
# shove, radians for lift/roll; presentation only.
var kick_shove := 0.0
var kick_lift := 0.0
var kick_roll := 0.0
var flash_remaining := 0.0
var switch_remaining := 0.0
var age := 0.0
var look_lag := Vector2.ZERO
var recoil_count := 0
var build_count := 0
var seen: Dictionary = {}
var event_order: Array[String] = []
var expired_time := -INF
var parts: Dictionary = {}
var rest: Dictionary = {}
var _attached := false
var aim_requested := false
var aim_target := 0.0
var aim_weight := 0.0
var aim_blocked := false
var external_muzzle_fx := false
var anchors: Dictionary = {}
var wrists: Dictionary = {}
var forearms: Dictionary = {}
var elbows: Dictionary = {}
var ads_pose := Transform3D.IDENTITY
var presentation: Dictionary = {}
var handling := Handling.new()
var finish := Finish.new()
## The shared, immutable presentation profile for the held source weapon. Unknown
## source weapons resolve to the documented default, i.e. current behaviour.
var profile: WeaponPresentationProfile = Profile.default_for_weapon()
# Pose/ADS and compose bounds resolved from `profile` on weapon select, so the
# per-frame compositor reads plain floats instead of chasing tables.
var _hip_offset := Vector3(0.29, -0.26, -0.75)
var _switch_seconds := 0.22
var _switch_drop := 0.0704
var _slide_offset := Vector3(0.018, -0.025, 0.0)
var _slide_roll := 0.08
var _slide_rate := 12.0
var _reload_window := Vector3(0.22, 0.72, 1.0)
var _reload_drop := 0.045
var _reload_roll := 0.16
var _hand_window := Vector4(0.04, 0.22, 0.78, 0.96)
var _shove_scale := 0.45
var _lift_scale := 0.6
var _lift_scale_reduced := 0.28
var _punch_reduced := 0.35
var _punch_rate_scale := 1.5
var _punch_limit := 1.25
var _recoil_cap := 1.5
var _look_lag_rate := 12.0
var _mechanism_reduced := 0.5
var _sight_rear := "SightRear"
var _sight_front := "SightFront"
var _sight_optic := "OpticCenter"

func attach_to(camera: Camera3D) -> void:
	assert(is_inside_tree(), "Add the rig to the session before attach_to")
	source_camera = camera
	if _attached: return
	_attached = true
	manifest = {"weapons": Catalog.WEAPONS}
	viewport = SubViewport.new()
	viewport.name = "FirstPersonOnly"
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.gui_disable_input = true
	add_child(viewport)
	weapon_camera = Camera3D.new()
	weapon_camera.near = 0.025
	weapon_camera.far = 8.0
	viewport.add_child(weapon_camera)
	weapon_camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b8d3ea")
	environment.environment.ambient_light_energy = 0.65
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	viewport.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, -35, 0)
	key.light_color = Color("fff0db")
	key.light_energy = 1.8
	viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(25, 145, 0)
	rim.light_color = Color("8dc9ec")
	rim.light_energy = 1.1
	viewport.add_child(rim)
	pivot = Node3D.new()
	pivot.name = "WeaponPose"
	viewport.add_child(pivot)
	hands = Node3D.new()
	hands.name = "ArmsRig"
	pivot.add_child(hands)
	_build_hands()
	flash = Node3D.new()
	flash.name = "BarrelFlash"
	pivot.add_child(flash)
	flash.hide()
	_build_kick_leg()
	_build_mechanism()
	# Handling FX (heat haze/smoke at the authored HeatZone) live beside the
	# pivot: they must not add weapon mesh instances or pivot children.
	handling.configure(viewport)
	overlay = CanvasLayer.new()
	overlay.layer = 0 # World overlay; existing HUD CanvasLayers use 1 and above.
	add_child(overlay)
	image = TextureRect.new()
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture = viewport.get_texture()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.add_child(image)
	overlay.hide()
	_sync_camera()

static func number(value: Variant, fallback: float = 0.0) -> float:
	return float(value) if (value is int or value is float) and is_finite(float(value)) else fallback

static func identity(value: Variant) -> int:
	var n := number(value, -1)
	return int(n) if n >= 0 and n == floor(n) else -1

func apply_actor(actor: Dictionary, can_show: bool) -> void:
	if not _attached: return
	var next_id := identity(actor.get("id"))
	var id := identity(actor.get("weapon"))
	var eligible := can_show and next_id >= 0 and id < 10 and id >= 0 and number(actor.get("health")) > 0 and not bool(actor.get("dead", false)) and not bool(actor.get("spectating", false)) and actor.get("vehicleId") == null
	if next_id != actor_id:
		_clear_motion()
		actor_id = next_id
	if eligible and id != current_weapon: _select_weapon(id)
	if showing and not eligible: _clear_motion()
	finish.apply(actor.get("finish") if eligible else null)
	if eligible: kick_leg.apply_identity(actor)
	showing = eligible
	overlay.visible = eligible
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if eligible else SubViewport.UPDATE_DISABLED
	if eligible: inertia.observe(actor, source_camera.global_basis, flight_mode)
	speed = minf(12.0, Vector2(number(actor.get("vx")), number(actor.get("vz"))).length()) if eligible and actor.get("grounded", true) != false else 0.0
	reloading = eligible and actor.get("reloading", false) == true
	slide_target = 1.0 if eligible and actor.get("sliding", false) == true else 0.0
	aim_blocked = reloading or actor.get("sprinting", false) == true or number(actor.get("weaponSwitch")) > 0.0
	if aim_blocked: interrupt_kick()
	if aim_blocked:
		aim_requested = false
		aim_target = 0.0
	var duration := number(actor.get("reloadDuration"))
	reload_progress = clampf(1.0 - number(actor.get("reloadTimer"), duration) / duration, 0.0, 1.0) if reloading and duration > 0 else 0.0
	# Sampled pilot ownership: the clip only ever runs inside the authoritative
	# reload window, and sprint or a weapon switch cancels it explicitly. Nothing
	# here writes source state.
	var window_open: bool = reloading and reload_progress > 0.0 and reload_progress < 1.0
	if not window_open:
		cancel_mechanism("source reload window closed")
	elif actor.get("sprinting", false) == true or number(actor.get("weaponSwitch")) > 0.0:
		cancel_mechanism("source posture blocks aim")
	else:
		_arm_mechanism()

func apply_aim(active: bool, weight: float = 1.0) -> bool:
	aim_requested = active and showing and not aim_blocked and kick_motion.age >= KICK_SECONDS and is_finite(weight) and weight > 0.0
	aim_target = clampf(weight, 0.0, 1.0) if aim_requested else 0.0
	return aim_requested

func get_aim_state(base_fov: float = 75.0) -> Dictionary:
	var base := clampf(number(base_fov, 75.0), 30.0, 130.0)
	var info: Dictionary = manifest.weapons[current_weapon].ads if current_weapon >= 0 else {}
	var mag := float(info.get("magnification", 1.0))
	var target_fov := maxf(55.0, base * 0.82) if mag <= 1.0001 else maxf(12.0, minf(base, rad_to_deg(2.0 * atan(tan(deg_to_rad(base) * 0.5) / mag))))
	return {"active": aim_requested, "weight": aim_weight, "ready": showing and aim_requested and not reloading and switch_remaining <= 0.0 and aim_weight >= 0.98, "kind": info.get("kind", "iron"), "magnification": mag, "fov": lerpf(base, target_fov, aim_weight)}

func get_muzzle_count() -> int:
	return manifest.weapons[current_weapon].muzzles.size() if showing and current_weapon >= 0 else 0

func get_muzzle_world_transform(index: int = 0) -> Transform3D:
	if index < 0 or index >= get_muzzle_count() or not is_instance_valid(source_camera): return Transform3D.IDENTITY
	# Camera transform includes Camera3D h/v offsets. Both cameras share projection.
	return source_camera.get_camera_transform() * weapon_camera.get_camera_transform().affine_inverse() * anchors["Muzzle%d" % index].global_transform

func get_muzzle_screen_position(index: int = 0) -> Vector2:
	if index < 0 or index >= get_muzzle_count(): return Vector2(INF, INF)
	return weapon_camera.unproject_position(anchors["Muzzle%d" % index].global_position)

func get_sight_screen_positions() -> Dictionary:
	if not showing: return {}
	return {"rear": weapon_camera.unproject_position(_corridor_anchor(_sight_rear).global_position), "front": weapon_camera.unproject_position(_corridor_anchor(_sight_front).global_position), "optic": weapon_camera.unproject_position(_corridor_anchor(_sight_optic).global_position)}

func apply_events(events: Array, local_id: int) -> void:
	# Consume hidden events as well, so unfocus/stale/death recovery cannot replay fire.
	for value: Variant in events:
		if not value is Dictionary: continue
		var event: Dictionary = value
		if event.get("type") not in ["shot", "launch", "melee"]: continue
		var id := identity(event.get("id"))
		var time := number(event.get("time"), -1)
		var owner := identity(event.get("actor"))
		# Melee has no weapon identity; changing the held gun must not make an
		# already-consumed source event look new when it is delivered again.
		var kind := identity(event.get("weapon")) if event.type != "melee" else -1
		if id < 0 or time < 0 or owner < 0 or (event.type != "melee" and (kind < 0 or kind >= 10)): continue
		var key := "%s/%d/%s/%d/%d" % [event.type, id, str(time), owner, kind]
		if time <= expired_time or seen.has(key): continue
		_remember(key, time)
		if event.type == "melee":
			# Only an accepted source melee event moves the foot. A denied repeat
			# during source cooldown never claims a hit or invents an extra attack.
			if showing and owner == local_id and owner == actor_id:
				if kick_motion.accept(event):
					kick_age = 0.0
					kick_count += 1
					aim_requested = false
					aim_target = 0.0
					cancel_mechanism("source melee")
			continue
		# One source trigger can produce 8/12 shot events. Explosive shrapnel is not fire.
		var volley := "volley/%d/%d/%s" % [owner, kind, str(time)]
		if event.has("shrapnel") or seen.has(volley): continue
		_remember(volley, time)
		if not showing or owner != local_id or owner != actor_id or kind != current_weapon: continue
		recoil = minf(_recoil_cap, recoil + 1.0)
		punch = minf(_punch_limit, punch + 1.0)
		punch_spring.value = punch
		punch_spring.velocity = 0.0
		punch_sign = -punch_sign
		flash_remaining = float(manifest.weapons[kind].muzzle[1])
		recoil_count += 1
		handling.fire()

func _remember(key: String, time: float) -> void:
	seen[key] = time
	event_order.append(key)
	if event_order.size() > MAX_SEEN:
		var old: String = event_order.pop_front()
		expired_time = maxf(expired_time, seen[old])
		seen.erase(old)

func apply_look_delta(radians: Vector2) -> void:
	if showing and radians.is_finite() and not reduced_motion:
		inertia.look(radians)

func _select_weapon(id: int) -> void:
	_clear_motion()
	if is_instance_valid(weapon):
		# Detach render surfaces before releasing their private material RIDs.
		# Godot 4.5 GLES/dummy backends otherwise query a freed override on rapid swaps.
		for node: MeshInstance3D in weapon.find_children("*", "MeshInstance3D"):
			node.mesh = null
		# The sampled offset node outlives the weapon it is riding.
		if mechanism.get_parent() != null: mechanism.get_parent().remove_child(mechanism)
		pivot.remove_child(weapon)
		weapon.free()
	parts.clear()
	rest.clear()
	anchors.clear()
	if not scenes.has(id): scenes[id] = load("res://first_person/generated/weapon-%d.glb" % id)
	weapon = scenes[id].instantiate()
	pivot.add_child(weapon)
	# The disjoint sampled track rides the live weapon, so its offset is authored
	# in weapon space and never overlaps a pivot-level aim/recoil channel.
	if mechanism.get_parent() != null: mechanism.get_parent().remove_child(mechanism)
	weapon.add_child(mechanism)
	mechanism.transform = Transform3D.IDENTITY
	mechanism_player.root_node = mechanism_player.get_path_to(mechanism)
	Art.install(weapon, id)
	# Imported resources are shared. Each rig gets immutable private surface overrides.
	for node: Node in weapon.find_children("*", "MeshInstance3D"):
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface: int in node.mesh.get_surface_count():
			var mat: Material = node.mesh.surface_get_material(surface)
			if mat != null: node.set_surface_override_material(surface, mat.duplicate())
	finish.bind(weapon)
	for name: String in ["feed", "barrel-assembly", "shock-emitter", "flak-barrel", "bolt"]:
		var part := weapon.find_child(name, true, false) as Node3D
		if part != null:
			parts[name] = part
			rest[name] = part.transform
	current_weapon = id
	presentation = manifest.weapons[id].get("presentation", {})
	for name: String in manifest.weapons[id].anchors:
		anchors[name] = weapon.find_child(name, true, false)
		assert(anchors[name] != null, "Missing exported anchor: " + name)
	# One profile per source weapon, shared and immutable: this rig, the handling
	# helper, the inertia helper and the sprint cue all read the same instance.
	_bind_profile(String(manifest.weapons[id].name))
	handling.bind(weapon, parts, rest, anchors, manifest.weapons[id], id)
	# Solve from the imported, actual sight nodes, rather than a shared ADS offset.
	var rear: Vector3 = pivot.to_local(_corridor_anchor(_sight_rear).global_position)
	var front: Vector3 = pivot.to_local(_corridor_anchor(_sight_front).global_position)
	var orientation := Basis(Quaternion((front - rear).normalized(), Vector3.FORWARD))
	var rotated_rear := orientation * rear
	ads_pose = Transform3D(orientation, Vector3(-rotated_rear.x, -rotated_rear.y, -float(manifest.weapons[id].ads.pose.distance)))
	build_count += 1
	switch_remaining = _switch_seconds
	for child: Node in flash.get_children(): child.free()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(manifest.weapons[id].color).lerp(Color.WHITE, 0.55)
	var mesh := SphereMesh.new()
	mesh.radius = float(manifest.weapons[id].muzzle[0]) * 0.55
	mesh.height = mesh.radius * 4.5
	mesh.radial_segments = 8
	mesh.rings = 4
	for index: int in manifest.weapons[id].muzzles.size():
		var flare := MeshInstance3D.new()
		flare.name = "MuzzleFlash%d" % index
		flare.mesh = mesh
		flare.material_override = material
		flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flash.add_child(flare)

## Resolve every authored bound this compositor uses from the shared profile for
## `weapon_name`, then hand the same instance to the helpers. Nothing is copied
## into a second table and no helper reads another's constants.
func _bind_profile(weapon_name: String) -> void:
	profile = Profile.for_weapon(weapon_name)
	_hip_offset = profile.hip_offset()
	_switch_seconds = profile.switch_seconds()
	_switch_drop = profile.switch_drop()
	_slide_offset = profile.slide_offset()
	_slide_roll = profile.slide_roll()
	_slide_rate = profile.slide_rate()
	_reload_window = profile.reload_window()
	_reload_drop = profile.reload_drop()
	_reload_roll = profile.reload_roll()
	_hand_window = profile.hand_window()
	_shove_scale = profile.shove_scale()
	_lift_scale = profile.lift_scale()
	_lift_scale_reduced = profile.lift_scale_reduced()
	_punch_reduced = profile.punch_reduced()
	_punch_rate_scale = profile.punch_rate_scale()
	_punch_limit = profile.punch_limit()
	_recoil_cap = profile.recoil_cap()
	_look_lag_rate = profile.look_lag_rate()
	_mechanism_reduced = profile.mechanism_reduced_scale()
	var corridor := profile.sight_corridor()
	_sight_rear = String(corridor.get("rear", "SightRear"))
	_sight_front = String(corridor.get("front", "SightFront"))
	_sight_optic = String(corridor.get("optic", "OpticCenter"))
	inertia.bind(profile)
	handling.bind_profile(profile)
	# The sampled pilot is profile-driven: a weapon with no authored clip stays
	# purely procedural and can never be sampled by accident.
	mechanism_clip = profile.clip("reload")
	if mechanism_clip.is_empty(): cancel_mechanism("no authored mechanism clip")

## The authored sight-corridor anchor for `name`. A profile that names an anchor
## the weapon did not export falls back to the exported defaults rather than
## reading a null station.
func _corridor_anchor(name: String) -> Node3D:
	for candidate: String in [name, _sight_rear, _sight_front, _sight_optic]:
		var node: Variant = anchors.get(candidate, null)
		if node is Node3D: return node
	return null

## The profile-resolved pose bounds this compositor is actually reading, for
## evidence and diagnostics. Read-only: it is a copy of resolved values, not a
## second source of truth.
func profile_pose() -> Dictionary:
	return {"hip_offset":_hip_offset, "switch_seconds":_switch_seconds, "switch_drop":_switch_drop,
		"slide_offset":_slide_offset, "slide_roll":_slide_roll, "slide_rate":_slide_rate,
		"reload_window":_reload_window, "reload_drop":_reload_drop, "reload_roll":_reload_roll,
		"hand_window":_hand_window, "shove_scale":_shove_scale, "lift_scale":_lift_scale,
		"lift_scale_reduced":_lift_scale_reduced, "punch_reduced":_punch_reduced,
		"punch_rate_scale":_punch_rate_scale, "punch_limit":_punch_limit, "recoil_cap":_recoil_cap,
		"look_lag_rate":_look_lag_rate, "mechanism_reduced":_mechanism_reduced,
		"sight_rear":_sight_rear, "sight_front":_sight_front, "sight_optic":_sight_optic}

## --- Sampled mechanism pilot (F05) -----------------------------------------
## One disjoint hardware/offset track whose playhead is the authoritative reload
## progress, read-only. The rig stays the sole compositor: the clip's offset is
## one more additive layer, it cannot gate, shorten or complete the reload, and
## it never touches ammunition, aim, recoil or inertia. Cancellation and RESET
## ownership are explicit: any source event that closes the reload window, a
## weapon switch, sprint, melee, death, focus loss or a round reset cancels and
## returns the node to rest.
func _build_mechanism() -> void:
	mechanism = Node3D.new()
	mechanism.name = "MechanismSample"
	add_child(mechanism)
	mechanism_player = AnimationPlayer.new()
	mechanism_player.name = "MechanismTrack"
	# Never free-runs: the playhead is only ever set from the source progress.
	mechanism_player.speed_scale = 0.0
	add_child(mechanism_player)
	var library := AnimationLibrary.new()
	library.add_animation(MECHANISM_CLIP, _reload_hardware_clip())
	mechanism_player.add_animation_library(MECHANISM_LIBRARY, library)

## The Pulse Rifle reload pilot clip, authored in *normalised source progress*
## (length 1.0 is the whole authoritative window) and holding only a small,
## bounded offset that is exactly zero at both window edges. Because the rig
## seeks it to the source progress every frame, the clip cannot shorten, gate or
## complete the reload; cancelling simply stops sampling and the rest pose is
## immediate.
func _reload_hardware_clip() -> Animation:
	var clip := Animation.new()
	clip.length = 1.0
	clip.loop_mode = Animation.LOOP_NONE
	var track := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(track, NodePath("."))
	clip.track_insert_key(track, 0.0, Vector3.ZERO)
	clip.track_insert_key(track, 0.18, Vector3(0.014, -0.048, 0.030))
	clip.track_insert_key(track, 0.55, Vector3(-0.008, -0.058, 0.012))
	clip.track_insert_key(track, 1.0, Vector3.ZERO)
	return clip

func _arm_mechanism() -> void:
	if mechanism_active: return
	if mechanism_clip.is_empty() or not is_instance_valid(mechanism_player): return
	if not mechanism_player.has_animation(mechanism_clip): return
	mechanism_active = true
	mechanism_cancel = ""
	mechanism_plays += 1
	mechanism_player.play(mechanism_clip)
	mechanism_player.pause()

## Explicit cancellation with RESET ownership: the clip stops driving the node and
## the node returns to its authored rest pose immediately.
func cancel_mechanism(reason: String) -> void:
	if not mechanism_active: return
	mechanism_active = false
	mechanism_cancel = reason
	if is_instance_valid(mechanism_player): mechanism_player.stop()
	if is_instance_valid(mechanism): mechanism.transform = Transform3D.IDENTITY

## The sampled offset the compositor would add right now. Read-only: it never
## moves the playhead, so a diagnostic read cannot perturb the replay.
func sampled_offset() -> Vector3:
	if not mechanism_active or not is_instance_valid(mechanism): return Vector3.ZERO
	if not reloading or reload_progress <= 0.0 or reload_progress >= 1.0: return Vector3.ZERO
	return mechanism.transform.origin * (_mechanism_reduced if reduced_motion else 1.0)

## Read-only replay at the source reload progress. `Vector3.ZERO` whenever the
## authoritative window is closed, so nothing can be sampled outside it.
func mechanism_offset() -> Vector3:
	if not mechanism_active or not is_instance_valid(mechanism) or not is_instance_valid(mechanism_player): return Vector3.ZERO
	if not reloading or reload_progress <= 0.0 or reload_progress >= 1.0: return Vector3.ZERO
	mechanism_player.seek(reload_progress, true)
	return sampled_offset()

## Pilot state for the focused evidence test. Presentation diagnostics only.
func get_mechanism_state() -> Dictionary:
	# A paused player reports no current animation, so the playhead is only read
	# while armed: cancelling clears the flag before the position is queried.
	var position := 0.0
	if mechanism_active and is_instance_valid(mechanism_player): position = mechanism_player.current_animation_position
	return {"armed":mechanism_active, "clip":mechanism_clip, "cancelled_by":mechanism_cancel,
		"plays":mechanism_plays, "position":position,
		"offset":mechanism.transform.origin if is_instance_valid(mechanism) else Vector3.ZERO,
		"applied":sampled_offset(),
		"playing":is_instance_valid(mechanism_player) and mechanism_player.is_playing(),
		"progress":reload_progress}

func _sync_camera() -> void:
	if not is_instance_valid(source_camera):
		if _attached: apply_actor({}, false)
		return
	var size := Vector2i(source_camera.get_viewport().get_visible_rect().size)
	if viewport.size != size: viewport.size = size.max(Vector2i(1, 1))
	weapon_camera.fov = source_camera.fov
	weapon_camera.keep_aspect = source_camera.keep_aspect
	weapon_camera.projection = source_camera.projection
	weapon_camera.size = source_camera.size
	weapon_camera.frustum_offset = source_camera.frustum_offset
	image.size = Vector2(size)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not _attached or not is_finite(delta) or delta < 0: return
	_sync_camera()
	if not showing: return
	var dt := delta
	age += dt
	var info: Dictionary = manifest.weapons[current_weapon]
	# Sustained recoil settles at ~78% of the source recover rate (noticeably
	# heavier) while the transient punch decays much faster.
	recoil = move_toward(recoil, 0.0, dt * handling.recover_speed)
	if punch > 0.0:
		punch = punch_spring.advance(dt, 0.0, handling.transient_rate * _punch_rate_scale, _punch_limit)
		if punch < 0.0005: punch = 0.0
	flash_remaining = maxf(0.0, flash_remaining - dt)
	switch_remaining = maxf(0.0, switch_remaining - dt)
	var target := aim_target if not reloading and switch_remaining <= 0.0 and kick_motion.age >= KICK_SECONDS else 0.0
	var rate := float(info.ads.enter if target > aim_weight else info.ads.exit)
	aim_weight = lerpf(aim_weight, target, 1.0 - exp(-dt * rate))
	if absf(aim_weight - target) < 0.00001: aim_weight = target
	look_lag *= exp(-dt * _look_lag_rate)
	var motion: Dictionary = inertia.advance(dt, reduced_motion)
	var heft_weight := profile.heft_weight_for(info.kick)
	# Lift/hold/seat rather than a symmetric sine: source progress still owns
	# the complete window and cancellation returns immediately to the grip.
	var reload_curve := smoothstep(0.0, _reload_window.x, reload_progress) * (1.0 - smoothstep(_reload_window.y, _reload_window.z, reload_progress)) if reloading else 0.0
	# Keep the receiver below/right in hip fire, but align the *barrel axis*
	# with the source camera ray. The old 0.22-rad yaw made the visible gun
	# point off the crosshair even though source shots used the correct ray.
	var hip := Transform3D(ads_pose.basis, _hip_offset)
	pivot.transform = hip.interpolate_with(ads_pose, aim_weight)
	# Keep settled neutral sights exactly on the camera ray. Recoil is deliberately
	# visible, then recovers; idle/locomotion/lag fade out as cheek weld completes.
	var free_motion := 1.0 - aim_weight
	# Small weapon-only slide cant; settled sights and camera retain their ray.
	slide_weight = 0.0 if reduced_motion else lerpf(slide_weight, slide_target, 1.0 - exp(-dt * _slide_rate))
	var slide_pose := slide_weight * free_motion
	pivot.position += _slide_offset * slide_pose
	pivot.basis *= Basis.from_euler(Vector3(0.0, 0.0, _slide_roll * slide_pose))
	# Weapon-oomph recoil: the source kick is amplified per weapon (heavier source
	# feel -> stronger multiplier) with a fast transient punch layered on top.
	# Reduced motion keeps a visible but small punch and never the full jolt.
	var punch_weight := punch * (_punch_reduced if reduced_motion else 1.0)
	var shove := recoil * float(info.kick[0]) * _shove_scale * handling.kick_scale + punch_weight * float(info.kick[0]) * handling.transient_back
	var lift := recoil * float(info.kick[1]) * handling.lift_hold * (_lift_scale_reduced if reduced_motion else _lift_scale) + punch_weight * float(info.kick[1]) * handling.transient_pitch
	var roll := punch_weight * float(info.kick[1]) * handling.transient_roll * punch_sign
	kick_shove = shove
	kick_lift = lift
	kick_roll = roll
	var switch_drop := smoothstep(0.0, 1.0, switch_remaining / _switch_seconds) * _switch_drop
	pivot.position += motion.position * free_motion * heft_weight + Vector3(0.0, -switch_drop - reload_curve * _reload_drop, shove)
	pivot.basis *= Basis.from_euler(motion.rotation * free_motion * heft_weight + Vector3(lift, 0.0, reload_curve * _reload_roll + roll))
	# Sampled mechanism pilot: one disjoint hardware/offset track, played at the
	# authoritative reload progress. It adds an offset only; every layer above
	# and below keeps its own procedural authority.
	var sampled := mechanism_offset()
	if sampled != Vector3.ZERO: pivot.position += weapon.transform.basis * sampled
	flash.visible = flash_remaining > 0 and not external_muzzle_fx
	# Presentation-only handling: bolt/slide cycle, charging handle, authoritative
	# magazine window, barrel heat. Never writes recoil/spread/ammo authority.
	handling.advance(dt, reloading, reload_progress, aim_weight, reduced_motion)
	_update_hands()
	_advance_kick(delta)
	var kick_pose := kick_motion.sample(reduced_motion)
	pivot.position += kick_pose.weapon_position
	pivot.basis *= Basis.from_euler(kick_pose.weapon_rotation)
	# Includes break-action motion, recoil, ADS, switch and reload transforms.
	for index: int in flash.get_child_count():
		var flare := flash.get_child(index) as Node3D
		flare.global_transform = anchors["Muzzle%d" % index].global_transform * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0, -0.025))

func _clear_motion() -> void:
	slide_target = 0.0
	slide_weight = 0.0
	recoil = 0.0
	punch = 0.0
	punch_spring.reset()
	inertia.reset()
	punch_sign = 1.0
	flash_remaining = 0.0
	switch_remaining = 0.0
	look_lag = Vector2.ZERO
	aim_requested = false
	aim_target = 0.0
	aim_weight = 0.0
	aim_blocked = false
	reloading = false
	reload_progress = 0.0
	kick_age = KICK_SECONDS
	kick_motion.interrupt()
	cancel_mechanism("motion cleared")
	if is_instance_valid(kick_leg): kick_leg.hide()
	if is_instance_valid(flash): flash.hide()
	if is_instance_valid(weapon): handling.clear()

func reset() -> void:
	_clear_motion()
	finish.clear()
	showing = false
	actor_id = -1
	speed = 0.0
	age = 0.0
	seen.clear()
	event_order.clear()
	expired_time = -INF
	recoil_count = 0
	kick_count = 0
	kick_motion.reset()
	if _attached:
		overlay.hide()
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func clear_round() -> void:
	reset()

func _exit_tree() -> void:
	# Teardown can happen before the first rendered frame (disconnect during loading).
	# Release instance surfaces while their material overrides still own valid RIDs.
	if is_instance_valid(pivot):
		for node: MeshInstance3D in pivot.find_children("*", "MeshInstance3D", true, false):
			node.mesh = null
	if is_instance_valid(kick_leg):
		for node: MeshInstance3D in kick_leg.find_children("*", "MeshInstance3D", true, false):
			node.mesh = null

func _build_kick_leg() -> void:
	kick_leg = KickRig.new()
	viewport.add_child(kick_leg)
	kick_leg.build()

func interrupt_kick() -> void:
	kick_motion.interrupt()
	kick_age = KICK_SECONDS
	if is_instance_valid(kick_leg): kick_leg.hide()

func get_kick_state() -> Dictionary:
	var pose := kick_motion.sample(reduced_motion)
	return {"step":pose.step, "strike":pose.strike, "age":kick_motion.age,
		"active":showing and pose.visible, "confirmed":kick_motion.confirmed,
		"accepted":kick_count, "contact_seconds":KickMotion.CONTACT,
		"duration":KICK_SECONDS, "chain_window":KickMotion.CHAIN_WINDOW}

func _advance_kick(delta: float) -> void:
	if not is_instance_valid(kick_leg): return
	kick_motion.advance(delta)
	kick_age = kick_motion.age
	kick_leg.apply_pose(kick_motion.sample(reduced_motion))

func _build_hands() -> void:
	# Rigid articulated hierarchy: independent Wrist / Elbow / Forearm nodes.
	# Grips are constrained to imported stations, not baked into one static mesh.
	var glove := StandardMaterial3D.new()
	glove.albedo_color = Color("26343b")
	glove.roughness = 0.88
	var sleeve := StandardMaterial3D.new()
	sleeve.albedo_color = Color("506168")
	sleeve.roughness = 0.72
	for side: int in [-1, 1]:
		var limb := Node3D.new()
		limb.name = "RightArm" if side == 1 else "LeftArm"
		hands.add_child(limb)
		var wrist := Node3D.new()
		wrist.name = "Wrist"
		limb.add_child(wrist)
		wrists[side] = wrist
		var elbow := Node3D.new()
		elbow.name = "Elbow"
		limb.add_child(elbow)
		elbows[side] = elbow
		var gloves := SurfaceTool.new()
		gloves.begin(Mesh.PRIMITIVE_TRIANGLES)
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 12
		sphere.rings = 6
		gloves.append_from(sphere, 0, Transform3D(Basis.from_scale(Vector3(0.044, 0.057, 0.047)), Vector3.ZERO))
		for finger: int in 4:
			gloves.append_from(sphere, 0, Transform3D(Basis.from_scale(Vector3(0.012, 0.016, 0.034)), Vector3(-0.031 + finger * 0.021, 0.026, -0.027)))
		gloves.append_from(sphere, 0, Transform3D(Basis.from_scale(Vector3(0.019, 0.035, 0.02)), Vector3(side * 0.037, 0.01, 0.015)))
		var palm := MeshInstance3D.new()
		palm.name = "Glove"
		palm.mesh = gloves.commit()
		palm.material_override = glove
		palm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wrist.add_child(palm)
		var arm := CylinderMesh.new()
		arm.top_radius = 0.054
		arm.bottom_radius = 0.075
		arm.height = 1.0
		arm.radial_segments = 12
		var forearm := MeshInstance3D.new()
		forearm.name = "Forearm"
		forearm.mesh = arm
		forearm.material_override = sleeve
		forearm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elbow.add_child(forearm)
		forearms[side] = forearm

func _update_hands() -> void:
	if anchors.is_empty(): return
	# Left hand leaves the fore-end, grips the feed through extraction/insertion,
	# and returns. Right hand remains constrained to the pistol grip throughout.
	var contact := 0.0
	if reloading:
		contact = smoothstep(_hand_window.x, _hand_window.y, reload_progress) * (1.0 - smoothstep(_hand_window.z, _hand_window.w, reload_progress))
	for side: int in [-1, 1]:
		var station: Node3D = anchors.GripRight if side == 1 else anchors.GripSupport
		var target: Transform3D = hands.global_transform.affine_inverse() * station.global_transform
		if side == -1 and contact > 0:
			var feed: Transform3D = hands.global_transform.affine_inverse() * anchors.GripReload.global_transform
			target = target.interpolate_with(feed, contact)
		wrists[side].transform = target
		wrists[side].basis *= Basis(Vector3.RIGHT, -0.22 if side == 1 else 0.18 * (1.0 - contact))
		var elbow: Node3D = elbows[side]
		elbow.position = Vector3(0.27, -0.38, 0.32) if side == 1 else Vector3(-0.30, -0.38, 0.11)
		var delta: Vector3 = target.origin - elbow.position
		var axis := delta.normalized()
		forearms[side].transform = Transform3D(Basis(Quaternion(Vector3.UP, axis)) * Basis.from_scale(Vector3(1, maxf(0.01, delta.length() - 0.035), 1)), delta * 0.5)
