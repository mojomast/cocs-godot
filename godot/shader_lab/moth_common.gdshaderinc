// Moth RGB albedo is sRGB. Normals, flow/noise fields and R/T LUTs are linear.
// Never consume the original opaque alpha as presentation coverage.
uniform sampler2D base_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D field_map : filter_linear_mipmap, repeat_enable;
uniform sampler2D lut_r : filter_linear, repeat_disable;
uniform sampler2D lut_t : filter_linear, repeat_disable;
uniform vec4 body_color : source_color = vec4(0.38, 0.46, 0.55, 1.0);
uniform vec4 accent : source_color = vec4(0.12, 0.85, 1.0, 1.0);
uniform vec4 secondary : source_color = vec4(0.64, 0.35, 1.0, 1.0);
uniform float effect_time = 0.0;
uniform float intensity : hint_range(0.0, 2.5) = 1.0;
uniform float texture_scale : hint_range(0.1, 4.0) = 1.0;
uniform float texture_gain : hint_range(0.0, 8.0) = 2.2;
uniform float texture_saturation : hint_range(0.0, 1.0) = 0.28;
uniform float normal_strength : hint_range(0.0, 0.65) = 0.2;
uniform float field_strength : hint_range(0.0, 1.0) = 1.0;
uniform float lut_strength : hint_range(0.0, 2.0) = 0.65;
uniform float lut_phase : hint_range(0.0, 1.0) = 0.8;
uniform bool effect_enabled = true;
varying vec3 object_position;
varying vec3 object_normal;
varying mat3 object_to_view;

void vertex() {
	object_position = VERTEX;
	object_normal = NORMAL;
	object_to_view = mat3(VIEW_MATRIX) * MODEL_NORMAL_MATRIX;
}

vec3 tri_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / max(dot(w, vec3(1.0)), 0.00001);
}

// Separate helpers preserve sampler color-space/filter policies on Compatibility.
vec3 tri_base(vec3 p, vec3 n) {
	vec3 w = tri_weights(n);
	vec3 s = step(vec3(0.0), n) * 2.0 - 1.0;
	return texture(base_map, vec2(p.z * s.x, -p.y)).rgb * w.x
		+ texture(base_map, vec2(p.x * s.y, -p.z)).rgb * w.y
		+ texture(base_map, vec2(p.x * s.z, p.y)).rgb * w.z;
}

vec3 tri_field(vec3 p, vec3 n) {
	vec3 w = tri_weights(n);
	vec3 s = step(vec3(0.0), n) * 2.0 - 1.0;
	return texture(field_map, vec2(p.z * s.x, -p.y)).rgb * w.x
		+ texture(field_map, vec2(p.x * s.y, -p.z)).rgb * w.y
		+ texture(field_map, vec2(p.x * s.z, p.y)).rgb * w.z;
}

vec3 moth_local_normal(vec3 p, vec3 n) {
	vec3 w = tri_weights(n);
	vec3 s = step(vec3(0.0), n) * 2.0 - 1.0;
	vec3 nx = texture(normal_map, vec2(p.z * s.x, -p.y)).xyz * 2.0 - 1.0;
	vec3 ny = texture(normal_map, vec2(p.x * s.y, -p.z)).xyz * 2.0 - 1.0;
	vec3 nz = texture(normal_map, vec2(p.x * s.z, p.y)).xyz * 2.0 - 1.0;
	nx.xy /= max(nx.z, 0.2);
	ny.xy /= max(ny.z, 0.2);
	nz.xy /= max(nz.z, 0.2);
	vec3 detail = vec3(0.0, -nx.y, nx.x * s.x) * w.x
		+ vec3(ny.x * s.y, 0.0, -ny.y) * w.y
		+ vec3(nz.x * s.z, nz.y, 0.0) * w.z;
	detail -= n * dot(n, detail);
	return normalize(n + detail * normal_strength);
}

vec3 moth_body(vec3 p, vec3 n) {
	vec3 tile = tri_base(p, n);
	float luminance = dot(tile, vec3(0.2126, 0.7152, 0.0722));
	tile = mix(vec3(luminance), tile, texture_saturation);
	return clamp(body_color.rgb * mix(vec3(0.6), tile * texture_gain, 0.7), vec3(0.0), vec3(1.0));
}

float moth_lut(float fresnel) {
	// Retain source R/T half-phase semantics and linear channels; these are masks,
	// not colorful gradients. Color comes from the explicitly selected palette.
	vec3 r = texture(lut_r, vec2(fresnel, lut_phase)).rgb;
	vec3 t = texture(lut_t, vec2(fresnel, fract(lut_phase + 0.5))).rgb;
	return clamp(dot(mix(r, t, 0.5), vec3(0.333333)) * lut_strength, 0.0, 2.0);
}

float band(float wave, float width) {
	float aa = max(fwidth(wave), 0.002);
	return 1.0 - smoothstep(width - aa, width + aa, abs(wave));
}
