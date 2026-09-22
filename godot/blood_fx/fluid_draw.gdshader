shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Fluid draw pass for GPU-simulated droplets. Ordinary world depth testing is
// kept: droplets never draw through walls. Droplets are alpha-blended blobs, not
// additive full-screen light, so the HUD and enemy silhouettes stay readable.
// Per-emitting-node material: only the uniforms below change per emitter and the
// shader resource itself is shared by every pooled node.

uniform sampler2D flow_field : filter_linear, repeat_enable;
uniform float size_scale = 1.0;      // art-direction particle scale
uniform float stretch = 0.09;        // screen-space elongation along velocity
uniform float near_fade_start = 0.3; // eye guard for in-your-face fluid (m)
uniform float near_fade_end = 1.6;
uniform float far_fade = 70.0;

varying vec4 particle_color;
varying float camera_fade;
varying float particle_seed;

void vertex() {
	particle_color = COLOR;
	particle_seed = INSTANCE_CUSTOM.x;
	vec3 world = MODEL_MATRIX[3].xyz;
	vec4 center = VIEW_MATRIX * vec4(world, 1.0);
	vec3 velocity = MODEL_MATRIX[0].xyz;
	float speed = length(velocity);
	vec4 view_velocity = VIEW_MATRIX * vec4(velocity, 0.0);
	vec2 axis = speed > 0.001 ? view_velocity.xy / speed : vec2(0.0, 1.0);
	if (length(axis) < 0.001) { axis = vec2(0.0, 1.0); }
	axis = normalize(axis);
	vec2 side = vec2(-axis.y, axis.x);
	float size = INSTANCE_CUSTOM.z * size_scale;
	float extent = 1.0 + clamp(speed * stretch, 0.0, 4.0);
	center.xy += (axis * dot(VERTEX.xy, axis) * extent + side * dot(VERTEX.xy, side)) * size;
	float depth = -center.z;
	camera_fade = smoothstep(near_fade_start, max(near_fade_end, near_fade_start + 0.05), depth)
		* (1.0 - smoothstep(far_fade, far_fade * 1.4, depth));
	POSITION = PROJECTION_MATRIX * center;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	if (r2 > 1.0) { discard; }
	if (particle_color.a * camera_fade < 0.004) { discard; }
	float body = 1.0 - smoothstep(0.15, 1.0, r2);
	float source = texture(flow_field, UV * 0.35 + particle_color.rg * 0.7 + particle_seed * 0.04).r;
	ALBEDO = particle_color.rgb * (0.78 + source * 0.5);
	EMISSION = particle_color.rgb * 0.12;
	ALPHA = min(0.85, particle_color.a * camera_fade * (0.35 + 0.65 * body) * (0.55 + source * 0.45));
}
