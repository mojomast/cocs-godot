extends RefCounted
## Single documented art-direction, budget and lifecycle block for blood_fx.
##
## Everything the fluid presentation obeys lives here: no other script in
## `res://blood_fx/` hard-codes a colour, a size, a pool cap or a quality number.
## Change art direction in one place:
##
##   const BloodSettings = preload("res://blood_fx/settings.gd")
##   var s := BloodSettings.new()
##   s.fluid_color = Color("c21807")      # crimson (default)
##   s.fluid_scale = 1.15
##   blood_fx.settings = s                # assign before configure()
##
## (The class has no `class_name` on purpose: every cross-file type here is a
## preload const, so the module never depends on the editor class cache.)
##
## The operators are armoured machines, so one call switches the whole system to
## a synthetic-fluid variant without touching any code path:
##
##   blood_fx.apply_variant("synthetic")
##
## Variants only change fluid colour, brightness and size/viscosity; emission
## logic, budgets, pools and lifecycle rules are identical and never duplicated.
##
## Budgets are total allocated fluid particles for the WHOLE pool, never per
## event. They are split across `fluid_emitters` pooled GPUParticles3D nodes.

# --- exact API vocabulary -----------------------------------------------------
const QUALITY := ["Low", "High", "Extreme"]
const DEFAULT_QUALITY := "High"

# --- pools and budgets --------------------------------------------------------
## Pooled GPUParticles3D emitters. Shared world-space quota, split evenly.
var fluid_emitters: int = 24
## Total allocated fluid particles per quality. Reported as allocated_slots.
var quality_budgets: Dictionary = {"Low": 4096, "High": 24576, "Extreme": 98304}
## Maximum fluid emitters allowed to be live at once (concurrent cap).
var concurrent_cap: Dictionary = {"Low": 8, "High": 14, "Extreme": 20}
## Pooled surface-quad stains. Hard cap on nodes created.
var stain_pool: int = 128
## Maximum live stains per quality; the oldest stain is recycled past the cap.
var stain_caps: Dictionary = {"Low": 32, "High": 80, "Extreme": 128}

# --- wire / lifecycle ---------------------------------------------------------
var events_per_callback: int = 512
var id_window: int = 4096
var stale_seconds: float = 0.8

# --- fluid look ---------------------------------------------------------------
var fluid_color: Color = Color(0.56, 0.022, 0.035)      # crimson blood
var fluid_color_arterial: Color = Color(0.72, 0.03, 0.045)
var fluid_color_mist: Color = Color(0.44, 0.02, 0.03)
var fluid_scale: float = 1.0            # global droplet size multiplier (base 0.085-0.16 m)
var viscosity: float = 0.5              # 0 watery/spray -> 1 thick/coagulated
var gravity_scale: float = 1.0
var mist_speed: float = 2.4             # entry puff speed (m/s)
var jet_speed: float = 9.5              # exit jet speed (m/s)
var arterial_speed: float = 12.5        # pulsed arterial jet speed (m/s)
var burst_speed: float = 7.5            # death burst speed (m/s)
var jet_life: float = 0.85
var mist_life: float = 0.4
var burst_life: float = 1.15
var pulse_count: float = 3.0            # arterial pulses per emission
var density: float = 1.0                # global alpha gain for the fluid draw

# --- hit classification (real health damage, amount - shield) ------------------
var full_reference: float = 45.0        # damage that maps to strength 1.0
var min_strength: float = 0.18
var mist_max: float = 8.0               # <= this: entry mist only
var arterial_min: float = 45.0          # >= this: heavier arterial pulse
var wound_offset: float = 0.26          # torso surface offset from actor centre
var body_centre: float = 0.9            # matches world/presentation.gd actor y offset

# --- death splatter -----------------------------------------------------------
var death_stains: Dictionary = {"Low": 3, "High": 5, "Extreme": 8}
var death_drips: Dictionary = {"Low": 1, "High": 2, "Extreme": 3}
var stain_reach: float = 3.4            # radial probe length from the death point
var stain_depth: float = 6.5            # downward probe for the floor pool
var pool_size: float = 1.05             # primary floor pool diameter (m)
var stain_size: float = 0.55            # secondary splatter diameter (m)
var drip_size: float = 0.16
var drip_seconds: float = 7.0
var stain_growth_seconds: float = 0.55
var stain_fade_seconds: float = 0.0     # 0 = persist for the round (bounded pool)
var stain_normal_offset: float = 0.012  # normal offset that avoids z-fighting
var stain_opacity: float = 0.88
var stain_visibility_check: bool = true
var spurt_stain_reach: float = 2.8      # a spurt stains a wall it visibly hits
var spurt_stain_size: float = 0.32

# --- local player protection --------------------------------------------------
var coverage_limit: float = 0.7         # max angular radius / half-FOV, remote
var local_coverage_limit: float = 0.38  # stricter cap when the eye is inside it
var local_gain: float = 0.45            # extra damp for any local-actor emitter
var local_death_offset: float = 0.55    # push the local burst behind the eye (m)
var eye_fade_near: float = 0.35         # near-plane fade start (m)
var eye_fade_far: float = 1.6           # fully visible past this distance (m)

# --- surface queries ----------------------------------------------------------
var collision_mask: int = 1             # world geometry only; actors own no bodies

var _path := ""

func apply_variant(variant: String) -> bool:
	match variant:
		"", "blood", "crimson":
			fluid_color = Color(0.56, 0.022, 0.035)
			fluid_color_arterial = Color(0.72, 0.03, 0.045)
			fluid_color_mist = Color(0.44, 0.02, 0.03)
			fluid_scale = 1.0
			viscosity = 0.5
			density = 1.0
			_path = "blood"
			return true
		"synthetic":
			# Armoured-operator coolant variant. Same emission/lifecycle logic.
			fluid_color = Color(0.06, 0.55, 0.62)
			fluid_color_arterial = Color(0.10, 0.72, 0.80)
			fluid_color_mist = Color(0.05, 0.42, 0.5)
			fluid_scale = 0.82
			viscosity = 0.28
			density = 0.85
			_path = "synthetic"
			return true
	return false

func variant() -> String:
	return _path if not _path.is_empty() else "blood"

func budget(quality: String) -> int:
	return int(quality_budgets.get(quality, quality_budgets[DEFAULT_QUALITY]))

func cap(quality: String) -> int:
	return int(concurrent_cap.get(quality, concurrent_cap[DEFAULT_QUALITY]))

func stains(quality: String) -> int:
	return int(stain_caps.get(quality, stain_caps[DEFAULT_QUALITY]))

func death_stain_count(quality: String) -> int:
	return maxi(1, int(death_stains.get(quality, death_stains[DEFAULT_QUALITY])))

func death_drip_count(quality: String) -> int:
	return maxi(0, int(death_drips.get(quality, death_drips[DEFAULT_QUALITY])))

## Documented summary for reports/telemetry. Never a claim of GPU readback.
func describe() -> Dictionary:
	return {
		"variant": variant(), "fluid_color": fluid_color.to_html(false), "scale": fluid_scale,
		"viscosity": viscosity, "budgets": quality_budgets.duplicate(), "caps": concurrent_cap.duplicate(),
		"fluid_emitters": fluid_emitters, "stain_pool": stain_pool, "stain_caps": stain_caps.duplicate(),
		"full_reference": full_reference, "mist_max": mist_max, "arterial_min": arterial_min,
		"local_coverage_limit": local_coverage_limit, "local_gain": local_gain,
	}
