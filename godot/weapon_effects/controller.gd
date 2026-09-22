extends Node3D
## Cosmetic public-event consumer. Provider() -> {visible, actor_id, weapon,
## camera: Camera3D, muzzles: Array[Node3D], ejection: Node3D (optional)}.
## Muzzle nodes live in the isolated first-person viewport and must follow the
## animated barrel. External ownership is respected; pooled nodes are detached.
const Profiles = preload("res://weapon_effects/profiles.gd")
const Origin = preload("res://weapon_effects/origin.gd")
const FlashShader = preload("res://weapon_effects/flash.gdshader")
const CAP := 64
const LINE_CAP := 128
const SEEN_CAP := 4096
var source_camera: Camera3D
var muzzle_provider: Callable
var collision_mask := 1
var occlusion_provider: Callable
var physics_occlusion_enabled := false
var quality := 2
var slots: Array[Dictionary] = []
var lines: Array[Dictionary] = []
var seen: Dictionary = {}
var order: Array[String] = []
var expired_time := -INF
var sheets: Dictionary = {}
var flashes := 0
var tracer_count := 0
var impacts := 0
var rejected := 0
var serial := 0
var quad := QuadMesh.new()
var casing := BoxMesh.new()

func _init() -> void:
	quad.size = Vector2.ONE
	casing.size = Vector3(0.009, 0.009, 0.025)
	# Run after ordinary rig animation, so visible tips and active paths agree.
	process_priority = 50

func configure(camera: Camera3D, provider: Callable) -> void:
	reset()
	source_camera = camera
	muzzle_provider = provider

## Convenience adapter for the ADS agent's authored animated anchors. The
## callback form remains usable by fixtures and future weapon implementations.
func attach_rig(rig: Node) -> void:
	var reference: WeakRef = weakref(rig)
	rig.set("external_muzzle_fx", true)
	configure(rig.get("source_camera"), func() -> Dictionary:
		var current: Node = reference.get_ref()
		if not is_instance_valid(current): return {}
		var anchors: Dictionary = current.get("anchors")
		var tips: Array = []
		for index: int in current.get_muzzle_count():
			var tip: Variant = anchors.get("Muzzle%d" % index)
			if tip is Node3D: tips.append(tip)
		return {"visible":current.get("showing"), "actor_id":current.get("actor_id"), "weapon":current.get("current_weapon"), "camera":current.get("weapon_camera"), "muzzles":tips, "ejection":anchors.get("Ejection")}
	)

func set_quality(value: int) -> void:
	quality = clampi(value, 0, 2)
	if quality == 0: _hide_all()

## Callback(from: Vector3, to: Vector3) -> bool: true means blocked. Required
## for mesh-only source maps; physics fallback is only for collider-backed maps.
func configure_occlusion(provider: Callable) -> void:
	occlusion_provider = provider

func _occluded(from: Vector3, to: Vector3) -> bool:
	if occlusion_provider.is_valid():
		var result: Variant = occlusion_provider.call(from, to)
		return result if result is bool else true
	# Empty native physics worlds are not evidence of visibility. Integration
	# opts in only on collider-backed maps, otherwise requires semantic geometry.
	if not physics_occlusion_enabled: return true
	return Origin.blocked(source_camera, from, to, collision_mask)

func configure_moth(provider: Callable) -> void:
	sheets.clear()
	if not provider.is_valid(): return
	# Caller aliases its approved library names to these semantic keys. No asset
	# imports or external pulse-preview reservations are touched here.
	for key: String in ["pulse", "plasma", "shock"]:
		var sheet: Variant = provider.call(key)
		if not sheet is Dictionary or not sheet.get("frames") is Array: continue
		if sheet.frames.is_empty() or sheet.frames.size() > 32 or not numeric(sheet.get("fps")): continue
		if sheet.fps <= 0 or sheet.fps > 120: continue
		var valid := true
		for frame: Variant in sheet.frames:
			if not frame is Texture2D: valid = false
		if valid: sheets[key] = sheet.duplicate()

static func numeric(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func identity(value: Variant) -> int:
	if not numeric(value) or value < 0 or value > 9007199254740991 or float(value) != floor(float(value)): return -1
	return int(value)

static func point(value: Variant) -> Variant:
	if not value is Dictionary: return null
	for key: String in ["x", "y", "z"]:
		if not numeric(value.get(key)) or absf(float(value[key])) > 100000: return null
	return Vector3(value.x, value.y, value.z)

func _rig() -> Dictionary:
	if not muzzle_provider.is_valid(): return {}
	var result: Variant = muzzle_provider.call()
	return result if result is Dictionary else {}

func _eligible(rig: Dictionary, owner: int, weapon: int) -> bool:
	return owner >= 0 and weapon >= 0 and weapon < 10 and quality > 0 and rig.get("visible") == true and identity(rig.get("actor_id")) == owner and identity(rig.get("weapon")) == weapon and rig.get("camera") is Camera3D and rig.get("muzzles") is Array

func _remember(key: String, time: float) -> bool:
	if time <= expired_time or seen.has(key): return false
	seen[key] = time
	order.append(key)
	if order.size() > SEEN_CAP:
		var old: String = order.pop_front()
		expired_time = maxf(expired_time, seen[old])
		seen.erase(old)
	return true

func consume(events: Array, local_id: int, actors: Array = []) -> void:
	var rig := _rig()
	var alive := {}
	for index: int in mini(actors.size(), 512):
		var actor: Variant = actors[index]
		if actor is Dictionary and identity(actor.get("id")) >= 0:
			alive[identity(actor.id)] = numeric(actor.get("health")) and actor.health > 0 and not bool(actor.get("dead", false)) and not bool(actor.get("spectating", false)) and actor.get("vehicleId") == null and actor.get("visible", true) != false and actor.get("hidden", false) != true
	for index: int in mini(events.size(), 512):
		var event: Variant = events[index]
		if not event is Dictionary or event.get("type") not in ["shot", "launch"]: continue
		var id := identity(event.get("id"))
		var owner := identity(event.get("actor"))
		var weapon := identity(event.get("weapon"))
		if id < 0 or owner < 0 or weapon < 0 or weapon >= 10 or not numeric(event.get("time")) or event.time < 0:
			rejected += 1
			continue
		if not _remember("event/%d/%s/%d" % [id, str(event.time), owner], event.time): continue
		# Consume invisible/dead/remote events too; focus recovery cannot replay.
		var first := false
		if not event.has("shrapnel"):
			first = _remember("volley/%d/%d/%s" % [owner, weapon, str(event.time)], event.time)
		if quality == 0 or not alive.get(owner, false): continue
		var local := owner == local_id
		if local and not _eligible(rig, owner, weapon): continue
		var start: Variant = point(event.get("from" if event.type == "shot" else "pos"))
		var end: Variant = point(event.get("to")) if event.type == "shot" else start
		if start == null or end == null: continue
		var resolved := {}
		var tips: Array = rig.get("muzzles", []) if local else []
		if local and not event.has("shrapnel"):
			# Source muzzleBlocked emits a short eye-origin ray, not a launch. A
			# close eye-origin event must never light the protruding cosmetic barrel.
			if event.type == "shot" and is_instance_valid(source_camera) and start.distance_to(source_camera.global_position) < 0.15 and start.distance_to(end) < 1.0: continue
			var tip_index := id % maxi(1, tips.size())
			if tips.is_empty() or not tips[tip_index] is Node3D: continue
			resolved = Origin.resolve(source_camera, rig.camera, tips[tip_index], start, end, collision_mask, _occluded)
			if resolved.is_empty(): continue
			if first:
				for tip: Variant in tips.slice(0, 4):
					if tip is Node3D and not Origin.resolve(source_camera, rig.camera, tip, start, end, collision_mask, _occluded).is_empty(): _fire(tip, weapon, rig)
		if event.type == "shot":
			var origin: Vector3 = resolved.get("position", start)
			var join: Vector3 = resolved.get("join", start)
			_spawn_line(origin, join, end, weapon, tips[id % tips.size()] if not resolved.is_empty() else null, rig.get("camera"), start)
			# Current source has no hit normal. Never guess a wall/actor surface
			# from shot.hit (which may be a blocked candidate, not damage).
			var normal: Variant = point(event.get("normal"))
			if normal != null and normal.length() > 0.9 and normal.length() < 1.1 and event.get("surface_hit") == true:
				_impact(end, normal.normalized(), weapon)

## Lead's projectile handshake: returns {} when hidden, unsafe, or mismatched.
## Visual interpolation only; launch.pos and snapshot projectile remain unchanged.
func resolve_launch_origin(event: Dictionary, local_id: int) -> Dictionary:
	var rig := _rig()
	var weapon := identity(event.get("weapon"))
	var start: Variant = point(event.get("pos"))
	if identity(event.get("actor")) != local_id or start == null or not _eligible(rig, local_id, weapon): return {}
	var tips: Array = rig.muzzles
	if tips.is_empty() or not tips[0] is Node3D: return {}
	return Origin.resolve(source_camera, rig.camera, tips[0], start, start, collision_mask, _occluded)

func _slot(parent: Node, kind: int) -> Dictionary:
	var slot := {}
	for candidate: Dictionary in slots:
		if not is_instance_valid(candidate.node): continue
		if candidate.remaining <= 0:
			slot = candidate
			break
	if slot.is_empty():
		# Rig swaps can free attached nodes. Retire those records before pooling.
		for index: int in range(slots.size()-1, -1, -1):
			if not is_instance_valid(slots[index].node): slots.remove_at(index)
		if slots.size() >= CAP:
			slot = slots[0]
			for candidate: Dictionary in slots:
				if candidate.serial < slot.serial: slot = candidate
		else:
			var node := MeshInstance3D.new()
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var material := ShaderMaterial.new()
			material.shader = FlashShader
			node.material_override = material
			add_child(node)
			slot = {"node":node, "material":material, "remaining":0.0}
			slots.append(slot)
	serial += 1
	if slot.node.get_parent() != parent: slot.node.reparent(parent, false)
	slot.node.transform = Transform3D.IDENTITY
	slot.node.mesh = casing if kind == 12 else quad
	slot.node.visible = true
	slot.merge({"kind":kind, "serial":serial, "velocity":Vector3.ZERO, "sheet":"", "remaining":0.1, "total":0.1, "size":0.1, "opacity":1.0}, true)
	slot.material.set_shader_parameter("kind", kind)
	slot.material.set_shader_parameter("billboard", kind != 12)
	slot.material.set_shader_parameter("use_sheet", false)
	slot.material.set_shader_parameter("frame_texture", null)
	return slot

func _fire(tip: Node3D, weapon: int, rig: Dictionary) -> void:
	var profile: Dictionary = Profiles.ITEMS[weapon]
	var slot := _slot(tip, profile.mode)
	slot.merge({"remaining":profile.life, "total":profile.life, "size":profile.size*2.4, "sheet":profile.sheet}, true)
	slot.material.set_shader_parameter("tint", profile.color)
	slot.node.position.z = -0.008
	_update_slot(slot)
	flashes += 1
	if weapon in [1, 5]:
		# Axial exhaust is in barrel-local geometry; the facing bloom is only its
		# bright mouth. Two crossed cards preserve the jet at oblique ADS angles.
		for angle: float in [0.0, PI/2.0]:
			var jet := _slot(tip, profile.mode)
			jet.merge({"remaining":profile.life, "total":profile.life, "size":profile.size*1.2}, true)
			jet.material.set_shader_parameter("billboard", false)
			jet.material.set_shader_parameter("tint", profile.color)
			jet.node.rotation = Vector3(PI/2.0, 0, angle)
			jet.node.position.z = -profile.size*0.45
			_update_slot(jet)
	if quality < 2: return
	var smoke := _slot(tip, 10)
	smoke.merge({"remaining":profile.smoke, "total":profile.smoke, "size":profile.size*1.4, "opacity":0.22, "velocity":Vector3(0.025, 0.28, -0.14)}, true)
	smoke.material.set_shader_parameter("tint", Color("809099"))
	_update_slot(smoke)
	var heat := _slot(tip, 11)
	heat.merge({"remaining":0.28, "total":0.28, "size":profile.size*0.5, "opacity":0.28}, true)
	heat.material.set_shader_parameter("tint", profile.color)
	_update_slot(heat)
	# Ejection is only supported with a real authored port anchor. Twin-break
	# scatter/flak and sealed energy tubes do not eject invented casings.
	if profile.case and rig.get("ejection") is Node3D and is_instance_valid(rig.ejection):
		var shell := _slot(rig.ejection, 12)
		shell.merge({"remaining":0.38, "total":0.38, "size":1.0, "velocity":Vector3(0.65,0.5,0.1)}, true)
		shell.material.set_shader_parameter("tint", Color("b59658"))
		_update_slot(shell)

func _impact(pos: Vector3, normal: Vector3, weapon: int) -> void:
	var slot := _slot(self, 11)
	slot.merge({"remaining":0.8, "total":0.8, "size":0.13, "opacity":0.65}, true)
	slot.node.global_position = pos + normal * 0.006
	slot.node.global_basis = Basis.looking_at(normal, Vector3.RIGHT if absf(normal.y) > 0.99 else Vector3.UP)
	slot.material.set_shader_parameter("billboard", false)
	slot.material.set_shader_parameter("tint", Color("343039"))
	_update_slot(slot)
	var spark := _slot(self, 7)
	spark.merge({"remaining":0.11,"total":0.11,"size":0.17,"opacity":0.8},true)
	spark.node.global_position = pos + normal*0.012
	spark.node.global_basis = slot.node.global_basis
	spark.material.set_shader_parameter("billboard",false)
	spark.material.set_shader_parameter("tint",Profiles.ITEMS[weapon].color)
	_update_slot(spark)
	impacts += 1

func _spawn_line(start: Vector3, join: Vector3, end: Vector3, weapon: int, tip: Variant, camera: Variant, authority: Vector3) -> void:
	if quality == 0 or start.distance_squared_to(end) < 0.00001: return
	var slot := {}
	for candidate: Dictionary in lines:
		if candidate.remaining <= 0:
			slot = candidate
			break
	if slot.is_empty():
		if lines.size() >= LINE_CAP:
			slot = lines[0]
			for candidate: Dictionary in lines:
				if candidate.serial < slot.serial: slot = candidate
		else:
			var node := MeshInstance3D.new()
			node.mesh = ImmediateMesh.new()
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.top_level = true
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.vertex_color_use_as_albedo = true
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			node.material_override = material
			add_child(node)
			slot = {"node":node,"material":material}
			lines.append(slot)
	serial += 1
	var duration := 0.13 if weapon in [2,6] else (0.075 if weapon in [3,7] else 0.065)
	slot.merge({"start":start,"join":join,"end":end,"tip":tip,"camera":camera,"authority":authority,"weapon":weapon,"remaining":duration,"total":duration,"serial":serial}, true)
	slot.node.visible = true
	_draw_line(slot)
	tracer_count += 1

func _draw_line(slot: Dictionary) -> void:
	var mesh: ImmediateMesh = slot.node.mesh
	mesh.clear_surfaces()
	var color: Color = Profiles.ITEMS[slot.weapon].color
	color.a = clampf(slot.remaining/slot.total,0.0,1.0)
	slot.material.albedo_color = color
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := 0.018
	if slot.weapon in [2,6]: width = 0.035
	elif slot.weapon in [3,7,9]: width = 0.008
	_segment(mesh,slot.start,slot.join,width*2.8,0.18)
	_segment(mesh,slot.join,slot.end,width*2.8,0.18)
	_segment(mesh,slot.start,slot.join,width,0.9)
	_segment(mesh,slot.join,slot.end,width,0.9)
	mesh.surface_end()

func _segment(mesh: ImmediateMesh, from: Vector3, to: Vector3, width: float, alpha: float) -> void:
	if from.distance_squared_to(to) < 0.0000001: return
	var view := source_camera.get_camera_transform().origin - (from+to)*0.5 if is_instance_valid(source_camera) else Vector3.UP
	var side := (to-from).cross(view).normalized()*width*0.5
	if side.length_squared() < 0.00000001: side = Vector3.RIGHT*width*0.5
	mesh.surface_set_color(Color(1,1,1,alpha))
	for vertex: Vector3 in [from-side,from+side,to+side,from-side,to+side,to-side]: mesh.surface_add_vertex(vertex)

func _update_slot(slot: Dictionary) -> void:
	var phase: float = 1.0-slot.remaining/slot.total
	slot.material.set_shader_parameter("phase", phase)
	slot.material.set_shader_parameter("opacity", slot.opacity * pow(1.0-phase, 0.65))
	var size: float = slot.size * (1.0 + phase*(1.8 if slot.kind == 10 else 0.35))
	slot.node.scale = Vector3.ONE * size
	if sheets.has(slot.sheet):
		var sheet: Dictionary = sheets[slot.sheet]
		var frame := mini(sheet.frames.size()-1, int((slot.total-slot.remaining)*sheet.fps))
		slot.material.set_shader_parameter("use_sheet", true)
		slot.material.set_shader_parameter("frame_texture", sheet.frames[frame])

func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0: return
	var rig := _rig()
	for slot: Dictionary in slots:
		if not is_instance_valid(slot.node) or slot.remaining <= 0: continue
		slot.remaining = maxf(0.0, slot.remaining-delta)
		if slot.node.get_parent() != self and rig.get("visible") != true: slot.remaining = 0.0
		if slot.remaining > 0 and slot.node.get_parent() != self and is_instance_valid(source_camera) and rig.get("camera") is Camera3D:
			var mapped := Origin.map_tip(source_camera, rig.camera, slot.node.get_parent())
			if mapped.is_empty() or _occluded(source_camera.get_camera_transform().origin, mapped.position): slot.remaining = 0.0
		if slot.remaining <= 0:
			slot.node.hide()
			slot.material.set_shader_parameter("frame_texture", null)
			continue
		slot.node.position += slot.velocity * delta
		if slot.kind == 12:
			slot.velocity.y -= delta*2.5
			slot.node.rotate_x(delta*13.0)
		_update_slot(slot)
	for slot: Dictionary in lines:
		if slot.remaining <= 0: continue
		slot.remaining = maxf(0.0,slot.remaining-delta)
		if slot.tip != null:
			if not is_instance_valid(slot.tip) or rig.get("visible") != true:
				slot.remaining = 0.0
			else:
				var resolved := Origin.resolve(source_camera, slot.camera, slot.tip, slot.authority, slot.end, collision_mask, _occluded)
				if resolved.is_empty(): slot.remaining = 0.0
				else: slot.start = resolved.position
		if slot.remaining <= 0: slot.node.hide()
		else: _draw_line(slot)

func _process(delta: float) -> void:
	advance(delta)

func _hide_all() -> void:
	for slot: Dictionary in slots + lines:
		slot.remaining = 0.0
		if is_instance_valid(slot.node): slot.node.hide()

func reset() -> void:
	for slot: Dictionary in slots + lines:
		if is_instance_valid(slot.node):
			slot.node.mesh = null
			slot.node.free()
	slots.clear()
	lines.clear()
	seen.clear()
	order.clear()
	expired_time = -INF
	flashes = 0
	tracer_count = 0
	impacts = 0
	rejected = 0
	serial = 0

func _exit_tree() -> void:
	reset()
