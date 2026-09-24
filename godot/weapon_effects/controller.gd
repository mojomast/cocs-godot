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
## Alt-fire blast kinds from the four projectile specs in game/alt-fire.mjs
## (cluster shell, mortar round, proximity mine, flak bomb). Presentation only:
## the pool body, ring/dust card and shard velocities are cosmetic and never
## touch the authoritative explosion position, radius or any damage.
const ALT_BLASTS: Array[String] = ["cluster", "mortar", "mine", "bomb"]
const BLAST_WEAPON_KINDS := {1:"cluster", 4:"mortar", 5:"mine", 7:"bomb"}
const BLAST_KIND := {"cluster":13, "mortar":14, "mine":15, "bomb":16}
const BLAST_TINTS := {
	"cluster":Color("ffb066"), "mortar":Color("c9a6ff"),
	"mine":Color("8fd9ff"), "bomb":Color("ff9a7a"),
}
## Per-kind card growth over its life and fade exponent (kind 10 smoke keeps its
## original hard-coded growth).
const BLAST_GROWTH := {"cluster":0.90, "mortar":0.60, "mine":2.30, "bomb":1.10}
const BLAST_FADE := {"cluster":0.50, "mortar":0.30, "mine":0.45, "bomb":0.60}
const MAX_BLAST_SHARDS := 8
## At a settled cheek weld the muzzle sits only a few degrees below the sight
## axis, so any large flash card centred on it would cover the open target gap.
## The aiming bloom is deliberately compact (hip fire keeps the full per-weapon
## size): presentation judgement call, asserted by the rendered gap check.
const ADS_FLASH_MAX := 0.18
## Barrel lights are a separate bounded pool: two pooled OmniLight3D nodes, only
## allocated on first use at Extreme quality, recycled oldest-first. They light
## the isolated viewmodel world for a few frames and never join the flash pool.
const MAX_LIGHTS := 2
var source_camera: Camera3D
var muzzle_provider: Callable
## Optional third-person anchor lookup (actor id, weapon id) -> visible Node3D.
## Hosts should return the exported world-weapon `Muzzle`, never a guessed body
## offset. Without this wiring remote cues retain their authoritative origin.
var remote_muzzle_provider: Callable
var collision_mask := 1
var occlusion_provider: Callable
var physics_occlusion_enabled := false
var quality := 2
var slots: Array[Dictionary] = []
var lines: Array[Dictionary] = []
var lights: Array[Dictionary] = []
var seen: Dictionary = {}
var order: Array[String] = []
var expired_time := -INF
var sheets: Dictionary = {}
var flashes := 0
var tracer_count := 0
var impacts := 0
var blasts := 0
var blast_shards := 0
var rejected := 0
var serial := 0
var light_serial := 0
var light_flashes := 0
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

func configure_remote_muzzles(provider: Callable) -> void:
	remote_muzzle_provider = provider

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
		return {"visible":current.get("showing"), "actor_id":current.get("actor_id"), "weapon":current.get("current_weapon"), "camera":current.get("weapon_camera"), "muzzles":tips, "ejection":anchors.get("Ejection"), "aim":current.get("aim_weight")}
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

## The alt blast a public explosion event names, or "" for a primary/unknown
## explosion. Gated on the alt flag so a primary rocket can never be re-skinned.
static func blast_kind(event: Dictionary) -> String:
	if event.get("alt") != true: return ""
	var id := str(event.get("altId", ""))
	if id in ALT_BLASTS: return id
	var weapon := identity(event.get("weapon"))
	var kind: Variant = BLAST_WEAPON_KINDS.get(weapon, "")
	return str(kind)

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
		if not event is Dictionary: continue
		# Alt explosions use their own pooled burst presentation; they are not a
		# shot, so they never touch the flash/tracer/rejected counters.
		if event.get("type") == "explosion":
			_consume_explosion(event)
			continue
		if event.get("type") not in ["shot", "launch"]: continue
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
		var remote_tip: Node3D
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
		elif not local and not event.has("shrapnel") and remote_muzzle_provider.is_valid():
			var remote: Variant = remote_muzzle_provider.call(owner, weapon)
			if remote is Node3D and is_instance_valid(remote) and remote.is_inside_tree() and remote.is_visible_in_tree():
				resolved = Origin.resolve_world(source_camera, remote.global_position, start, end, _occluded)
				# A known visible barrel behind cover must not silently fall back
				# to an eye-origin tracer or flash through that cover.
				if resolved.is_empty(): continue
				remote_tip = remote
				if first: _fire(remote, weapon, {})
		if event.type == "shot":
			var origin: Vector3 = resolved.get("position", start)
			var join: Vector3 = resolved.get("join", start)
			_spawn_line(origin, join, end, weapon, tips[id % tips.size()] if local and not resolved.is_empty() else remote_tip, rig.get("camera") if local else null, start)
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
	slot.merge({"kind":kind, "serial":serial, "velocity":Vector3.ZERO, "sheet":"", "remaining":0.1, "total":0.1, "size":0.1, "opacity":1.0, "growth":0.35, "fade":0.65}, true)
	slot.material.set_shader_parameter("kind", kind)
	slot.material.set_shader_parameter("billboard", kind != 12)
	slot.material.set_shader_parameter("use_sheet", false)
	slot.material.set_shader_parameter("frame_texture", null)
	# Recycled flash cards must not leak the previous weapon's core gain.
	slot.material.set_shader_parameter("core_gain", 1.0)
	slot.material.set_shader_parameter("brightness", 1.0)
	return slot

func _fire(tip: Node3D, weapon: int, rig: Dictionary) -> void:
	var profile: Dictionary = Profiles.ITEMS[weapon]
	var flash_life: float = float(profile.life) * float(profile.flash_life)
	# The bloom stays huge from the hip; at a settled cheek weld it collapses to
	# a compact bright spark so a heavy card can never cover the open sight gap.
	var aim := clampf(float(rig.get("aim", 0.0)), 0.0, 1.0)
	var flash_size: float = float(profile.size) * float(profile.flash_scale)
	if aim > 0.0: flash_size = lerpf(flash_size, minf(flash_size, ADS_FLASH_MAX), aim)
	var slot := _slot(tip, profile.mode)
	slot.merge({"remaining":flash_life, "total":flash_life, "size":flash_size*2.4, "sheet":profile.sheet}, true)
	slot.material.set_shader_parameter("tint", profile.color)
	slot.material.set_shader_parameter("core_gain", profile.bright)
	slot.material.set_shader_parameter("brightness", profile.bright)
	slot.node.position.z = -0.008
	_update_slot(slot)
	flashes += 1
	if weapon in [1, 5]:
		# Axial exhaust is in barrel-local geometry; the facing bloom is only its
		# bright mouth. Two crossed cards preserve the jet at oblique ADS angles.
		for angle: float in [0.0, PI/2.0]:
			var jet := _slot(tip, profile.mode)
			jet.merge({"remaining":flash_life, "total":flash_life, "size":flash_size*1.2}, true)
			jet.material.set_shader_parameter("billboard", false)
			jet.material.set_shader_parameter("tint", profile.color)
			jet.material.set_shader_parameter("core_gain", profile.bright)
			jet.material.set_shader_parameter("brightness", profile.bright)
			jet.node.rotation = Vector3(PI/2.0, 0, angle)
			jet.node.position.z = -profile.size*0.45
			_update_slot(jet)
	_barrel_light(tip, profile)
	if quality < 2: return
	var smoke := _slot(tip, 10)
	smoke.merge({"remaining":profile.smoke, "total":profile.smoke, "size":profile.size*1.4, "opacity":0.22, "velocity":Vector3(0.025, 0.28, -0.14), "growth":1.8}, true)
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

## Short barrel-light flash for heavy/energy weapons. Pooled and bounded to
## MAX_LIGHTS OmniLight3D nodes, only used at quality 2 (F9 High/Extreme), and
## parented to the authored muzzle tip so it follows the animated barrel. Kept
## out of the flash/casing pool so the existing node budgets are unchanged.
func _barrel_light(tip: Node3D, profile: Dictionary) -> void:
	if quality < 2 or float(profile.light) <= 0.0: return
	var slot := {}
	for candidate: Dictionary in lights:
		if is_instance_valid(candidate.node) and candidate.remaining <= 0.0:
			slot = candidate
			break
	if slot.is_empty():
		for index: int in range(lights.size()-1, -1, -1):
			if not is_instance_valid(lights[index].node): lights.remove_at(index)
		if lights.size() < MAX_LIGHTS:
			var node := OmniLight3D.new()
			node.name = "BarrelLight%d" % lights.size()
			node.shadow_enabled = false
			node.omni_attenuation = 1.6
			add_child(node)
			slot = {"node":node, "remaining":0.0, "total":0.1, "energy":1.0, "serial":0}
			lights.append(slot)
		else:
			slot = lights[0]
			for candidate: Dictionary in lights:
				if int(candidate.serial) < int(slot.serial): slot = candidate
	light_serial += 1
	if slot.node.get_parent() != tip: slot.node.reparent(tip, false)
	slot.node.position = Vector3(0.0, 0.0, -0.03)
	slot.node.light_color = profile.color
	slot.node.omni_range = float(profile.light_range)
	slot.merge({"serial":light_serial, "remaining":float(profile.light_life), "total":float(profile.light_life), "energy":float(profile.light)}, true)
	slot.node.light_energy = float(profile.light)
	slot.node.visible = true
	light_flashes += 1

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

## Alt explosion presentation. Consumes the public explosion event for the four
## projectile alt modes and draws a pooled burst that reads unlike primary fire
## and unlike the other alt modes:
##   cluster  a compact shard pop; the sim's own bomblet events add the small
##            staggered bursts, indexed by the event's `bomblet` field
##   mortar   a heavy dome burst plus a slow rising dust/smoke column
##   mine     a sharp proximity core plus a fast, tight shockwave ring
##   bomb     a vented pop plus a bounded fan of fragment shards
## The authoritative position is used exactly; no ground contact is invented.
func _consume_explosion(event: Dictionary) -> void:
	var kind := blast_kind(event)
	if kind.is_empty() or quality == 0: return
	var pos: Variant = point(event.get("pos"))
	if pos == null: return
	var time: float = float(event.time) if numeric(event.get("time")) else 0.0
	var id := identity(event.get("id"))
	if id >= 0 and not _remember("blast/%d/%s" % [id, str(time)], time): return
	match kind:
		"cluster": _cluster_blast(pos, identity(event.get("bomblet")))
		"mortar": _mortar_blast(pos)
		"mine": _mine_blast(pos)
		"bomb": _bomb_blast(pos)
	blasts += 1

func _blast_card(at: Vector3, kind: int, size: float, life: float, tint: Color, growth: float, fade: float) -> Dictionary:
	var slot := _slot(self, kind)
	slot.merge({"remaining":life, "total":life, "size":size, "opacity":1.0, "growth":growth, "fade":fade}, true)
	slot.material.set_shader_parameter("billboard", true)
	slot.material.set_shader_parameter("tint", tint)
	slot.material.set_shader_parameter("core_gain", 1.0)
	slot.material.set_shader_parameter("brightness", 1.0)
	slot.material.set_shader_parameter("use_sheet", false)
	slot.material.set_shader_parameter("frame_texture", null)
	slot.node.global_position = at
	slot.node.scale = Vector3.ONE * size
	_update_slot(slot)
	return slot

func _cluster_blast(pos: Vector3, bomblet: int) -> void:
	var accent: Color = BLAST_TINTS.cluster
	if bomblet >= 0:
		# Bomblet bursts share the shell's authoritative tick; the deterministic
		# index stagger keeps the three small pops readable as separate hits. The
		# delay rides `remaining` only, so the card's phase stays negative (hidden)
		# until its slot starts, then runs the full life.
		var pop := _blast_card(pos + Vector3(0, 0.05, 0), 13, 0.42, 0.20, accent, BLAST_GROWTH.cluster, BLAST_FADE.cluster)
		pop.remaining += 0.05 * float(bomblet)
		_update_slot(pop)
		return
	_blast_card(pos, 13, 0.95, 0.26, accent, BLAST_GROWTH.cluster, BLAST_FADE.cluster)
	# The split moment: a quick low ring under the pop.
	_blast_card(pos, 2, 1.5, 0.20, accent, 0.50, 0.50)

func _mortar_blast(pos: Vector3) -> void:
	var accent: Color = BLAST_TINTS.mortar
	_blast_card(pos, 14, 1.7, 0.55, accent, BLAST_GROWTH.mortar, BLAST_FADE.mortar)
	var dust := _blast_card(pos + Vector3(0, 0.35, 0), 14, 2.5, 0.85, Color("b9b2a6"), 1.10, 0.35)
	dust.merge({"opacity":0.34, "velocity":Vector3(0.0, 0.5, 0.0)}, true)
	# A slow, wide smoke card keeps reading after the flash collapses.
	var smoke := _blast_card(pos + Vector3(0, 0.55, 0), 10, 2.1, 0.95, Color("8d949c"), 1.80, 0.40)
	smoke.merge({"opacity":0.20, "velocity":Vector3(0.1, 0.65, 0.0)}, true)

func _mine_blast(pos: Vector3) -> void:
	var accent: Color = BLAST_TINTS.mine
	_blast_card(pos, 15, 0.80, 0.18, accent, 0.40, 0.60)
	# Sharper than the rocket bloom: a fast, tight ring outruns the core, and a
	# short concentric pulse sits inside it.
	_blast_card(pos, 2, 1.7, 0.26, accent.lerp(Color.WHITE, 0.25), BLAST_GROWTH.mine, 0.35)
	_blast_card(pos, 4, 0.55, 0.14, accent, 0.30, 0.70)

func _bomb_blast(pos: Vector3) -> void:
	var accent: Color = BLAST_TINTS.bomb
	_blast_card(pos, 16, 1.0, 0.26, accent, BLAST_GROWTH.bomb, BLAST_FADE.bomb)
	var plume := _blast_card(pos + Vector3(0, 0.2, 0), 10, 1.2, 0.55, Color("6f655c"), 1.80, 0.40)
	plume.merge({"opacity":0.18, "velocity":Vector3(0.0, 0.45, 0.0)}, true)
	# Fragment fan: the source expels `flak` shards; the fan is bounded and only
	# spends its full width at Extreme. Every shard reuses the pooled casing mesh.
	var count := MAX_BLAST_SHARDS if quality >= 2 else 4
	for index: int in count:
		var angle := float(index) * 2.399963229728653 + 0.7
		var lift := sin(angle * 1.7) * 0.5 + 0.25
		var direction := Vector3(cos(angle), lift, sin(angle)).normalized()
		var shard := _slot(self, 12)
		shard.merge({"remaining":0.4, "total":0.4, "size":9.0, "opacity":1.0,
			"velocity":direction * (5.5 + float(index % 3))}, true)
		shard.material.set_shader_parameter("tint", accent)
		shard.material.set_shader_parameter("brightness", 1.2)
		shard.node.global_position = pos + direction * 0.12
		_update_slot(shard)
		blast_shards += 1

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
	var duration: float = float(Profiles.ITEMS[weapon].tracer_life)
	slot.merge({"start":start,"join":join,"end":end,"tip":tip,"camera":camera,"authority":authority,"weapon":weapon,"remaining":duration,"total":duration,"serial":serial}, true)
	slot.node.visible = true
	_draw_line(slot)
	tracer_count += 1

func _draw_line(slot: Dictionary) -> void:
	var mesh: ImmediateMesh = slot.node.mesh
	mesh.clear_surfaces()
	var profile: Dictionary = Profiles.ITEMS[slot.weapon]
	var life := clampf(slot.remaining/slot.total,0.0,1.0)
	var phase := 1.0 - life
	# Per-weapon fade curve: fast weapons snap out, heavy beams hold a long tail.
	var fade := pow(life,float(profile.tracer_fade))
	var color: Color = profile.color
	var core: Color = color.lerp(Color(1.0,0.97,0.9),float(profile.tracer_core))
	var width := float(profile.tracer_width)
	var glow := float(profile.tracer_glow)
	slot.material.albedo_color = Color(1.0,1.0,1.0,fade)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# 1. Wide soft trail, brightest at the muzzle and fading down the ray.
	_segment(mesh,slot.start,slot.join,width*3.4,color,glow*0.9,glow*0.75)
	_segment(mesh,slot.join,slot.end,width*3.4,color,glow*0.75,glow*0.15)
	# 2. Solid mid trail along the whole authoritative path.
	_segment(mesh,slot.start,slot.join,width*1.7,core,0.22,0.50)
	_segment(mesh,slot.join,slot.end,width*1.7,core,0.50,0.06)
	# 3. Hot core: a near-white strip, brightest at the receiver end.
	_segment(mesh,slot.start,slot.join,width,core,0.65,1.0)
	_segment(mesh,slot.join,slot.end,width,core,1.0,0.30)
	# 4. Travelling bright head over the instant ray: the path is drawn whole at
	#    once (unchanged), the head reads as the round crossing it.
	var axis: Vector3 = slot.end - slot.start
	if axis.length_squared() > 0.000001:
		var direction := axis.normalized()
		var head: Vector3 = slot.start + axis * phase
		var tail := maxf(width*6.0, axis.length()*0.04)
		_segment(mesh,head - direction*tail,head + direction*width*1.5,width*1.5,core.lerp(Color.WHITE,0.5),0.0,1.0)
	mesh.surface_end()

func _segment(mesh: ImmediateMesh, from: Vector3, to: Vector3, width: float, color: Color, from_alpha: float, to_alpha: float) -> void:
	if from.distance_squared_to(to) < 0.0000001: return
	var view := source_camera.get_camera_transform().origin - (from+to)*0.5 if is_instance_valid(source_camera) else Vector3.UP
	var side := (to-from).cross(view).normalized()*width*0.5
	if side.length_squared() < 0.00000001: side = Vector3.RIGHT*width*0.5
	mesh.surface_set_color(Color(color.r,color.g,color.b,from_alpha))
	for vertex: Vector3 in [from-side,from+side,to+side]: mesh.surface_add_vertex(vertex)
	mesh.surface_set_color(Color(color.r,color.g,color.b,to_alpha))
	for vertex: Vector3 in [from-side,to+side,to-side]: mesh.surface_add_vertex(vertex)

func _update_slot(slot: Dictionary) -> void:
	var phase: float = 1.0-slot.remaining/slot.total
	if phase < 0.0:
		# A staggered blast card waits out its presentation delay hidden.
		slot.node.hide()
		return
	slot.node.visible = true
	slot.material.set_shader_parameter("phase", phase)
	slot.material.set_shader_parameter("opacity", slot.opacity * pow(1.0-phase, float(slot.get("fade", 0.65))))
	var size: float = slot.size * (1.0 + phase*float(slot.get("growth", 0.35)))
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
			if not is_instance_valid(slot.tip) or (slot.camera is Camera3D and rig.get("visible") != true):
				slot.remaining = 0.0
			else:
				var resolved := Origin.resolve(source_camera, slot.camera, slot.tip, slot.authority, slot.end, collision_mask, _occluded) if slot.camera is Camera3D else Origin.resolve_world(source_camera, slot.tip.global_position, slot.authority, slot.end, _occluded)
				if resolved.is_empty(): slot.remaining = 0.0
				else:
					slot.start = resolved.position
					slot.join = resolved.join
		if slot.remaining <= 0: slot.node.hide()
		else: _draw_line(slot)
	for slot: Dictionary in lights:
		if not is_instance_valid(slot.node) or slot.remaining <= 0: continue
		slot.remaining = maxf(0.0,slot.remaining-delta)
		if slot.node.get_parent() != self and rig.get("visible") != true: slot.remaining = 0.0
		if slot.remaining <= 0:
			slot.node.visible = false
			continue
		var phase: float = 1.0-slot.remaining/slot.total
		slot.node.light_energy = slot.energy*pow(1.0-phase,1.8)

func _process(delta: float) -> void:
	advance(delta)

func _hide_all() -> void:
	for slot: Dictionary in slots + lines + lights:
		slot.remaining = 0.0
		if is_instance_valid(slot.node): slot.node.hide()

func reset() -> void:
	for slot: Dictionary in slots + lines:
		if is_instance_valid(slot.node):
			slot.node.mesh = null
			slot.node.free()
	for slot: Dictionary in lights:
		if is_instance_valid(slot.node): slot.node.free()
	slots.clear()
	lines.clear()
	lights.clear()
	seen.clear()
	order.clear()
	expired_time = -INF
	flashes = 0
	tracer_count = 0
	impacts = 0
	blasts = 0
	blast_shards = 0
	rejected = 0
	serial = 0
	light_serial = 0
	light_flashes = 0

func _exit_tree() -> void:
	reset()
