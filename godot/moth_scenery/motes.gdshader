shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D dust_field : filter_linear, repeat_enable;
uniform sampler2D flow_field : filter_linear, repeat_enable;
uniform sampler2D snow_frame : source_color, filter_linear, repeat_enable;
uniform vec4 tint : source_color = vec4(0.7, 0.7, 0.7, 1.0);
uniform float height = 2.4;
uniform float size = 0.045;
uniform float opacity = 0.30;
uniform float fall_speed = 0.035;
uniform bool snow = false;
uniform float clock_override = -1.0;
varying float seed;
varying float fade;

void vertex() {
	float clock = clock_override >= 0.0 ? clock_override : TIME;
	seed = INSTANCE_CUSTOM.r;
	float age = fract(INSTANCE_CUSTOM.g + clock * fall_speed);
	vec3 center = MODEL_MATRIX[3].xyz;
	center.y += (INSTANCE_CUSTOM.g - age) * height;
	center.x += sin(clock * 0.21 + seed * 30.0) * 0.18;
	center.z += cos(clock * 0.16 + seed * 25.0) * 0.18;
	fade = smoothstep(0.0, 0.12, age) * (1.0 - smoothstep(0.82, 1.0, age));
	vec4 view_center = VIEW_MATRIX * vec4(center, 1.0);
	view_center.xy += VERTEX.xy * size * (0.65 + INSTANCE_CUSTOM.b * 0.7);
	POSITION = PROJECTION_MATRIX * view_center;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radial = 1.0 - smoothstep(0.10, 1.0, dot(p, p));
	float grain = texture(dust_field, UV * 0.7 + vec2(seed, seed * 3.0)).r;
	float flow = texture(flow_field, vec2(seed, seed * 2.0)).r;
	// Source snow alpha is opaque. Only its RGB contrast modulates the tiny
	// radial mote; original dark square backgrounds are never emitted as quads.
	float weather = snow ? dot(texture(snow_frame, UV).rgb, vec3(0.3333)) : 0.0;
	ALBEDO = tint.rgb;
	ALPHA = radial * fade * opacity * (0.50 + grain * 0.30 + flow * 0.12 + weather * 0.08);
}
