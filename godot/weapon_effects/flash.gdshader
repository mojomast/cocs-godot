shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float phase = 0.0;
uniform int kind = 0;
uniform float opacity = 1.0;
uniform bool billboard = true;
uniform bool use_sheet = false;
uniform sampler2D frame_texture : source_color, filter_linear;
// Weapon-oomph additions: per-weapon core gain (bigger, hotter white core) and
// an overall brightness multiplier. Defaults preserve the original card.
uniform float core_gain = 1.0;
uniform float brightness = 1.0;
void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX[0] *= length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX[1] *= length(MODEL_MATRIX[1].xyz);
	}
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float core = exp(-r*r*32.0) * core_gain;
	float shape = exp(-r*r*8.0);
	if (kind == 0) shape *= 0.5 + 0.5*pow(abs(cos(a*3.0+phase*2.0)), 6.0);
	if (kind == 1) shape = exp(-dot(p*vec2(2.8,0.8),p*vec2(2.8,0.8))*4.0);
	if (kind == 2) shape = exp(-abs(r-(0.32+phase*0.35))*32.0)*0.75 + core;
	if (kind == 3) shape *= 0.4+0.6*pow(abs(cos(a*4.0)), 3.0);
	if (kind == 4) shape = exp(-r*r*5.0)*(0.65+0.35*sin(r*35.0-phase*12.0));
	if (kind == 5) shape = exp(-dot(p*vec2(1.8,0.8),p*vec2(1.8,0.8))*5.0)*(0.8+0.2*cos(a*5.0));
	if (kind == 6) shape = exp(-abs(r-0.46-0.08*sin(a*9.0+phase*19.0))*32.0)+core;
	if (kind == 7) shape *= 0.3+0.7*pow(abs(cos(a*6.0+phase)), 8.0);
	if (kind == 8) shape = exp(-r*r*9.0)*(0.35+pow(abs(cos(a*2.0)), 12.0));
	if (kind == 9) shape *= 0.4+0.6*pow(abs(cos(a*2.0-phase*4.0)), 8.0);
	if (kind == 10) shape = exp(-r*r*4.0)*(0.7+0.15*sin(p.x*16.0+phase*4.0)*sin(p.y*19.0));
	if (kind == 11) shape = exp(-abs(r-0.35)*24.0)*0.4;
	// Alt-fire blast cards (weapon_effects/controller.gd): 13 cluster shards,
	// 14 mortar dome, 15 mine proximity core, 16 flak fragment star.
	if (kind == 13) shape = exp(-r*r*6.0)*(0.45+0.55*pow(abs(cos(a*5.0+phase*7.0)), 4.0));
	if (kind == 14) shape = exp(-dot(p,p)*3.4)*(0.72+0.28*cos(a*3.0-phase*1.5));
	if (kind == 15) shape = exp(-r*r*18.0)+0.35*exp(-abs(r-0.5)*40.0);
	if (kind == 16) shape = exp(-r*r*10.0)*(0.4+0.6*pow(abs(cos(a*8.0+phase*9.0)), 3.0));
	vec3 color = mix(tint.rgb, vec3(1.0,0.96,0.85), clamp(core*0.8,0.0,1.0)) * brightness;
	if (use_sheet) {
		vec4 tex = texture(frame_texture, UV);
		// Moth frames can have opaque black backgrounds: derive soft coverage,
		// retain their alpha, and taper edges rather than drawing opaque cards.
		float coverage = smoothstep(0.035,0.32,max(tex.r,max(tex.g,tex.b)));
		shape = max(shape*0.35, coverage*tex.a);
		color = mix(color, tex.rgb*tint.rgb, 0.6);
	}
	float edge = 1.0-smoothstep(0.65,1.0,r);
	ALBEDO = color;
	ALPHA = clamp((shape + (kind < 10 ? core : 0.0))*edge*opacity,0.0,0.95);
	if (kind == 12) { ALBEDO = tint.rgb; ALPHA = opacity; }
}
