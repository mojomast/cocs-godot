shader_type spatial;
render_mode depth_draw_opaque, cull_back;
#include "res://shader_lab/moth_common.gdshaderinc"

void fragment() {
	vec3 n = normalize(object_normal);
	vec3 p = object_position * texture_scale;
	NORMAL = normalize(object_to_view * moth_local_normal(p, n));
	vec2 uv = UV * vec2(4.0, 2.0);
	vec3 flow = texture(field_map, uv + vec2(0.0, effect_time * 0.035)).rgb;
	vec2 bend = (flow.rg - vec2(0.5)) * field_strength;
	float lanes = pow(0.5 + 0.5 * cos((UV.x * 8.0 + bend.r * 0.22) * 6.283185), 10.0);
	float pulse = pow(0.5 + 0.5 * sin((UV.y * 3.5 - effect_time * 0.42 + bend.g) * 6.283185), 3.0);
	float tracer = band(sin((UV.y * 7.0 - effect_time * 0.8 + bend.r) * 3.141593), 0.15);
	float belt = band(sin(object_position.y * 4.3), 0.095);
	float fresnel = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 3.0);
	float lut = moth_lut(fresnel);
	float enabled = effect_enabled ? 1.0 : 0.0;
	float energy = lanes * (0.22 + pulse * 1.05 + tracer * 0.3) + belt * 0.12;
	ALBEDO = moth_body(p, n) * (1.0 - lanes * 0.35 * enabled);
	ROUGHNESS = mix(0.53, 0.32, lanes);
	METALLIC = 0.38;
	SPECULAR = 0.38;
	EMISSION = clamp((accent.rgb * energy + secondary.rgb * belt * (0.3 + flow.b) + accent.rgb * lut * 2.0) * intensity * enabled, vec3(0.0), vec3(4.0));
	// Intentionally opaque; Moth albedo alpha never drives visibility.
}
