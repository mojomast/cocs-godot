extends Node
## Cosmetic only: isolated transparent world, source snapshots/events, no input/aim writes.
const Catalog = preload("res://first_person/generated/catalog.gd")
const Handling = preload("res://first_person/handling.gd")
const MAX_SEEN := 4096
var source_camera: Camera3D
var viewport: SubViewport
var overlay: CanvasLayer
var image: TextureRect
var weapon_camera: Camera3D
var pivot: Node3D
var weapon: Node3D
var hands: Node3D
var flash: Node3D
var manifest: Dictionary = {}
var scenes: Dictionary = {}
var current_weapon := -1
var actor_id := -1
var showing := false
var reduced_motion := false
var speed := 0.0
var reloading := false
var reload_progress := 0.0
var recoil := 0.0
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
var handling := Handling.new()

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
	showing = eligible
	overlay.visible = eligible
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if eligible else SubViewport.UPDATE_DISABLED
	speed = minf(12.0, Vector2(number(actor.get("vx")), number(actor.get("vz"))).length()) if eligible and actor.get("grounded", true) != false else 0.0
	reloading = eligible and actor.get("reloading", false) == true
	aim_blocked = reloading or actor.get("sprinting", false) == true or number(actor.get("weaponSwitch")) > 0.0
	if aim_blocked:
		aim_requested = false
		aim_target = 0.0
	var duration := number(actor.get("reloadDuration"))
	reload_progress = clampf(1.0 - number(actor.get("reloadTimer"), duration) / duration, 0.0, 1.0) if reloading and duration > 0 else 0.0

func apply_aim(active: bool, weight: float = 1.0) -> bool:
	aim_requested = active and showing and not aim_blocked and is_finite(weight) and weight > 0.0
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
	return {"rear": weapon_camera.unproject_position(anchors.SightRear.global_position), "front": weapon_camera.unproject_position(anchors.SightFront.global_position), "optic": weapon_camera.unproject_position(anchors.OpticCenter.global_position)}

func apply_events(events: Array, local_id: int) -> void:
	# Consume hidden events as well, so unfocus/stale/death recovery cannot replay fire.
	for value: Variant in events:
		if not value is Dictionary: continue
		var event: Dictionary = value
		if event.get("type") not in ["shot", "launch"]: continue
		var id := identity(event.get("id"))
		var time := number(event.get("time"), -1)
		var owner := identity(event.get("actor"))
		var kind := identity(event.get("weapon"))
		if id < 0 or time < 0 or owner < 0 or kind < 0 or kind >= 10: continue
		var key := "%s/%d/%s/%d/%d" % [event.type, id, str(time), owner, kind]
		if time <= expired_time or seen.has(key): continue
		_remember(key, time)
		# One source trigger can produce 8/12 shot events. Explosive shrapnel is not fire.
		var volley := "volley/%d/%d/%s" % [owner, kind, str(time)]
		if event.has("shrapnel") or seen.has(volley): continue
		_remember(volley, time)
		if not showing or owner != local_id or owner != actor_id or kind != current_weapon: continue
		recoil = minf(1.5, recoil + 1.0)
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
		look_lag = (look_lag - radians * 0.22).clamp(Vector2(-0.025, -0.02), Vector2(0.025, 0.02))

func _select_weapon(id: int) -> void:
	_clear_motion()
	if is_instance_valid(weapon):
		# Detach render surfaces before releasing their private material RIDs.
		# Godot 4.5 GLES/dummy backends otherwise query a freed override on rapid swaps.
		for node: MeshInstance3D in weapon.find_children("*", "MeshInstance3D"):
			node.mesh = null
		pivot.remove_child(weapon)
		weapon.free()
	parts.clear()
	rest.clear()
	anchors.clear()
	if not scenes.has(id): scenes[id] = load("res://first_person/generated/weapon-%d.glb" % id)
	weapon = scenes[id].instantiate()
	pivot.add_child(weapon)
	# Imported resources are shared. Each rig gets immutable private surface overrides.
	for node: Node in weapon.find_children("*", "MeshInstance3D"):
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface: int in node.mesh.get_surface_count():
			var mat: Material = node.mesh.surface_get_material(surface)
			if mat != null: node.set_surface_override_material(surface, mat.duplicate())
	for name: String in ["feed", "barrel-assembly", "shock-emitter", "flak-barrel", "bolt"]:
		var part := weapon.find_child(name, true, false) as Node3D
		if part != null:
			parts[name] = part
			rest[name] = part.transform
	current_weapon = id
	for name: String in manifest.weapons[id].anchors:
		anchors[name] = weapon.find_child(name, true, false)
		assert(anchors[name] != null, "Missing exported anchor: " + name)
	handling.bind(weapon, parts, rest, anchors, manifest.weapons[id], id)
	# Solve from the imported, actual sight nodes, rather than a shared ADS offset.
	var rear: Vector3 = pivot.to_local(anchors.SightRear.global_position)
	var front: Vector3 = pivot.to_local(anchors.SightFront.global_position)
	var orientation := Basis(Quaternion((front - rear).normalized(), Vector3.FORWARD))
	var rotated_rear := orientation * rear
	ads_pose = Transform3D(orientation, Vector3(-rotated_rear.x, -rotated_rear.y, -float(manifest.weapons[id].ads.pose.distance)))
	build_count += 1
	switch_remaining = 0.22
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
	var dt := minf(delta, 0.05)
	age += dt
	var info: Dictionary = manifest.weapons[current_weapon]
	recoil = move_toward(recoil, 0.0, dt * float(info.kick[2]))
	flash_remaining = maxf(0.0, flash_remaining - dt)
	switch_remaining = maxf(0.0, switch_remaining - dt)
	var target := aim_target if not reloading and switch_remaining <= 0.0 else 0.0
	var rate := float(info.ads.enter if target > aim_weight else info.ads.exit)
	aim_weight = lerpf(aim_weight, target, 1.0 - exp(-dt * rate))
	if absf(aim_weight - target) < 0.00001: aim_weight = target
	look_lag *= exp(-dt * 12.0)
	var bob := minf(speed / 8.0, 1.0) if not reduced_motion else 0.0
	var breathe := sin(age * 1.7) * 0.0015 if not reduced_motion else 0.0
	var reload_curve := sin(reload_progress * PI) if reloading else 0.0
	# Hip pose: muzzle sits below/right of the center ray, receiver and arms remain above HUD.
	var hip := Transform3D(Basis.from_euler(Vector3(-0.04, 0.22, -0.025)), Vector3(0.34, -0.26, -0.88))
	pivot.transform = hip.interpolate_with(ads_pose, aim_weight)
	# Keep settled neutral sights exactly on the camera ray. Recoil is deliberately
	# visible, then recovers; idle/locomotion/lag fade out as cheek weld completes.
	var free_motion := 1.0 - aim_weight
	pivot.position += Vector3(sin(age * 8.0) * bob * 0.004 * free_motion, (breathe + cos(age * 16.0) * bob * 0.003) * free_motion - switch_remaining * 0.32 - reload_curve * 0.045, recoil * float(info.kick[0]) * 0.45)
	pivot.basis *= Basis.from_euler(Vector3(recoil * float(info.kick[1]) * (0.25 if reduced_motion else 0.6) + look_lag.y * free_motion, look_lag.x * free_motion, reload_curve * 0.16))
	flash.visible = flash_remaining > 0 and not external_muzzle_fx
	# Presentation-only handling: bolt/slide cycle, charging handle, authoritative
	# magazine window, barrel heat. Never writes recoil/spread/ammo authority.
	handling.advance(dt, reloading, reload_progress, aim_weight, reduced_motion)
	_update_hands()
	# Includes break-action motion, recoil, ADS, switch and reload transforms.
	for index: int in flash.get_child_count():
		var flare := flash.get_child(index) as Node3D
		flare.global_transform = anchors["Muzzle%d" % index].global_transform * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0, -0.025))

func _clear_motion() -> void:
	recoil = 0.0
	flash_remaining = 0.0
	switch_remaining = 0.0
	look_lag = Vector2.ZERO
	aim_requested = false
	aim_target = 0.0
	aim_weight = 0.0
	aim_blocked = false
	reloading = false
	reload_progress = 0.0
	if is_instance_valid(flash): flash.hide()
	if is_instance_valid(weapon): handling.clear()

func reset() -> void:
	_clear_motion()
	showing = false
	actor_id = -1
	speed = 0.0
	age = 0.0
	seen.clear()
	event_order.clear()
	expired_time = -INF
	recoil_count = 0
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
		contact = smoothstep(0.04, 0.22, reload_progress) * (1.0 - smoothstep(0.78, 0.96, reload_progress))
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
