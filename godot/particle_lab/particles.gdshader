shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

#include "res://particle_lab/trajectories.gdshaderinc"

uniform bool analytic_backend = false;
uniform mat4 field_transform;
uniform float particle_size = 0.34;
uniform float intensity = 0.85;
uniform sampler2D effect_frame : source_color, filter_linear, repeat_disable;
varying vec3 particle_color;

void vertex() {
	vec4 seed = seed_for(uint(INSTANCE_ID));
	vec3 center;
	if (analytic_backend) {
		// Intentionally ignore the zero-initialized MultiMesh transforms. One
		// bounded buffer/draw, no per-instance CPU initialization or animation.
		center = (field_transform * vec4(field_target(seed, field_clock), 1.0)).xyz;
		particle_color = field_color(seed);
	} else {
		center = MODEL_MATRIX[3].xyz;
		particle_color = COLOR.rgb;
	}
	vec4 view_center = VIEW_MATRIX * vec4(center, 1.0);
	float size = particle_size * (0.6 + seed.w * 0.8);
	// Camera-facing small quads. The glow is local analytic coverage, not a
	// fullscreen/unsupported glow effect or a large overdraw-heavy billboard.
	view_center.xy += VERTEX.xy * size;
	POSITION = PROJECTION_MATRIX * view_center;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	if (r2 > 1.0) { discard; }
	vec3 source = texture(effect_frame, UV).rgb;
	vec3 background = texture(effect_frame, vec2(0.0)).rgb;
	vec3 signal_color = max(source - background, vec3(0.0));
	float signal_strength = max(signal_color.r, max(signal_color.g, signal_color.b));
	// Source frames have alpha=1 everywhere. Derive soft coverage deliberately;
	// never use that opaque alpha as a square billboard's coverage.
	float core = exp(-r2 * 12.0);
	float halo = exp(-r2 * 3.8) * 0.22;
	float coverage = (core + halo + signal_strength * 1.5) * (1.0 - smoothstep(0.64, 1.0, r2));
	ALBEDO = particle_color;
	EMISSION = particle_color * 0.3 + signal_color * 0.2;
	ALPHA = clamp(coverage * intensity, 0.0, 1.0);
}
