shader_type spatial;
render_mode cull_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform bool vertex_tint = false;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D data_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool albedo_is_linear = false;
// No source_color or hint_normal: retain all original normal channels, including Z.
uniform sampler2D normal_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_albedo = false;
uniform bool has_normal = false;
uniform float repeat_scale : hint_range(0.01, 8.0) = 0.5;
uniform float texture_strength : hint_range(0.0, 1.0) = 0.68;
uniform float texture_saturation : hint_range(0.0, 1.0) = 0.55;
uniform float albedo_gain = 1.0;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.24;
uniform float roughness : hint_range(0.0, 1.0) = 0.84;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D lut_r : filter_linear, repeat_enable;
uniform sampler2D lut_t : filter_linear, repeat_enable;
uniform bool has_lut = false;
uniform float lut_phase = 0.35;
uniform float lut_intensity = 0.0;
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
	vec3 p = world_position * max(repeat_scale, 0.001);
	vec3 side = step(vec3(0.0), n) * 2.0 - 1.0;
	vec2 ux = vec2(p.z * side.x, -p.y);
	vec2 uy = vec2(p.x * side.y, -p.z);
	vec2 uz = vec2(p.x * side.z, p.y);
	vec3 base = tint.rgb * (vertex_tint ? COLOR.rgb : vec3(1.0));
	vec3 texel = vec3(1.0);
	if (has_albedo) {
		if (albedo_is_linear) {
			texel = texture(data_map, ux).rgb * weights.x + texture(data_map, uy).rgb * weights.y + texture(data_map, uz).rgb * weights.z;
		} else {
			texel = texture(albedo_map, ux).rgb * weights.x + texture(albedo_map, uy).rgb * weights.y + texture(albedo_map, uz).rgb * weights.z;
		}
	}
	// Some original tiles are nearly black; finite per-family gain restores readable contrast without altering exported pixels.
	float luminance = dot(texel, vec3(0.2126, 0.7152, 0.0722));
	texel = mix(vec3(luminance), texel, texture_saturation);
	ALBEDO = base;
	if (has_albedo) {
		ALBEDO *= mix(vec3(1.0), clamp(texel * albedo_gain, vec3(0.0), vec3(1.2)), texture_strength);
	}
	if (has_normal) {
		vec3 nx = texture(normal_map, ux).xyz * 2.0 - 1.0;
		vec3 ny = texture(normal_map, uy).xyz * 2.0 - 1.0;
		vec3 nz = texture(normal_map, uz).xyz * 2.0 - 1.0;
		nx.xy /= max(nx.z, 0.15);
		ny.xy /= max(ny.z, 0.15);
		nz.xy /= max(nz.z, 0.15);
		// Tangent-plane perturbations in WORLD space: no mesh UV/tangent dependency.
		vec3 detail = vec3(0.0, -nx.y, nx.x * side.x) * weights.x;
		detail += vec3(ny.x * side.y, 0.0, -ny.y) * weights.y;
		detail += vec3(nz.x * side.z, nz.y, 0.0) * weights.z;
		detail -= n * dot(n, detail);
		n = normalize(n + detail * normal_strength);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n * (FRONT_FACING ? 1.0 : -1.0), 0.0)).xyz);
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = 0.28;
	if (has_lut) {
		float fresnel = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 3.0);
		EMISSION = mix(texture(lut_r, vec2(fresnel, fract(lut_phase))).rgb, texture(lut_t, vec2(fresnel, fract(lut_phase + 0.5))).rgb, 0.5) * lut_intensity;
	}
	// Match semantic support-surface priority exactly. Opaque world pass; no displacement or visibility change.
	DEPTH = FRAGCOORD.z - (vertex_tint ? UV.x * 0.000001 : 0.0);
}
