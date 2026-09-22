shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// Ordinary world depth testing stays enabled. Small alpha-blended particles,
// not additive full-screen light, preserve HUD/enemy silhouette readability.
uniform sampler2D flow_field : filter_linear, repeat_enable;
varying vec4 particle_color;
varying float camera_fade;
void vertex() {
	particle_color = COLOR;
	vec4 center = VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0);
	float dust = step(0.72, INSTANCE_CUSTOM.z);
	float size = mix(0.065, 0.20, dust);
	center.xy += VERTEX.xy * size;
	camera_fade = smoothstep(0.6, 2.5, -center.z);
	POSITION = PROJECTION_MATRIX * center;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	if (r2 > 1.0) { discard; }
	float source = texture(flow_field, UV * 0.2 + particle_color.rg).r;
	ALBEDO = particle_color.rgb;
	EMISSION = particle_color.rgb * 0.18;
	ALPHA = min(0.46, exp(-r2 * 4.0) * particle_color.a * camera_fade * (0.65 + source * 0.35));
}
