shader_type spatial;
render_mode unshaded, cull_disabled;

void fragment() {
	float pulse = 0.93 + 0.07 * sin(TIME * 0.23 + UV.x * 8.0);
	ALBEDO = vec3(0.32, 0.94, 0.89) * pulse;
}
