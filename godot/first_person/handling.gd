extends RefCounted
## Presentation-only first-person weapon handling: reciprocating bolt/slide
## carrier, charging handle, authoritative-window magazine/feed handling and
## barrel heat (glow + bounded haze/smoke at the authored `HeatZone`).
##
## Owns no gameplay state. Every channel is a pure function of the source
## snapshot (`reloading` + reload progress) or of local cosmetic state, and is
## fully reset by `clear()` on weapon switch, reload cancel, death, spectator,
## focus loss, stale snapshot, results and round restart.
##
## Bounded by construction: fixed part references, one persistent FX root and a
## fixed pool of quads. No node, mesh, material or collection is created while
## running.
const PUFFS := 3
const PUFF_LIFE := 0.40
const HAZE_SIZE := 0.026
const HAZE_GROWTH := 0.026
const CHARGE_TIME := 0.28

var _viewport: Node
var _fx_root: Node3D
var _weapon: Node3D
var _anchors: Dictionary = {}
var _info: Dictionary = {}
var _bolt: Node3D
var _bolt_rest := Transform3D.IDENTITY
var _feed: Node3D
var _feed_rest := Transform3D.IDENTITY
var _barrel: Node3D
var _barrel_rest := Transform3D.IDENTITY
var _glow: Array[StandardMaterial3D] = []
var _glow_steady: Array[bool] = []
var _glow_energy := -1.0
var _haze: MeshInstance3D
var _haze_material: StandardMaterial3D
var _puffs: Array[Dictionary] = []
var _quad := QuadMesh.new()
var _tint := Color("b8d3ea")
var _heat := 0.0
var _since_shot := 999.0
var _bolt_t := -1.0
var _charge_t := -1.0
var _puff_t := 0.0
var _puff_serial := 0

# Diagnostic read-outs for the bounded handling tests. Presentation only.
var bolt_offset := 0.0
var charge_offset := 0.0
var magazine_curve := 0.0
var heat := 0.0
var haze_alpha := 0.0
var puff_alpha := 0.0
var active_puffs := 0
var puffs_spawned := 0
var cycles := 0
var racks := 0
var cycle_duration := 0.1
var cycle_stroke := 0.05

func _init() -> void:
	_quad.size = Vector2.ONE

## Idempotent per-rig setup: one FX root inside the isolated viewport, a fixed
## quad pool, and no further node creation for the life of the rig.
func configure(viewport: Node) -> void:
	if _viewport == viewport: return
	_viewport = viewport
	_fx_root = Node3D.new()
	_fx_root.name = "WeaponHandlingFx"
	if is_instance_valid(_viewport): _viewport.add_child(_fx_root)
	_haze_material = _make_material()
	_haze = MeshInstance3D.new()
	_haze.name = "HeatHaze"
	_haze.mesh = _quad
	_haze.material_override = _haze_material
	_haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_haze.visible = false
	_fx_root.add_child(_haze)
	for index: int in PUFFS:
		var material := _make_material()
		var node := MeshInstance3D.new()
		node.name = "HeatPuff%d" % index
		node.mesh = _quad
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = false
		_fx_root.add_child(node)
		_puffs.append({"node":node, "material":material, "remaining":0.0, "total":PUFF_LIFE, "size":0.05, "velocity":Vector3.ZERO})

func _make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# Billboarded quads lose their node scale unless this is set; without it a
	# 1 m card would render over the sight picture instead of a few centimetres.
	material.billboard_keep_scale = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1, 1, 1, 0)
	return material

## Per-weapon binding from the rig's imported parts, rest pose and anchors.
func bind(weapon: Node3D, parts: Dictionary, rest: Dictionary, anchors: Dictionary, info: Dictionary, _id: int) -> void:
	_weapon = weapon
	_anchors = anchors
	_info = info.get("handling", {})
	_bolt = parts.get("bolt")
	_bolt_rest = rest.get("bolt", Transform3D.IDENTITY) if _bolt != null else Transform3D.IDENTITY
	_feed = parts.get("feed")
	_feed_rest = rest.get("feed", Transform3D.IDENTITY) if _feed != null else Transform3D.IDENTITY
	_barrel = parts.get("barrel-assembly", parts.get("shock-emitter", parts.get("flak-barrel")))
	_barrel_rest = _barrel.transform if _barrel != null else Transform3D.IDENTITY
	_tint = Color(info.get("color", "b8d3ea")).lerp(Color.WHITE, 0.35)
	cycle_duration = maxf(0.02, float(_info.get("cycle", 0.09)))
	cycle_stroke = maxf(0.0, float(_info.get("stroke", 0.05)))
	_glow.clear()
	_glow_steady.clear()
	_glow_energy = -1.0
	if _barrel != null:
		for node: MeshInstance3D in _barrel.find_children("*", "MeshInstance3D"):
			if node.mesh == null: continue
			for surface: int in node.mesh.get_surface_count():
				var material := node.get_surface_override_material(surface) as StandardMaterial3D
				if material != null:
					_glow.append(material)
					_glow_steady.append(material.emission_enabled)
	if is_instance_valid(_weapon) != is_instance_valid(weapon): pass
	clear()

## Called for every accepted local shot (same gate the rig uses for recoil).
func fire() -> void:
	_bolt_t = 0.0
	cycles += 1
	if _since_shot > maxf(0.35, cycle_duration * 4.0):
		_charge_t = 0.0
		racks += 1
	_since_shot = 0.0
	var heat_info: Dictionary = _info.get("heat", {})
	_heat = minf(_heat + maxf(0.0, float(heat_info.get("gain", 0.06))), float(heat_info.get("cap", 1.0)))

## Advances all cosmetic channels. `progress` is the authoritative reload
## progress (0..1); feed/charging motion is a pure function of it, so it can
## never run outside the source reloading state.
func advance(delta: float, reloading: bool, progress: float, aim_weight: float, reduced_motion: bool) -> void:
	if not is_instance_valid(_fx_root): return
	var dt := clampf(delta, 0.0, 0.05)
	var info: Dictionary = _info
	var cycle := maxf(0.02, float(info.get("cycle", 0.09)))
	var stroke := maxf(0.0, float(info.get("stroke", 0.05)))
	_since_shot += dt
	# 1. Reciprocating carrier: fast extraction, slower return, always back at
	#    rest before the next cycle of the weapon's own source rate.
	bolt_offset = 0.0
	if _bolt_t >= 0.0:
		_bolt_t += dt
		var phase := _bolt_t / cycle
		if phase >= 1.0: _bolt_t = -1.0
		else: bolt_offset = stroke * _cycle_curve(phase)
	# 2. Charging handle: first shot after a pause, and once per reload after the
	#    fresh magazine is seated. Never stacked on an in-flight shot cycle.
	charge_offset = 0.0
	var charge_stroke := maxf(0.0, float(info.get("charge", 0.0)))
	if _in_reload(reloading, progress):
		# A reload owns the charging handle until its own rack window completes.
		_charge_t = -1.0
		charge_offset = charge_stroke * _reload_charge_curve(progress)
	elif charge_stroke > 0.0 and _charge_t >= 0.0:
		_charge_t += dt
		var charge_phase := _charge_t / CHARGE_TIME
		if charge_phase >= 1.0: _charge_t = -1.0
		else: charge_offset = charge_stroke * _charge_curve(charge_phase)
	if _bolt != null and is_instance_valid(_bolt):
		_bolt.transform = _bolt_rest
		_bolt.position.z += maxf(bolt_offset, charge_offset)
	# 3. Feed/magazine handling, strictly inside the authoritative window.
	magazine_curve = 0.0
	var reload: Dictionary = info.get("reload", {})
	if _feed != null and is_instance_valid(_feed):
		_feed.transform = _feed_rest
		if _in_reload(reloading, progress):
			magazine_curve = _magazine_curve(progress)
			var amount := magazine_curve
			_feed.position += Vector3(0.0, -float(reload.get("drop", 0.1)) * amount, float(reload.get("slide", 0.0)) * amount)
			var roll := float(reload.get("roll", 0.0)) * amount
			var tilt := float(reload.get("tilt", 0.0)) * amount
			if roll != 0.0 or tilt != 0.0:
				_feed.basis = _feed_rest.basis * Basis.from_euler(Vector3(tilt, 0.0, roll))
	if _barrel != null and is_instance_valid(_barrel):
		_barrel.transform = _barrel_rest
		var hinge := float(reload.get("hinge", 0.0))
		if hinge > 0.0 and _in_reload(reloading, progress):
			_barrel.rotation.x += hinge * sin(PI * progress)
	# 4. Barrel heat: builds per shot, cools when idle, never above its cap.
	var heat_info: Dictionary = info.get("heat", {})
	_heat = maxf(0.0, _heat - dt * maxf(0.0, float(heat_info.get("cool", 0.3))))
	heat = minf(float(heat_info.get("cap", 1.0)), _heat)
	_apply_glow(heat)
	_advance_fx(dt, heat, aim_weight, reduced_motion)

static func _in_reload(reloading: bool, progress: float) -> bool:
	return reloading and progress > 0.0 and progress < 1.0

func _apply_glow(level: float) -> void:
	if _glow.is_empty(): return
	var energy := level * level * 0.9
	if absf(energy - _glow_energy) < 0.0005: return
	_glow_energy = energy
	var on := energy > 0.001
	for index: int in _glow.size():
		var material := _glow[index]
		if not is_instance_valid(material): continue
		if on:
			material.emission_enabled = true
			material.emission = _tint
			material.emission_energy_multiplier = energy
		else:
			material.emission_energy_multiplier = 0.0
			if _glow_steady[index] == false: material.emission_enabled = false

func _advance_fx(delta: float, level: float, aim_weight: float, reduced_motion: bool) -> void:
	var anchor: Node3D = _anchors.get("HeatZone")
	if anchor == null or not is_instance_valid(anchor):
		_haze.visible = false
		active_puffs = 0
		puff_alpha = 0.0
		for slot: Dictionary in _puffs:
			slot.remaining = 0.0
			slot.node.visible = false
		return
	_fx_root.global_transform = anchor.global_transform
	# ADS owns the sight picture: the heat micro-effect fades out completely
	# before the cheek weld settles, so no haze can enter the sight corridor.
	var scale := clampf(1.0 - aim_weight / 0.55, 0.0, 1.0)
	if reduced_motion: scale *= 0.5
	var visible := level > 0.02 and scale > 0.01
	_haze.visible = visible
	haze_alpha = 0.0
	if visible:
		var size := (HAZE_SIZE + HAZE_GROWTH * level) * (1.0 + level * 0.7)
		_haze.scale = Vector3(size, size, 1.0)
		haze_alpha = 0.16 * level * scale
		_haze_material.albedo_color = Color(_tint.r, _tint.g, _tint.b, haze_alpha)
	# Sustained fire emits a bounded smoke wisp; a cold barrel emits nothing.
	if scale <= 0.01:
		puff_alpha = 0.0
		for slot: Dictionary in _puffs:
			slot.remaining = 0.0
			slot.node.visible = false
		active_puffs = 0
		return
	if not reduced_motion and level > 0.22 and _puff_t <= 0.0:
		_spawn_puff(level)
		_puff_t = maxf(0.045, 0.14 - level * 0.085)
	_puff_t -= delta
	active_puffs = 0
	puff_alpha = 0.0
	for slot: Dictionary in _puffs:
		if slot.remaining <= 0.0:
			slot.node.visible = false
			continue
		slot.remaining = maxf(0.0, float(slot.remaining) - delta)
		if slot.remaining <= 0.0:
			slot.node.visible = false
			continue
		var phase: float = 1.0 - float(slot.remaining) / float(slot.total)
		slot.node.position += slot.velocity * delta
		var puff_size: float = float(slot.size) * (1.0 + phase * 0.7)
		slot.node.scale = Vector3(puff_size, puff_size, 1.0)
		var alpha := 0.26 * level * scale * pow(1.0 - phase, 0.8)
		slot.material.albedo_color = Color(_tint.r, _tint.g, _tint.b, alpha)
		slot.node.visible = alpha > 0.002
		puff_alpha = maxf(puff_alpha, alpha)
		active_puffs += 1

func _spawn_puff(level: float) -> void:
	_puff_serial += 1
	var slot: Dictionary = _puffs[0]
	for candidate: Dictionary in _puffs:
		if candidate.remaining <= 0.0:
			slot = candidate
			break
		if candidate.remaining < slot.remaining: slot = candidate
	var side := -1.0 if _puff_serial % 2 == 0 else 1.0
	slot.total = PUFF_LIFE
	slot.remaining = PUFF_LIFE
	slot.size = 0.024 + 0.016 * level
	slot.velocity = Vector3(0.010 * side, 0.025 + 0.015 * level, -0.02)
	slot.node.position = Vector3(0.006 * side, 0.002, 0.0)
	slot.node.visible = true
	puffs_spawned += 1

## Cycle shape: 32% fast extraction, 68% eased return.
static func _cycle_curve(phase: float) -> float:
	var p := clampf(phase, 0.0, 1.0)
	if p < 0.32: return smoothstep(0.0, 0.32, p)
	return 1.0 - smoothstep(0.32, 1.0, p)

## Charging handle: pull, brief hold, release.
static func _charge_curve(phase: float) -> float:
	var p := clampf(phase, 0.0, 1.0)
	if p < 0.40: return smoothstep(0.0, 0.40, p)
	if p < 0.58: return 1.0
	return 1.0 - smoothstep(0.58, 1.0, p)

## Feed out early in the authoritative window, seated late, with a small damped
## dip past rest as the fresh magazine locks in.
static func _magazine_curve(progress: float) -> float:
	var p := clampf(progress, 0.0, 1.0)
	var out := smoothstep(0.05, 0.36, p)
	var insert := smoothstep(0.58, 0.86, p)
	var curve := out * (1.0 - insert)
	if insert > 0.0 and insert < 1.0:
		curve += sin(PI * insert * 2.0) * (1.0 - insert) * 0.10
	return curve

## Reload racking: after the magazine is seated, released before the window ends.
static func _reload_charge_curve(progress: float) -> float:
	var p := clampf(progress, 0.0, 1.0)
	if p < 0.60 or p > 0.96: return 0.0
	var w := (p - 0.60) / 0.36
	if w < 0.35: return smoothstep(0.0, 0.35, w)
	if w < 0.5: return 1.0
	return 1.0 - smoothstep(0.5, 1.0, w)

func clear() -> void:
	_bolt_t = -1.0
	_charge_t = -1.0
	_since_shot = 999.0
	_heat = 0.0
	heat = 0.0
	bolt_offset = 0.0
	charge_offset = 0.0
	magazine_curve = 0.0
	haze_alpha = 0.0
	active_puffs = 0
	puff_alpha = 0.0
	_puff_t = 0.0
	cycles = 0
	racks = 0
	if _bolt != null and is_instance_valid(_bolt): _bolt.transform = _bolt_rest
	if _feed != null and is_instance_valid(_feed): _feed.transform = _feed_rest
	if _barrel != null and is_instance_valid(_barrel): _barrel.transform = _barrel_rest
	for slot: Dictionary in _puffs:
		slot.remaining = 0.0
		if is_instance_valid(slot.node): slot.node.visible = false
	if is_instance_valid(_haze): _haze.visible = false
	_apply_glow(0.0)