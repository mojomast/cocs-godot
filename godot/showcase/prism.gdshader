shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.10, 0.45, 0.50, 1.0);
varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float scan = pow(0.5 + 0.5 * sin(local_pos.y * 7.0 - TIME * 2.0), 9.0);
	float fresnel = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 2.0);
	ALBEDO = base_color.rgb * (0.7 + scan * 0.3);
	METALLIC = 0.55;
	ROUGHNESS = 0.24;
	EMISSION = base_color.rgb * (0.4 + scan * 1.0 + fresnel * 0.65);
}
