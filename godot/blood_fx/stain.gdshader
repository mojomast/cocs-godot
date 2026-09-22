shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Pooled surface stain. The Compatibility renderer has no Decal node, so a stain
// is a single quad lying on a real queried surface with a small normal offset
// (see blood_fx/controller.gd). World depth testing stays enabled: a stain
// behind opaque cover changes zero pixels. The quad is unshaded and unsorted
// against walls, but it never writes depth, so stains cannot occlude gameplay.

uniform vec4 fluid_color : source_color = vec4(0.56, 0.022, 0.035, 1.0);
uniform float opacity = 0.82;
uniform float seed = 0.0;
uniform float elongation = 1.0;   // > 1 stretches pools into downward drips
uniform float grain = 0.55;

float hash(float x) {
	return fract(sin(x * 127.1 + seed * 17.23) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y /= max(0.15, elongation);
	float body = 0.0;
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float a = hash(fi * 3.1 + 1.0) * 6.2831853;
		float radius = 0.16 + hash(fi * 5.7 + 2.0) * 0.5;
		vec2 center = vec2(cos(a), sin(a)) * (0.08 + hash(fi * 7.3 + 3.0) * 0.45);
		float d = length((p - center) * vec2(1.0, 0.65 + hash(fi * 2.9 + 4.0) * 0.7));
		body = max(body, 1.0 - smoothstep(radius * 0.3, radius, d));
	}
	body = max(body, (1.0 - smoothstep(0.15, 0.85, length(p))) * 0.9);
	float speck = 0.8 + grain * hash(floor(p.x * 11.0) + floor(p.y * 11.0) * 7.0);
	float alpha = body * opacity * speck;
	if (alpha < 0.006) { discard; }
	ALBEDO = fluid_color.rgb * (0.85 + 0.45 * hash(11.0));
	ALPHA = min(alpha, 0.94);
}
