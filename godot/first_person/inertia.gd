extends RefCounted
## Source-observed motion -> bounded cosmetic weapon offsets. Never camera/aim.
##
## Every spring and impulse bound is owned by the shared
## `WeaponPresentationProfile` for the held weapon and resolved once per bind,
## so the sway feel is authored in one place and the hot path stays plain float
## math. An unbound instance uses the profile's documented default, which
## reproduces the constants this helper carried before the profile existed.
const Profile = preload("res://first_person/profiles/weapon_presentation_profile.gd")
const Spring = preload("res://animation/critical_spring.gd")
## Cosmetic channels the profile owns a spring for.
const CHANNELS: Array[String] = ["lateral", "forward", "vertical", "sprint", "strafe", "look_x", "look_y"]
var lateral := Spring.new()
var forward := Spring.new()
var vertical := Spring.new()
var sprint := Spring.new()
var look_x := Spring.new()
var look_y := Spring.new()
var strafe := Spring.new()
var strafe_target := 0.0
var previous := Vector3.ZERO
var position := Vector3.ZERO
var grounded := true
var sampled := false
var sprinting := false
var flying := false
var health := 0.0

## Resolved once per bind: channel -> {omega, limit}, plus the authored impulse
## and composition table from the same profile.
var _profile: WeaponPresentationProfile = Profile.default_for_weapon()
var _springs: Dictionary = {}
var _impulses: Dictionary = {}

func _init() -> void:
	bind(Profile.default_for_weapon())

## Resolve this helper's bounds from the shared profile. Runtime state (the
## springs themselves and the observed snapshot history) stays per instance.
func bind(profile: WeaponPresentationProfile) -> void:
	_profile = profile if profile != null else Profile.default_for_weapon()
	_springs = {}
	for channel: String in CHANNELS:
		_springs[channel] = _profile.spring(channel)
	_impulses = _profile.impulse_table()

## The spring bound this helper resolved for `channel` (`omega`, `limit`).
## Read-only diagnostics/evidence: the profile, not this instance, owns them.
func spring(channel: String) -> Dictionary:
	var value: Variant = _springs.get(channel)
	return value if value is Dictionary else {}

func reset() -> void:
	for spring in [lateral, forward, vertical, sprint, look_x, look_y, strafe]: spring.reset()
	sampled = false
	sprinting = false
	flying = false
	grounded = true
	strafe_target = 0.0
	health = 0.0

func observe(actor: Dictionary, camera_basis: Basis, flight_mode: bool = false) -> void:
	var next := Vector3(float(actor.get("vx", 0.0)), float(actor.get("vy", 0.0)), float(actor.get("vz", 0.0)))
	var at := Vector3(float(actor.get("x", 0.0)), float(actor.get("y", 0.0)), float(actor.get("z", 0.0)))
	if not next.is_finite() or not at.is_finite(): reset(); return
	var floor_now: bool = actor.get("grounded", true) != false
	var flight_now: bool = flight_mode
	if sampled and (at.distance_to(position) > 4.0 or flight_now != flying): reset()
	var hp := float(actor.get("health", 0.0))
	if sampled and not flight_now:
		# Differences in observed velocity are impulses, not frame-count forces.
		var change := camera_basis.inverse() * (next - previous)
		var bounds: Dictionary = _impulses["lateral"]
		var reach := _number(bounds, "clamp")
		lateral.impulse(clampf(-change.x * _number(bounds, "gain"), -reach, reach), _number(bounds, "limit"))
		bounds = _impulses["forward"]
		reach = _number(bounds, "clamp")
		forward.impulse(clampf(-change.z * _number(bounds, "gain"), -reach, reach), _number(bounds, "limit"))
		bounds = _impulses["vertical"]
		if grounded and not floor_now and next.y > 1.0:
			vertical.impulse(_number(bounds, "jump"), _number(bounds, "jump_limit"))
		if not grounded and floor_now:
			vertical.impulse(-clampf(absf(previous.y) * _number(bounds, "land_gain"), _number(bounds, "land_min"), _number(bounds, "land_max")), _number(bounds, "land_limit"))
		if hp < health:
			var hurt: Dictionary = _impulses["hurt"]
			lateral.impulse(_number(hurt, "lateral"), _number(hurt, "lateral_limit"))
			vertical.impulse(_number(hurt, "vertical"), _number(hurt, "vertical_limit"))
	previous = next
	position = at
	grounded = floor_now
	health = hp
	flying = flight_now
	sprinting = actor.get("sprinting", false) == true and floor_now and not flying
	# The source velocity, not raw input, follows real braking and collision.
	# Weapon-only lean leaves camera aim and gameplay collision untouched.
	var strafe_bounds: Dictionary = _impulses["strafe"]
	var local_velocity := camera_basis.inverse() * next
	strafe_target = clampf(-local_velocity.x / _number(strafe_bounds, "divisor"), -1.0, 1.0) if floor_now and not flight_now else 0.0
	sampled = true

func look(radians: Vector2) -> void:
	var bounds: Dictionary = _impulses["look_x"]
	look_x.impulse(-radians.x * _number(bounds, "gain"), _number(bounds, "limit"))
	bounds = _impulses["look_y"]
	look_y.impulse(-radians.y * _number(bounds, "gain"), _number(bounds, "limit"))

func advance(delta: float, reduced: bool) -> Dictionary:
	var quiet := 0.0 if reduced else 1.0
	var lateral_spring: Dictionary = _springs["lateral"]
	var forward_spring: Dictionary = _springs["forward"]
	var vertical_spring: Dictionary = _springs["vertical"]
	var sprint_spring: Dictionary = _springs["sprint"]
	var strafe_spring: Dictionary = _springs["strafe"]
	var look_x_spring: Dictionary = _springs["look_x"]
	var look_y_spring: Dictionary = _springs["look_y"]
	var lateral_bounds: Dictionary = _impulses["lateral"]
	var vertical_bounds: Dictionary = _impulses["vertical"]
	var sprint_bounds: Dictionary = _impulses["sprint"]
	var strafe_bounds: Dictionary = _impulses["strafe"]
	var x := lateral.advance(delta, 0.0, _number(lateral_spring, "omega"), _number(lateral_spring, "limit")) * quiet
	var z := forward.advance(delta, 0.0, _number(forward_spring, "omega"), _number(forward_spring, "limit")) * quiet
	var y := vertical.advance(delta, 0.0, _number(vertical_spring, "omega"), _number(vertical_spring, "limit")) * quiet
	var run := sprint.advance(delta, 1.0 if sprinting else 0.0, _number(sprint_spring, "omega"), _number(sprint_spring, "limit")) * quiet
	var lean := strafe.advance(delta, strafe_target, _number(strafe_spring, "omega"), _number(strafe_spring, "limit")) * quiet
	return {"position":Vector3(x + lean * _number(strafe_bounds, "position"), y - run * _number(sprint_bounds, "position"), z),
		"rotation":Vector3(-y * _number(vertical_bounds, "pitch") + run * _number(sprint_bounds, "pitch") + look_y.advance(delta, 0.0, _number(look_y_spring, "omega"), _number(look_y_spring, "limit")) * quiet,
			look_x.advance(delta, 0.0, _number(look_x_spring, "omega"), _number(look_x_spring, "limit")) * quiet,
			-x * _number(lateral_bounds, "roll") - lean * _number(strafe_bounds, "roll"))}

## One authored bound from the resolved profile table. A channel or field the
## profile does not name contributes nothing, which is why the profile's default
## table carries every key these helpers read.
static func _number(table: Dictionary, field: String) -> float:
	var value: Variant = table.get(field)
	return float(value) if (value is int or value is float) and is_finite(float(value)) else 0.0
