shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX *= mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float flake = 1.0 - smoothstep(0.08, 0.48, length(UV - vec2(0.5)));
	ALBEDO = vec3(0.69, 0.86, 0.92);
	ALPHA = flake * COLOR.a * 0.40;
}
