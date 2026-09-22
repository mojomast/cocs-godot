shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled, fog_disabled;

uniform float phase = 0.0;
uniform float strength = 0.66;

void vertex() {
	// Only the high-altitude curtain moves. No displacement on collision surfaces.
	VERTEX.z += sin(UV.x * 21.0 + TIME * 0.12 + phase) * UV.y * 1.8;
}

void fragment() {
	float t = TIME * 0.075 + phase;
	float fold = sin(UV.x * 39.0 + sin(UV.x * 13.0 + t) * 2.4 + t);
	float threads = 0.55 + 0.45 * sin(UV.x * 760.0 + sin(UV.x * 82.0 + t) * 5.0);
	float bottom = 0.06 + 0.07 * sin(UV.x * 22.0 + t);
	float envelope = smoothstep(bottom, bottom + 0.11, UV.y) * (1.0 - smoothstep(0.24, 0.98, UV.y));
	envelope *= smoothstep(0.0, 0.12, UV.x) * (1.0 - smoothstep(0.84, 1.0, UV.x));
	vec3 green = vec3(0.16, 0.90, 0.62);
	vec3 blue = vec3(0.14, 0.36, 0.78);
	vec3 violet = vec3(0.52, 0.20, 0.66);
	vec3 color = mix(green, blue, smoothstep(0.10, 0.65, UV.y));
	color = mix(color, violet, smoothstep(0.52, 0.97, UV.y));
	ALBEDO = color;
	ALPHA = envelope * (0.56 + fold * 0.17) * (0.72 + threads * 0.28) * strength;
}
