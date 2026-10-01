shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform float fade = 1.0;
uniform float phase = 0.0;
uniform int weapon = 0;
void fragment() {
	float edge = pow(max(0.0, 1.0 - abs(UV.y*2.0-1.0)), 1.4);
	float filament = 1.0;
	// Rail induction bands and shock ion knots move only with this shot's age.
	if (weapon == 2) filament = 0.6 + 0.4*pow(0.5+0.5*cos(UV.x*85.0-phase*20.0),3.0);
	if (weapon == 6) filament = 0.45 + 0.55*pow(0.5+0.5*sin(UV.x*140.0-phase*30.0),2.0);
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * fade * edge * filament;
}
