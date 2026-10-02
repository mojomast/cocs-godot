shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
void fragment() {
	float d = min(1.0, length(UV * 2.0 - 1.0));
	// effects-fx.mjs makeRadialMask(48, {rim:.75,rimWidth:.1}).
	float mask = min(1.0, pow(max(0.0, 1.0-d), 1.6) + 0.75 * exp(-pow((d-0.74)/0.1, 2.0)));
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * mask;
}
