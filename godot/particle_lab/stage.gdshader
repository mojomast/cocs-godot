shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

void fragment() {
	vec2 p = (UV - 0.5) * 160.0;
	float radius = length(p);
	vec2 grid = abs(fract(p / 8.0 - 0.5) - 0.5) / max(fwidth(p / 8.0), vec2(0.001));
	float lines = 1.0 - min(min(grid.x, grid.y), 1.0);
	float ring = abs(fract(radius / 16.0 - 0.5) - 0.5) / max(fwidth(radius / 16.0), 0.001);
	float rings = 1.0 - min(ring, 1.0);
	float fade = 1.0 - smoothstep(22.0, 74.0, radius);
	ALBEDO = vec3(0.06, 0.24, 0.34);
	ALPHA = (lines * 0.12 + rings * 0.35) * fade;
}
