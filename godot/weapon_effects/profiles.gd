extends RefCounted
## Presentation dimensions in metres, source weapon ordering. No gameplay parameters.
##
## `size`/`life`/`smoke` are the original base numbers. The `flash_*`, `bright`,
## `light*` and `tracer_*` fields are the weapon-oomph additions: per-weapon
## multipliers and character for the muzzle bloom, an optional short barrel light
## and the ray tracer. They are presentation constants only and never feed aim,
## spread, ammo, damage or any authoritative value.
##
##  flash_scale   bloom/jet size multiplier on `size`
##  flash_life    bloom/jet lifetime multiplier on `life`
##  bright        shader core gain (whiter, hotter core)
##  light         barrel-light energy; 0.0 = no light (pooled, Extreme only)
##  light_range   barrel-light omni range in metres
##  light_life    barrel-light lifetime in seconds
##  tracer_width  hot core half-width in metres
##  tracer_life   full ray lifetime in seconds (trail never outlives the pool)
##  tracer_core   0..1 white-hot mix of the core strip
##  tracer_glow   outer glow alpha of the widest strip
##  tracer_fade   exponential fade power applied over the lifetime
const ITEMS := [
	{"name":"Pulse Rifle", "color":Color("70ffe6"), "mode":0, "size":0.20, "life":0.075, "smoke":0.20, "case":true, "sheet":"pulse",
		"flash_scale":1.45, "flash_life":1.55, "bright":1.20, "light":0.0, "light_range":0.0, "light_life":0.10,
		"tracer_width":0.021, "tracer_life":0.105, "tracer_core":0.60, "tracer_glow":0.16, "tracer_fade":1.1},
	{"name":"Rocket Launcher", "color":Color("ffad61"), "mode":1, "size":0.36, "life":0.14, "smoke":0.65, "case":false, "sheet":"",
		"flash_scale":1.60, "flash_life":1.40, "bright":1.35, "light":3.6, "light_range":9.5, "light_life":0.16,
		"tracer_width":0.030, "tracer_life":0.16, "tracer_core":0.55, "tracer_glow":0.22, "tracer_fade":1.05},
	{"name":"Rail Lance", "color":Color("bb9aff"), "mode":2, "size":0.26, "life":0.12, "smoke":0.26, "case":false, "sheet":"",
		"flash_scale":1.50, "flash_life":1.60, "bright":1.45, "light":2.0, "light_range":7.0, "light_life":0.14,
		"tracer_width":0.036, "tracer_life":0.30, "tracer_core":0.95, "tracer_glow":0.26, "tracer_fade":0.7},
	{"name":"Scattergun", "color":Color("ffde87"), "mode":3, "size":0.34, "life":0.115, "smoke":0.48, "case":false, "sheet":"",
		"flash_scale":1.75, "flash_life":1.40, "bright":1.30, "light":2.8, "light_range":8.0, "light_life":0.13,
		"tracer_width":0.011, "tracer_life":0.09, "tracer_core":0.40, "tracer_glow":0.12, "tracer_fade":1.5},
	{"name":"Plasma Driver", "color":Color("72cfff"), "mode":4, "size":0.30, "life":0.13, "smoke":0.18, "case":false, "sheet":"plasma",
		"flash_scale":1.40, "flash_life":1.55, "bright":1.30, "light":1.0, "light_range":5.5, "light_life":0.12,
		"tracer_width":0.026, "tracer_life":0.21, "tracer_core":0.80, "tracer_glow":0.20, "tracer_fade":1.0},
	{"name":"Grenade Launcher", "color":Color("ff806b"), "mode":5, "size":0.30, "life":0.16, "smoke":0.60, "case":false, "sheet":"",
		"flash_scale":1.65, "flash_life":1.45, "bright":1.30, "light":3.0, "light_range":8.5, "light_life":0.15,
		"tracer_width":0.020, "tracer_life":0.14, "tracer_core":0.50, "tracer_glow":0.18, "tracer_fade":1.15},
	{"name":"Shock Beam", "color":Color("8ce8ff"), "mode":6, "size":0.28, "life":0.13, "smoke":0.16, "case":false, "sheet":"shock",
		"flash_scale":1.45, "flash_life":1.55, "bright":1.40, "light":1.4, "light_range":6.0, "light_life":0.13,
		"tracer_width":0.036, "tracer_life":0.24, "tracer_core":0.90, "tracer_glow":0.24, "tracer_fade":0.8},
	{"name":"Flak Cannon", "color":Color("ffd166"), "mode":7, "size":0.40, "life":0.145, "smoke":0.55, "case":false, "sheet":"",
		"flash_scale":1.80, "flash_life":1.40, "bright":1.35, "light":3.2, "light_range":9.0, "light_life":0.14,
		"tracer_width":0.013, "tracer_life":0.095, "tracer_core":0.45, "tracer_glow":0.13, "tracer_fade":1.5},
	{"name":"Marksman Rifle", "color":Color("ffd27a"), "mode":8, "size":0.23, "life":0.085, "smoke":0.34, "case":true, "sheet":"",
		"flash_scale":1.50, "flash_life":1.60, "bright":1.30, "light":1.8, "light_range":6.5, "light_life":0.12,
		"tracer_width":0.019, "tracer_life":0.15, "tracer_core":0.75, "tracer_glow":0.18, "tracer_fade":1.05},
	{"name":"Submachine Gun", "color":Color("8affc1"), "mode":9, "size":0.15, "life":0.055, "smoke":0.18, "case":true, "sheet":"",
		"flash_scale":1.35, "flash_life":1.70, "bright":1.15, "light":0.0, "light_range":0.0, "light_life":0.08,
		"tracer_width":0.017, "tracer_life":0.08, "tracer_core":0.35, "tracer_glow":0.10, "tracer_fade":2.1},
]
