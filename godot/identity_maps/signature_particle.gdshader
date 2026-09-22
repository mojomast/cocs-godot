shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
// Bounded signature-effect billboard. Procedural soft falloff: no texture, so a
// map's effect pass adds zero bytes to the texture budget. Tint comes from the
// map palette; per-particle COLOR (from the process material's colour ramp)
// only modulates it, and alpha is capped so a mote can never read as a solid
// pickup, projectile, capture marker or door surface.

uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.5;
uniform float softness : hint_range(0.05, 1.0) = 0.55;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = dot(uv, uv);
	float mask = 1.0 - smoothstep(softness * 0.35, 1.0, r);
	vec3 base = tint.rgb * mix(vec3(1.0), COLOR.rgb, 0.35);
	ALBEDO = base;
	ALPHA = clamp(mask * opacity * COLOR.a, 0.0, 0.6);
}
