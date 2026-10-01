shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
// Analytic coverage has no texture/mipmap border. Animation is event-age driven,
// so source pause freezes the effect and recycling always starts at phase zero.
uniform vec4 tint : source_color = vec4(0.7, 0.65, 0.55, 0.5);
uniform float phase = 0.0;
uniform float opacity = 1.0;
uniform int family = 1;
uniform bool puff = false;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX[0] *= length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX[1] *= length(MODEL_MATRIX[1].xyz);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r >= 0.98) { discard; }
	float edge = 1.0 - smoothstep(0.65, 0.98, r);
	float cloud = exp(-r*r*4.0) * (0.72 + 0.18*sin(p.x*14.0+phase*2.0)*sin(p.y*17.0-phase));
	float shape = cloud;
	vec3 color = tint.rgb;
	if (!puff && family == 0) {
		float angle = atan(p.y, p.x);
		float rays = pow(abs(cos(angle*5.0+0.7)), 38.0);
		shape = rays * smoothstep(0.08, 0.28, r) * (1.0-smoothstep(0.4+phase*0.25,0.85,r));
		color = mix(vec3(1.0,0.45,0.10),vec3(1.0,0.94,0.64),1.0-r);
	} else if (!puff && family == 2) {
		shape *= 0.35 + 0.65*pow(abs(cos(atan(p.y,p.x)*6.0)),8.0);
	}
	ALBEDO = color;
	ALPHA = min(shape * edge * tint.a * opacity, 0.7);
}
