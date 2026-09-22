shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;
#include "res://shader_lab/moth_common.gdshaderinc"

uniform sampler2D motif_map : source_color, filter_linear_mipmap, repeat_enable;
uniform float opacity : hint_range(0.0, 0.8) = 0.68;

void fragment() {
	vec3 n = normalize(object_normal);
	vec3 p = object_position * texture_scale;
	NORMAL = normalize(object_to_view * moth_local_normal(p, n));
	float rim = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 1.7);
	vec3 field = tri_field(p * 0.7, n);
	float distortion = (field.r - 0.5) * field_strength;
	float t = effect_time;
	float scan = band(sin(object_position.y * 9.0 - t * 2.4 + distortion), 0.12);
	float interference = 0.5 + 0.5 * sin(object_position.y * 23.0 + object_position.x * 11.0 + t * 1.8);
	vec2 cells = UV * vec2(24.0, 12.0);
	float grid = max(band(sin(cells.x * 3.141593), 0.045), band(sin(cells.y * 3.141593), 0.045));
	// Shipped effect-shield alpha is 255. Its RGB motif modulates detail only.
	vec3 motif = texture(motif_map, UV * vec2(3.0, 2.0) + vec2(t * 0.025, 0.0)).rgb;
	float source_detail = clamp(dot(motif, vec3(0.2126, 0.7152, 0.0722)) * 12.0, 0.0, 1.0);
	float tile = dot(tri_base(p, n), vec3(0.333333));
	float lut = moth_lut(rim * rim);
	vec3 color = mix(accent.rgb, secondary.rgb, clamp(rim * 0.65 + interference * 0.18, 0.0, 1.0));
	float detail = grid * 0.24 + scan * 0.3 + source_detail * 0.4;
	float enabled = effect_enabled ? 1.0 : 0.0;
	ALBEDO = clamp(color * (0.65 + detail + tile * texture_gain), vec3(0.0), vec3(1.0));
	EMISSION = clamp(color * (0.2 + lut * 2.0) * intensity, vec3(0.0), vec3(3.0));
	// Closed, outward-facing shell: test opaque depth but never write transparent
	// depth. There is no screen/depth texture, rectangle, or full-screen pass.
	ALPHA = clamp(opacity * (0.035 + rim * 0.7 + detail + lut) * intensity * enabled, 0.0, 0.8);
}
