shader_type spatial;
render_mode cull_disabled;

// Material language surface. One base map, at most one normal map, one derived
// packed data map (R = AO, G = roughness, B = detail), one optional derived
// accent mask, one LUT accent. World-space triplanar, no UV or tangent input:
// the same mesh can be re-materialised without touching its UVs.
//
// Godot 4 GL Compatibility: no Decal/SSAO/SSR/transmission, no displacement.
// Everything here is a constant-cost fragment read set; nothing animates
// geometry and nothing writes transparency.

uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 accent_color : source_color = vec4(0.6, 0.8, 1.0, 1.0);

uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// Linear (non-sRGB) source pixels, e.g. the baked macro-organic field used as a
// base by one membrane variant. Kept separate from data_map so a linear base and
// a derived data map can coexist in one material.
uniform sampler2D linear_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D data_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mask_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D flow_map : filter_linear, repeat_enable;
uniform sampler2D lut_r : filter_linear, repeat_enable;
// The current bake's LUT T planes are entirely black; the sampler stays bound so
// a future re-bake can light it up without a shader edit. Default gain is 0.
uniform sampler2D lut_t : filter_linear, repeat_enable;

uniform bool has_albedo = false;
uniform bool has_data = false;
uniform bool has_normal = false;
uniform bool has_mask = false;
uniform bool has_flow = false;
uniform bool has_lut = false;
uniform bool albedo_is_linear = false;

// One tile per (1 / tiles_per_metre) metres. Texel density = tile_px * tiles_per_metre.
uniform float tiles_per_metre : hint_range(0.05, 4.0) = 0.5;
uniform float texture_strength : hint_range(0.0, 1.0) = 0.68;
uniform float texture_saturation : hint_range(0.0, 1.0) = 0.5;
uniform float albedo_gain : hint_range(0.0, 12.0) = 1.5;

uniform float normal_strength : hint_range(0.0, 1.0) = 0.28;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.35;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.5;
// Metres at which normal/crease detail has faded to half contribution. Kills
// the distant shimmer that a 64 px tile produces under motion.
uniform float detail_fade : hint_range(2.0, 200.0) = 26.0;

uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float roughness_variation : hint_range(0.0, 1.0) = 0.25;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.4;

uniform float lut_phase : hint_range(0.0, 1.0) = 0.35;
uniform float lut_gain : hint_range(0.0, 4.0) = 0.0;
uniform float lut_t_gain : hint_range(0.0, 4.0) = 0.0;
uniform float lut_fresnel_bias : hint_range(-1.0, 1.0) = 0.0;
// How tightly the accent hugs grazing angles. The baked LUT placement assumes
// 3.0 (the same exponent res://moth/surface.gdshader uses); a living surface
// lowers it so the band can sit on the body instead of the silhouette.
uniform float lut_fresnel_power : hint_range(0.3, 6.0) = 3.0;
uniform float accent_mask_strength : hint_range(0.0, 1.0) = 0.0;
uniform float accent_crease_strength : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed : hint_range(0.0, 2.0) = 0.0;
uniform float pulse_depth : hint_range(0.0, 1.0) = 0.0;
uniform float glow : hint_range(0.0, 1.0) = 1.0;
uniform float clock_override = -1.0;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 weights = pow(abs(n), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.00001);
	vec3 p = world_position * max(tiles_per_metre, 0.05);
	vec3 side = step(vec3(0.0), n) * 2.0 - 1.0;
	vec2 ux = vec2(p.z * side.x, -p.y);
	vec2 uy = vec2(p.x * side.y, -p.z);
	vec2 uz = vec2(p.x * side.z, p.y);

	float clock = clock_override >= 0.0 ? clock_override : TIME;
	float distance_to_camera = length(CAMERA_POSITION_WORLD - world_position);
	float detail_fade_factor = 1.0 / (1.0 + pow(distance_to_camera / max(detail_fade, 2.0), 2.0));

	vec3 texel = vec3(1.0);
	if (has_albedo) {
		if (albedo_is_linear) {
			texel = texture(linear_map, ux).rgb * weights.x + texture(linear_map, uy).rgb * weights.y + texture(linear_map, uz).rgb * weights.z;
		} else {
			texel = texture(albedo_map, ux).rgb * weights.x + texture(albedo_map, uy).rgb * weights.y + texture(albedo_map, uz).rgb * weights.z;
		}
	}
	// Original tiles are dark and saturated in places; finite per-family gain and
	// saturation move them into the shared mineral palette without editing pixels.
	float luminance = dot(texel, vec3(0.2126, 0.7152, 0.0722));
	texel = mix(vec3(luminance), texel, texture_saturation);

	float ao = 1.0;
	float derived_roughness = roughness;
	float crease = 0.0;
	if (has_data) {
		vec3 data = texture(data_map, ux).rgb * weights.x + texture(data_map, uy).rgb * weights.y + texture(data_map, uz).rgb * weights.z;
		ao = data.r;
		derived_roughness = data.g;
		crease = clamp((1.0 - data.r) * 2.5, 0.0, 1.0);
	}
	crease *= detail_fade_factor;

	ALBEDO = tint.rgb;
	if (has_albedo) {
		ALBEDO *= mix(vec3(1.0), clamp(texel * albedo_gain, vec3(0.0), vec3(1.25)), texture_strength);
	}
	ALBEDO *= mix(1.0, ao, ao_strength * mix(1.0, detail_strength, 0.35));
	// Creases darken (derived AO/detail), never brighten: this is what stops the
	// distant floor from turning into speckle.
	ALBEDO *= mix(1.0, 1.03 - 0.12 * crease, detail_strength * 0.4);

	float normal_fade = detail_fade_factor;
	if (has_normal) {
		vec3 nx = texture(normal_map, ux).xyz * 2.0 - 1.0;
		vec3 ny = texture(normal_map, uy).xyz * 2.0 - 1.0;
		vec3 nz = texture(normal_map, uz).xyz * 2.0 - 1.0;
		nx.xy /= max(nx.z, 0.15);
		ny.xy /= max(ny.z, 0.15);
		nz.xy /= max(nz.z, 0.15);
		vec3 detail = vec3(0.0, -nx.y, nx.x * side.x) * weights.x;
		detail += vec3(ny.x * side.y, 0.0, -ny.y) * weights.y;
		detail += vec3(nz.x * side.z, nz.y, 0.0) * weights.z;
		detail -= n * dot(n, detail);
		n = normalize(n + detail * normal_strength * normal_fade);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n * (FRONT_FACING ? 1.0 : -1.0), 0.0)).xyz);
	ROUGHNESS = clamp(mix(roughness, derived_roughness, roughness_variation), 0.03, 1.0);
	METALLIC = metallic;
	SPECULAR = specular_strength;

	if (has_lut && lut_gain > 0.0) {
		float fresnel = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), lut_fresnel_power);
		fresnel = clamp(fresnel + lut_fresnel_bias, 0.0, 1.0);
		float flow = 0.5;
		if (has_flow) flow = texture(flow_map, ux * 0.35 + uy * 0.15 + uz * 0.35).r;
		// Bounded breathing, not an unbounded drift: the accent stays inside its
		// LUT band at any clock and only inspects the band edges on the turn.
		float travel = 0.5 + 0.5 * sin(clock * pulse_speed * 0.6) - 0.5;
		float phase = fract(lut_phase + travel * pulse_depth + (flow - 0.5) * pulse_depth * 0.5);
		float gain = lut_gain * glow;
		if (has_mask && accent_mask_strength > 0.0) {
			float mask = texture(mask_map, ux).r * weights.x + texture(mask_map, uy).r * weights.y + texture(mask_map, uz).r * weights.z;
			gain *= mix(1.0, mask, accent_mask_strength);
		}
		if (accent_crease_strength > 0.0) gain *= mix(1.0, crease, accent_crease_strength);
		if (pulse_depth > 0.0) gain *= mix(1.0, 0.35 + 1.3 * flow, pulse_depth * 0.5);
		// The accent is a near-field signal: it falls to 15% beyond the detail
		// fade distance, so a distant floor cannot sparkle as the phase travels.
		gain *= mix(0.15, 1.0, detail_fade_factor);
		vec3 accent = texture(lut_r, vec2(fresnel, phase)).rgb;
		if (lut_t_gain > 0.0) accent = mix(accent, texture(lut_t, vec2(fresnel, fract(phase + 0.5))).rgb, 0.5 * lut_t_gain);
		EMISSION = accent_color.rgb * accent * gain;
	}
}
