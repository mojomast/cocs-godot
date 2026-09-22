shader_type spatial;
render_mode cull_disabled;

uniform vec4 deep_color : source_color = vec4(0.018, 0.21, 0.25, 1.0);
uniform vec4 crest_color : source_color = vec4(0.21, 0.72, 0.71, 1.0);
uniform sampler2D flow_map : repeat_enable, filter_linear;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float a = sin(p.x * 2.7 + p.y * 1.6 + TIME * 1.15);
	float b = sin(p.y * 4.2 - p.x * 0.7 - TIME * 0.8);
	float flow = texture(flow_map, p * 0.11 + vec2(TIME * 0.017, TIME * -0.024)).r;
	float crest = pow(clamp((a + b) * 0.24 + 0.5, 0.0, 1.0), 6.0);
	ALBEDO = mix(deep_color.rgb, crest_color.rgb, crest * 0.48 + flow * 0.12);
	NORMAL_MAP = normalize(vec3(a * 0.16, b * 0.13, 1.0)) * 0.5 + 0.5;
	ROUGHNESS = 0.22;
	METALLIC = 0.36;
	EMISSION = crest_color.rgb * crest * 0.12;
}
