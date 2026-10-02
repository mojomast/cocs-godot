shader_type spatial;
render_mode cull_disabled;

// Private map finish fork of material_language/family.gdshader at 068e3ce2.
// Keep the family sampler/response contract explicit; no runtime string injection.
// Geometry, UVs, clock, accent and two-sided world-normal conventions are retained.
// Font-face exclusion is owned by binder.gd, not this architectural surface shader.
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 accent_color : source_color = vec4(0.6, 0.8, 1.0, 1.0);
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D linear_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D data_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mask_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D flow_map : filter_linear, repeat_enable;
uniform sampler2D lut_r : filter_linear, repeat_enable;
uniform sampler2D lut_t : filter_linear, repeat_enable;
uniform bool has_albedo = false;
uniform bool has_data = false;
uniform bool has_normal = false;
uniform bool has_mask = false;
uniform bool has_flow = false;
uniform bool has_lut = false;
uniform bool albedo_is_linear = false;
uniform float tiles_per_metre : hint_range(0.05, 4.0) = 0.5;
uniform float texture_strength : hint_range(0.0, 1.0) = 0.68;
uniform float texture_saturation : hint_range(0.0, 1.0) = 0.5;
uniform float albedo_gain : hint_range(0.0, 12.0) = 1.5;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.28;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.35;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.5;
uniform float detail_fade : hint_range(2.0, 200.0) = 26.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float roughness_variation : hint_range(0.0, 1.0) = 0.25;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.4;
uniform float lut_phase : hint_range(0.0, 1.0) = 0.35;
uniform float lut_gain : hint_range(0.0, 4.0) = 0.0;
uniform float lut_t_gain : hint_range(0.0, 4.0) = 0.0;
uniform float lut_fresnel_bias : hint_range(-1.0, 1.0) = 0.0;
uniform float lut_fresnel_power : hint_range(0.3, 6.0) = 3.0;
uniform float accent_mask_strength : hint_range(0.0, 1.0) = 0.0;
uniform float accent_crease_strength : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed : hint_range(0.0, 2.0) = 0.0;
uniform float pulse_depth : hint_range(0.0, 1.0) = 0.0;
uniform float glow : hint_range(0.0, 1.0) = 1.0;
uniform float clock_override = -1.0;
uniform float macro_tiles_per_metre = 0.06;
uniform float macro_strength = 0.0;
uniform float wear_strength = 0.0;
uniform float wear_height_min = 0.0;
uniform float wear_height_max = 2.0;
uniform float wear_roughness = 0.95;
uniform vec4 wear_tint : source_color = vec4(0.4, 0.35, 0.3, 1.0);
uniform mat4 map_inverse;
// 0 none, 1 organic, 2 manufactured; source schema accepts names only.
uniform int variation_mode = 0;
uniform float variation_strength : hint_range(0.0, 1.0) = 0.0;
uniform float variation_scale : hint_range(0.01, 1.0) = 0.08;
uniform int variation_seed = 0;
varying vec3 world_position;
varying vec3 world_normal;

// Continuous C1 value field: no cell-local UV jumps, derivatives or clocks.
// Split the integer before float conversion so large author seeds retain low bits.
float spatial_hash(vec3 cell) {
	vec2 seed = vec2(float(variation_seed % 4093), float(variation_seed / 4093));
	return fract(sin(dot(cell, vec3(127.1, 311.7, 74.7)) + dot(seed, vec2(0.0137, 0.0173))) * 43758.5453);
}
float spatial_field(vec3 position) {
	vec3 cell = floor(position);
	vec3 f = fract(position);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(spatial_hash(cell), spatial_hash(cell + vec3(1, 0, 0)), f.x),
		mix(spatial_hash(cell + vec3(0, 1, 0)), spatial_hash(cell + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(spatial_hash(cell + vec3(0, 0, 1)), spatial_hash(cell + vec3(1, 0, 1)), f.x),
		mix(spatial_hash(cell + vec3(0, 1, 1)), spatial_hash(cell + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// Two globally affine micro mappings. No random rotation/mirroring: all normal
// components stay in their original projected axes. Manufactured never enters
// the second read, retaining panel courses, brushing and rivet pitch exactly.
// Texture gradients use each affine scale, never a hash-discontinuous UV.
vec3 surface_sample(sampler2D map, vec2 uv, float blend, vec2 offset) {
	vec3 base = texture(map, uv).rgb;
	if (variation_mode == 1 && variation_strength > 0.0) {
		vec3 other = textureGrad(map, uv * 0.731 + offset, dFdx(uv) * 0.731, dFdy(uv) * 0.731).rgb;
		return mix(base, other, blend);
	}
	return base;
}

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
	float field = 0.5;
	float amount = variation_mode == 0 ? 0.0 : variation_strength;
	if (amount > 0.0) field = spatial_field(world_position * variation_scale);
	float blend = amount * mix(0.35, 0.65, field);
	// Seed changes offsets without moving base texture courses. Same offsets and
	// blend for albedo/linear base, packed data, normal and accent mask.
	vec2 offset = vec2(float(variation_seed % 4093), float(variation_seed / 4093));
	offset = fract(offset * vec2(0.754877, 0.569841)) + vec2(0.317, 0.619);
	vec3 texel = vec3(1.0);
	if (has_albedo) {
		if (albedo_is_linear) {
			texel = surface_sample(linear_map, ux, blend, offset) * weights.x + surface_sample(linear_map, uy, blend, offset) * weights.y + surface_sample(linear_map, uz, blend, offset) * weights.z;
		} else {
			texel = surface_sample(albedo_map, ux, blend, offset) * weights.x + surface_sample(albedo_map, uy, blend, offset) * weights.y + surface_sample(albedo_map, uz, blend, offset) * weights.z;
		}
	}
	float luminance = dot(texel, vec3(0.2126, 0.7152, 0.0722));
	texel = mix(vec3(luminance), texel, texture_saturation);
	float ao = 1.0;
	float derived_roughness = roughness;
	float crease = 0.0;
	if (has_data) {
		vec3 data = surface_sample(data_map, ux, blend, offset) * weights.x + surface_sample(data_map, uy, blend, offset) * weights.y + surface_sample(data_map, uz, blend, offset) * weights.z;
		ao = data.r;
		derived_roughness = data.g;
		crease = clamp((1.0 - data.r) * 2.5, 0.0, 1.0);
	}
	crease *= detail_fade_factor;
	ALBEDO = tint.rgb;
	if (has_albedo) ALBEDO *= mix(vec3(1.0), clamp(texel * albedo_gain, vec3(0.0), vec3(1.25)), texture_strength);
	ALBEDO *= mix(1.0, ao, ao_strength * mix(1.0, detail_strength, 0.35));
	ALBEDO *= mix(1.0, 1.03 - 0.12 * crease, detail_strength * 0.4);
	if (has_normal) {
		vec3 nx = surface_sample(normal_map, ux, blend, offset) * 2.0 - 1.0;
		vec3 ny = surface_sample(normal_map, uy, blend, offset) * 2.0 - 1.0;
		vec3 nz = surface_sample(normal_map, uz, blend, offset) * 2.0 - 1.0;
		nx.xy /= max(nx.z, 0.15);
		ny.xy /= max(ny.z, 0.15);
		nz.xy /= max(nz.z, 0.15);
		vec3 detail = vec3(0.0, -nx.y, nx.x * side.x) * weights.x;
		detail += vec3(ny.x * side.y, 0.0, -ny.y) * weights.y;
		detail += vec3(nz.x * side.z, nz.y, 0.0) * weights.z;
		detail -= n * dot(n, detail);
		n = normalize(n + detail * normal_strength * detail_fade_factor);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n * (FRONT_FACING ? 1.0 : -1.0), 0.0)).xyz);
	ROUGHNESS = clamp(mix(roughness, derived_roughness, roughness_variation), 0.03, 1.0);
	// Restrained, neutral macro response; never random hue or high-frequency noise.
	ALBEDO *= 1.0 + (field - 0.5) * amount * 0.16;
	ROUGHNESS = clamp(ROUGHNESS + (field - 0.5) * amount * 0.05, 0.03, 1.0);
	if (has_data && (macro_strength > 0.0 || wear_strength > 0.0)) {
		// Preserve original baked macro/deposit mapping and local-height interval.
		vec3 mp = world_position * macro_tiles_per_metre;
		vec3 macro = texture(data_map, mp.zy).rgb * weights.x + texture(data_map, mp.xz).rgb * weights.y + texture(data_map, mp.xy).rgb * weights.z;
		float local_height = (map_inverse * vec4(world_position, 1.0)).y;
		float band = smoothstep(wear_height_min, wear_height_min + 0.15, local_height) * (1.0 - smoothstep(wear_height_max - 0.15, wear_height_max, local_height));
		float deposit = clamp((1.0 - macro.r) * 2.0, 0.0, 1.0) * band * wear_strength;
		ALBEDO *= mix(1.0, 0.65 + macro.b * 0.5, macro_strength);
		ALBEDO = mix(ALBEDO, wear_tint.rgb, deposit);
		ROUGHNESS = mix(ROUGHNESS, wear_roughness, deposit);
	}
	METALLIC = metallic;
	SPECULAR = specular_strength;
	if (has_lut && lut_gain > 0.0) {
		float fresnel = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), lut_fresnel_power);
		fresnel = clamp(fresnel + lut_fresnel_bias, 0.0, 1.0);
		float flow = 0.5;
		if (has_flow) flow = texture(flow_map, ux * 0.35 + uy * 0.15 + uz * 0.35).r;
		float travel = 0.5 + 0.5 * sin(clock * pulse_speed * 0.6) - 0.5;
		float phase = fract(lut_phase + travel * pulse_depth + (flow - 0.5) * pulse_depth * 0.5);
		float gain = lut_gain * glow;
		if (has_mask && accent_mask_strength > 0.0) {
			float mask = dot(vec3(surface_sample(mask_map, ux, blend, offset).r, surface_sample(mask_map, uy, blend, offset).r, surface_sample(mask_map, uz, blend, offset).r), weights);
			gain *= mix(1.0, mask, accent_mask_strength);
		}
		if (accent_crease_strength > 0.0) gain *= mix(1.0, crease, accent_crease_strength);
		if (pulse_depth > 0.0) gain *= mix(1.0, 0.35 + 1.3 * flow, pulse_depth * 0.5);
		gain *= mix(0.15, 1.0, detail_fade_factor);
		vec3 accent = texture(lut_r, vec2(fresnel, phase)).rgb;
		if (lut_t_gain > 0.0) accent = mix(accent, texture(lut_t, vec2(fresnel, fract(phase + 0.5))).rgb, 0.5 * lut_t_gain);
		EMISSION = accent_color.rgb * accent * gain;
	}
}
