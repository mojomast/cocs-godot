shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;
// Showcase's shared Moth field, triplanar normal and R/T interference functions.
#include "res://shader_lab/moth_common.gdshaderinc"
uniform sampler2D motif_map : source_color, filter_linear_mipmap, repeat_enable;
uniform float opacity = 0.3;
uniform float hit_age = 2.0;
uniform vec3 hit_direction = vec3(0.0, 0.0, 1.0);
uniform bool hit_direction_known = false;
uniform float directional = 0.0;
uniform float arc_cos = 0.8;
uniform float style = 0.0; // 0 protection/armor, 1 phase, 2 recovery, 3 shatter
uniform float progress = 0.0;
uniform bool low_quality = false;

void fragment() {
	vec3 n = normalize(object_normal);
	vec3 p = object_position * texture_scale;
	vec3 field = low_quality ? vec3(0.5) : tri_field(p * 0.7, n);
	NORMAL = normalize(object_to_view * (low_quality ? n : moth_local_normal(p, n)));
	float rim = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 1.7);
	float distortion = (field.r - 0.5) * field_strength;
	float scan = band(sin(object_position.y * 9.0 - effect_time * 2.4 + distortion), 0.10);
	float interference = 0.5 + 0.5 * sin(object_position.y * 23.0 + object_position.x * 11.0 + effect_time * 1.8);
	vec2 cells = UV * vec2(24.0, 12.0);
	float grid = max(band(sin(cells.x * 3.141593), 0.035), band(sin(cells.y * 3.141593), 0.035));
	float motif = low_quality ? 0.0 : clamp(dot(texture(motif_map, UV * vec2(3.0, 2.0)).rgb, vec3(0.33333)) * 8.0, 0.0, 1.0);
	float lut = low_quality ? 0.0 : moth_lut(rim * rim);
	float angle = acos(clamp(dot(n, normalize(hit_direction)), -1.0, 1.0));
	float ripple = exp(-pow((angle - hit_age * 5.5) * 10.0, 2.0)) * max(0.0, 1.0 - hit_age / 0.6);
	if (!hit_direction_known) { ripple = exp(-hit_age * 12.0) * 0.22; }
	vec3 color = mix(accent.rgb, secondary.rgb, rim * 0.65 + interference * 0.18);
	float detail = grid * 0.20 + scan * 0.15 + motif * 0.08;
	float coverage = opacity * (0.018 + rim * 0.75 + detail + lut * 0.10) + ripple * 0.48;
	if (directional > 0.5) {
		// Source npcShield is a frontal reduction cone, not an omnidirectional pool.
		float facing = dot(normalize(vec3(n.x, 0.00001, n.z)), vec3(0.0, 0.0, -1.0));
		coverage *= smoothstep(arc_cos - 0.06, arc_cos + 0.02, facing);
	}
	if (style > 0.5 && style < 1.5) {
		// Showcase phase's height/noise cut front, on an additive visual shell only.
		float cut = clamp(mix(object_position.y * 0.5 + 0.5, field.r, 0.35 * field_strength), 0.001, 0.999);
		float edge = 1.0 - smoothstep(0.02, 0.13, abs(cut - progress));
		coverage = (edge * 0.6 + grid * rim * 0.13) * (1.0 - progress);
		color = mix(secondary.rgb, accent.rgb, edge);
	} else if (style > 1.5 && style < 2.5) {
		coverage = opacity * (0.3 + scan * 0.35 + rim * 0.35) * (1.0 - progress);
	} else if (style > 2.5) {
		float shards = step(0.65, sin(cells.x * 1.7 + floor(cells.y) * 13.0)) * step(0.1, sin(cells.y * 2.3));
		coverage = shards * (rim * 0.4 + 0.25) * (1.0 - progress);
	}
	ALBEDO = clamp(color * (0.7 + detail + ripple), vec3(0.0), vec3(1.0));
	EMISSION = clamp(color * (0.35 + lut + ripple * 2.0) * intensity, vec3(0.0), vec3(3.0));
	// Original Moth alpha is opaque; never use it as coverage. Opaque world depth
	// is tested normally. No screen texture, depth disable, or full-screen pass.
	ALPHA = clamp(coverage * intensity * (effect_enabled ? 1.0 : 0.0), 0.0, 0.62);
}
