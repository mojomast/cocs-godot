shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.5,0.8,1.0,1.0);
uniform float phase = 0.0;
uniform float opacity = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
	MODELVIEW_MATRIX[0] *= length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX[1] *= length(MODEL_MATRIX[1].xyz);
}
void fragment() {
	vec2 p = UV*2.0-1.0;
	float r = length(p);
	if (r > 0.96) { discard; }
	float angle = atan(p.y,p.x);
	float ring = exp(-abs(r-(0.25+phase*0.45))*38.0);
	float arc = pow(0.5+0.5*cos(angle*3.0+phase*5.0),4.0);
	ALBEDO = tint.rgb;
	ALPHA = ring * arc * opacity * (1.0-smoothstep(0.8,0.96,r));
}
