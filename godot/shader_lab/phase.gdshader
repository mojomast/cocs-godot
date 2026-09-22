shader_type spatial;
render_mode depth_draw_opaque, cull_back;
#include "res://shader_lab/moth_common.gdshaderinc"

uniform float dissolve : hint_range(0.0, 1.0) = 0.43;
uniform float edge_width : hint_range(0.015, 0.2) = 0.065;
uniform float height_span : hint_range(0.1, 20.0) = 2.4;

void fragment() {
	vec3 n = normalize(object_normal);
	vec3 p = object_position * texture_scale;
	NORMAL = normalize(object_to_view * moth_local_normal(p, n));
	vec3 noise = tri_field(p * 0.75, n);
	float height = clamp(object_position.y / height_span + 0.5, 0.0, 1.0);
	float field = clamp(mix(height, noise.r, 0.35 * field_strength), 0.001, 0.999);
	float amount = effect_enabled ? dissolve : 0.0;
	if (amount >= 1.0 || (amount > 0.0 && field < amount)) { discard; }
	float edge = (1.0 - smoothstep(0.0, edge_width, field - amount)) * step(0.00001, amount);
	float fringe = (1.0 - smoothstep(edge_width, edge_width * 2.8, field - amount)) * step(0.00001, amount);
	float scan = 0.65 + 0.35 * sin(object_position.y * 55.0 + object_position.x * 7.0 - effect_time * 4.0);
	float fresnel = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 3.0);
	// Flat prop faces have near-zero Fresnel. Address the sparse source LUT with
	// the transition field as well, so its mask contributes on the cut front.
	float lut = moth_lut(clamp(0.25 + field * 0.4 + fresnel * 0.15, 0.0, 1.0));
	ALBEDO = moth_body(p, n) * mix(1.0, 0.3, fringe);
	ROUGHNESS = 0.64;
	METALLIC = 0.16;
	SPECULAR = 0.32;
	EMISSION = clamp((accent.rgb * edge * (0.8 + scan * 0.7) + secondary.rgb * fringe * (scan * 0.2 + lut * 0.3)) * intensity, vec3(0.0), vec3(4.0));
	// Binary discard retains the opaque depth/shadow path. Static prop study only;
	// this is not an actor invisibility, damage, or gameplay visibility mechanism.
}
