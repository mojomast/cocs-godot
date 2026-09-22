shader_type spatial;
render_mode cull_disabled;

// Moth's world-space sampling, without its source-map surface-priority DEPTH write.
// This standalone opaque map can retain early depth rejection in Compatibility.
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_albedo = false;
uniform bool has_normal = false;
uniform float repeat_scale = 0.5;
uniform float texture_strength = 0.6;
uniform float texture_saturation = 0.1;
uniform float albedo_gain = 1.5;
uniform float normal_strength = 0.13;
uniform float roughness = 0.84;
uniform float metallic = 0.0;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 weights = pow(abs(n), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.0001);
	vec3 p = world_position * repeat_scale;
	vec3 side = step(vec3(0.0), n) * 2.0 - 1.0;
	vec2 ux = vec2(p.z * side.x, -p.y);
	vec2 uy = vec2(p.x * side.y, -p.z);
	vec2 uz = vec2(p.x * side.z, p.y);
	vec3 texel = vec3(1.0);
	if (has_albedo) {
		texel = texture(albedo_map, ux).rgb * weights.x + texture(albedo_map, uy).rgb * weights.y + texture(albedo_map, uz).rgb * weights.z;
	}
	float luminance = dot(texel, vec3(0.2126, 0.7152, 0.0722));
	texel = mix(vec3(luminance), texel, texture_saturation);
	ALBEDO = tint.rgb * mix(vec3(1.0), clamp(texel * albedo_gain, vec3(0.0), vec3(1.2)), texture_strength);
	if (has_normal) {
		vec3 nx = texture(normal_map, ux).xyz * 2.0 - 1.0;
		vec3 ny = texture(normal_map, uy).xyz * 2.0 - 1.0;
		vec3 nz = texture(normal_map, uz).xyz * 2.0 - 1.0;
		vec3 detail = vec3(0.0, -nx.y, nx.x * side.x) * weights.x;
		detail += vec3(ny.x * side.y, 0.0, -ny.y) * weights.y;
		detail += vec3(nz.x * side.z, nz.y, 0.0) * weights.z;
		detail -= n * dot(n, detail);
		n = normalize(n + detail * normal_strength);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n * (FRONT_FACING ? 1.0 : -1.0), 0.0)).xyz);
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = 0.22;
}
