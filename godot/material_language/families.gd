extends RefCounted
## Named material families over the baked Moth asset set. Data only: the
## library turns one family + one variant into one shared ShaderMaterial.
##
## Rules encoded here (see godot/material_language/DESIGN.md):
##   * one family = at most one base atlas, at most one normal, at most one LUT
##   * a variant may swap which single base/normal/mask pair is bound, never stack
##   * emissive is a phase-gated accent read from a baked LUT, never a uniform glow
##
## `params` are shader uniforms (res://material_language/family.gdshader).
## `texel` and `tiles_per_metre` document the honest density: texel * tiles_per_metre
## pixels per metre. The baked tiles are 48-64 px, so the language tops out at
## ~96 px/m; close-up magnification is a known limit, not hidden.
const FAMILY_SHADER := "res://material_language/family.gdshader"

const TABLE := {
	"pearl-ceramic": {
		"label": "Pearl ceramic",
		"story": "The baked mottled hex tile read as glazed ceramic: the colony's original interior mineral, warm bone over a cool mottle.",
		"roles": ["interior-wall", "pillar", "hull-panel", "relic-inlay"],
		"palette": [Color("cfc9ba"), Color("8f8a7e"), Color("5f6a72")],
		"default": {"base": "hex_paneling-mottle", "normal": "hex_paneling", "normal_source": "baked"},
		"variants": {
			"polished": {"base": "hex_paneling", "normal": "hex_paneling", "normal_source": "baked", "params": {"roughness": 0.22, "texture_strength": 0.55}},
			"cast": {"base": "weathered_concrete", "normal": "weathered_concrete", "normal_source": "baked", "params": {"roughness": 0.52, "texture_saturation": 0.3}},
			"worn": {"base": "weathered_concrete-worn", "normal": "weathered_concrete", "normal_source": "baked", "params": {"roughness": 0.58, "metallic": 0.03}},
		},
		"accent": {"lut": "entanglement-ceramic", "phase": 0.35, "gain": 0.40, "color": Color("f2e7cf"), "behavior": "glaze bloom band on rounded forms (LUT fresnel 0.53-0.66, every phase)"},
		"texel": 64,
		"params": {
			"tiles_per_metre": 0.5, "texture_strength": 0.62, "texture_saturation": 0.40, "albedo_gain": 2.0,
			"normal_strength": 0.26, "detail_strength": 0.30, "ao_strength": 0.40,
			"roughness": 0.34, "roughness_variation": 0.22, "metallic": 0.04, "specular_strength": 0.3,
			"accent_crease_strength": 0.35,
		},
	},
	"enamel-glaze": {
		"label": "Enamel glaze",
		"story": "Kiln-bright glazing over the hex panel: the clean counterpart to pearl ceramic, used where the colony keeps its instruments.",
		"roles": ["clean-room-wall", "display-housing", "medical-bay", "prop-shell"],
		"palette": [Color("e2ecef"), Color("9fb6bd"), Color("4d6b78")],
		"default": {"base": "hex_paneling", "normal": "holographic_grid", "normal_source": "baked"},
		"variants": {
			"stucco": {"base": "rough_stucco-weathered", "normal": "rough_stucco", "normal_source": "baked", "params": {"roughness": 0.34, "tiles_per_metre": 1.0}},
			"crackle": {"base": "ice-cracked", "normal": "ice", "normal_source": "baked", "params": {"roughness": 0.18, "albedo_gain": 2.4}},
			"damp": {"base": "weathered_concrete-damp", "normal": "weathered_concrete", "normal_source": "baked", "params": {"roughness": 0.24, "albedo_gain": 3.2}},
		},
		"accent": {"lut": "entanglement-ceramic", "phase": 0.72, "gain": 0.60, "color": Color("dff2f8"), "behavior": "second glaze band, hotter phase: the kiln edge of the same LUT"},
		"texel": 48,
		"params": {
			"tiles_per_metre": 0.8, "texture_strength": 0.58, "texture_saturation": 0.22, "albedo_gain": 1.9,
			"normal_strength": 0.22, "detail_strength": 0.22, "ao_strength": 0.35,
			"roughness": 0.16, "roughness_variation": 0.12, "metallic": 0.0, "specular_strength": 0.42,
			"accent_crease_strength": 0.15,
		},
	},
	"brushed-alloy": {
		"label": "Brushed alloy",
		"story": "Machined stock: cold steel with a directional grain, the working metal of catwalks, rails and hardpoints.",
		"roles": ["catwalk-rail", "machinery", "bulkhead", "weapon-hardpoint"],
		"palette": [Color("b9c5cf"), Color("78838f"), Color("3c464f")],
		"default": {"base": "brushed_metal", "normal": "metal", "normal_source": "baked"},
		"variants": {
			"plate": {"base": "diamond_plate", "normal": "diamond_plate", "normal_source": "baked", "params": {"albedo_gain": 1.9, "roughness": 0.44}},
			"grating": {"base": "metal_grating", "normal": "metal_grating", "normal_source": "baked", "params": {"albedo_gain": 1.8, "roughness": 0.46}},
			"circuit": {"base": "circuit_board-etch", "normal": "metal", "normal_source": "baked", "mask": "mask--circuit_board", "mask_strength": 0.8, "params": {"lut_gain": 0.7, "accent_mask_strength": 0.8}},
		},
		"accent": {"lut": "entanglement", "phase": 0.80, "gain": 0.38, "color": Color("7fd8ff"), "behavior": "cold low-fresnel sheen where the alloy faces the viewer (LUT fresnel 0.08-0.27)"},
		"texel": 64,
		"params": {
			"tiles_per_metre": 1.1, "texture_strength": 0.62, "texture_saturation": 0.32, "albedo_gain": 2.6,
			"normal_strength": 0.34, "detail_strength": 0.40, "ao_strength": 0.50,
			"roughness": 0.38, "roughness_variation": 0.30, "metallic": 0.45, "specular_strength": 0.42,
			"accent_crease_strength": 0.20,
		},
	},
	"oxidised-copper": {
		"label": "Oxidised copper",
		"story": "Verdigris over grey stock: the colony's decay mineral, where the old plating has been left to the weather.",
		"roles": ["pipe", "ruin-machinery", "vent-hood", "salvage-prop"],
		"palette": [Color("7dae8f"), Color("5d8a75"), Color("35473f")],
		"default": {"base": "metal-oxide", "normal": "metal_grating", "normal_source": "baked"},
		"variants": {
			"scorched": {"base": "riveted_armor-scorched", "normal": "metal_grating", "normal_source": "baked", "params": {"texture_saturation": 0.35, "metallic": 0.5}},
			"pitted": {"base": "metal", "normal": "metal_grating", "normal_source": "baked", "params": {"texture_saturation": 0.4, "albedo_gain": 2.1}},
			"riveted": {"base": "riveted_armor", "normal": "riveted_armor", "normal_source": "derived", "params": {"roughness": 0.62, "normal_strength": 0.34}},
		},
		"accent": {"lut": "entanglement-void", "phase": 0.97, "gain": 0.44, "color": Color("9ff0c8"), "behavior": "cold bloom gated into creases at the phase extreme: tarnish catching low light"},
		"texel": 64,
		"params": {
			"tiles_per_metre": 0.7, "texture_strength": 0.70, "texture_saturation": 0.78, "albedo_gain": 1.7,
			"normal_strength": 0.30, "detail_strength": 0.45, "ao_strength": 0.60,
			"roughness": 0.68, "roughness_variation": 0.35, "metallic": 0.28, "specular_strength": 0.35,
			"accent_crease_strength": 0.55,
		},
	},
	"bioluminescent-membrane": {
		"label": "Bioluminescent membrane",
		"story": "Living chitin lit from inside: the only family where the accent travels, because the surface is alive.",
		"roles": ["growth", "organic-vent", "creature-adjacent", "relic-organic"],
		"palette": [Color("4f8f86"), Color("356b66"), Color("1f3a39")],
		"default": {"base": "alien_chitin", "normal": "alien_chitin", "normal_source": "derived"},
		"variants": {
			"fringe": {"base": "alien_chitin", "normal": "grass", "normal_source": "baked", "params": {"normal_strength": 0.3}},
			"veined": {"base": "alien_chitin", "normal": "rough_stucco", "normal_source": "baked", "params": {"normal_strength": 0.32, "roughness": 0.5}},
			"matrix": {"base": "macro-organic", "normal": "alien_chitin", "normal_source": "derived", "linear_base": true, "params": {"albedo_gain": 1.6, "roughness": 0.55}},
		},
		"accent": {"lut": "entanglement-arcane", "phase": 0.85, "gain": 1.10, "color": Color("b877ff"), "behavior": "violet band (LUT fresnel 0.38-0.50) travels with the phase clock: the pulse is the creature"},
		"texel": 64,
		"params": {
			"tiles_per_metre": 1.0, "texture_strength": 0.70, "texture_saturation": 0.42, "albedo_gain": 1.0,
			"normal_strength": 0.44, "detail_strength": 0.40, "ao_strength": 0.45,
			"roughness": 0.42, "roughness_variation": 0.30, "metallic": 0.0, "specular_strength": 0.3,
			"accent_crease_strength": 0.20, "lut_fresnel_bias": 0.25, "lut_fresnel_power": 1.0,
			"pulse_speed": 0.6, "pulse_depth": 0.25,
		},
	},
	"regolith": {
		"label": "Regolith",
		"story": "Ground truth: the baked sand and rock tiles are the only place the game is honest about grain, so they own every floor that is not built.",
		"roles": ["floor", "dune", "terrain-cap", "crater-rim"],
		"palette": [Color("c6b189"), Color("8d7f61"), Color("4d453a")],
		"default": {"base": "sand", "normal": "sand", "normal_source": "baked"},
		"variants": {
			"scoured": {"base": "rock", "normal": "rock", "normal_source": "baked", "params": {"albedo_gain": 8.0, "tint": Color("9aa0a6"), "texture_saturation": 0.25}},
			"mossy": {"base": "rock-moss", "normal": "rock", "normal_source": "baked", "params": {"albedo_gain": 2.4, "tint": Color("b8bfa4")}},
			"verdant": {"base": "grass", "normal": "grass", "normal_source": "baked", "params": {"albedo_gain": 2.6, "tint": Color("a9c08a"), "texture_saturation": 0.45, "roughness": 0.88}},
		},
		"accent": {"lut": "entanglement-void", "phase": 0.97, "gain": 0.15, "color": Color("ffe3b0"), "behavior": "dust glint only in creases at the cold phase; the ground does not glow by itself"},
		"texel": 64,
		"params": {
			"tiles_per_metre": 1.5, "texture_strength": 0.72, "texture_saturation": 0.40, "albedo_gain": 1.5,
			"normal_strength": 0.42, "detail_strength": 0.40, "ao_strength": 0.55,
			"roughness": 0.94, "roughness_variation": 0.18, "metallic": 0.0, "specular_strength": 0.2,
			"accent_crease_strength": 0.85,
		},
	},
	"polar-ice": {
		"label": "Polar ice",
		"story": "Frozen water over the same mineral story: the cracked ice atlas carries the structure, the near-black solid ice tile becomes the glazed variant.",
		"roles": ["ice-floor", "frozen-wall", "crystal-prop"],
		"palette": [Color("cfe6ee"), Color("8fb6c6"), Color("3f5f6d")],
		"default": {"base": "ice-cracked", "normal": "ice", "normal_source": "baked"},
		"variants": {
			"glazed": {"base": "ice", "normal": "ice", "normal_source": "baked", "params": {"albedo_gain": 4.2, "roughness": 0.18}},
		},
		"accent": {"lut": "entanglement", "phase": 0.55, "gain": 0.40, "color": Color("a8f0ff"), "behavior": "glacial inner glow on facing surfaces (LUT fresnel 0.08-0.27): depth, not a rim"},
		"texel": 64,
		"params": {
			"tiles_per_metre": 1.0, "texture_strength": 0.62, "texture_saturation": 0.28, "albedo_gain": 2.5,
			"normal_strength": 0.38, "detail_strength": 0.34, "ao_strength": 0.42,
			"roughness": 0.22, "roughness_variation": 0.15, "metallic": 0.0, "specular_strength": 0.38,
			"accent_crease_strength": 0.20,
		},
	},
	"hazard-industrial": {
		"label": "Hazard industrial",
		"story": "Amber warning over corrugated stock: the only family whose accent is masked to the baked yellow, so the glow means 'walk here carefully'.",
		"roles": ["hazard-trim", "walkway", "door-frame", "barrier"],
		"palette": [Color("d5c9a3"), Color("8f8156"), Color("3a3a36")],
		"default": {"base": "hazard_stripes", "normal": "hazard_stripes", "normal_source": "baked", "mask": "mask--hazard_stripes", "mask_strength": 0.85},
		"variants": {
			"deck": {"base": "diamond_plate", "normal": "diamond_plate", "normal_source": "baked", "params": {"albedo_gain": 1.9, "metallic": 0.35}},
			"corrugated": {"base": "corrugated_metal", "normal": "corrugated_metal", "normal_source": "baked", "mask": "mask--hazard_stripes", "mask_strength": 0.0, "params": {"albedo_gain": 1.4, "metallic": 0.3}},
			"grating": {"base": "metal_grating", "normal": "metal_grating", "normal_source": "baked", "mask": "mask--hazard_stripes", "mask_strength": 0.0, "params": {"albedo_gain": 1.8, "metallic": 0.4}},
		},
		"accent": {"lut": "entanglement-ember", "phase": 0.30, "gain": 1.50, "color": Color("ffb347"), "behavior": "powered warning rim (LUT fresnel 0.80-1.0) masked to the baked yellow stripes; the pulse is a patrol beacon"},
		"texel": 48,
		"params": {
			"tiles_per_metre": 1.0, "texture_strength": 0.64, "texture_saturation": 0.55, "albedo_gain": 1.8,
			"normal_strength": 0.35, "detail_strength": 0.40, "ao_strength": 0.50,
			"roughness": 0.60, "roughness_variation": 0.28, "metallic": 0.25, "specular_strength": 0.3,
			"accent_mask_strength": 0.60,
			"pulse_speed": 0.35, "pulse_depth": 0.35,
		},
	},
}
