extends RefCounted
## Small source-confirmed optical sprint cue. The ADS FOV is owned by the rig;
## this additive hip-fire cue never modifies look angles or gameplay aim.
##
## The cue's degree and rate are owned by the shared
## `WeaponPresentationProfile` for the held weapon; this helper owns only its own
## settled state. Unbound, it uses the profile's documented default.
const Profile = preload("res://first_person/profiles/weapon_presentation_profile.gd")
const MAX_DEGREES := Profile.SPRINT_FOV_DEGREES
const RATE := Profile.SPRINT_FOV_RATE
var degrees := 0.0
var _profile: WeaponPresentationProfile = Profile.default_for_weapon()
var _max_degrees := MAX_DEGREES
var _rate := RATE

func _init() -> void:
	_profile = null
	bind(Profile.default_for_weapon())

## Resolve the cue's bounds from the shared profile. The settled value stays here.
func bind(profile: WeaponPresentationProfile) -> void:
	if profile == _profile: return
	_profile = profile if profile != null else Profile.default_for_weapon()
	_max_degrees = _profile.sprint_fov_degrees()
	_rate = _profile.sprint_fov_rate()

func reset() -> void:
	degrees = 0.0

func advance(delta: float, sprinting: bool, allowed: bool, reduced: bool) -> void:
	if not allowed or reduced:
		reset()
		return
	if not is_finite(delta) or delta < 0.0: return
	var target := _max_degrees if sprinting else 0.0
	degrees = lerpf(degrees, target, 1.0 - exp(-minf(delta, 10.0) * _rate))

func compose(aim_fov: float, aim_weight: float) -> float:
	return aim_fov + degrees * (1.0 - clampf(aim_weight, 0.0, 1.0))
