shader_type sky;

uniform sampler2D ash_panorama : source_color, filter_linear, repeat_enable;

void sky() {
	float elevation = max(EYEDIR.y, 0.0);
	vec3 horizon = vec3(0.39, 0.235, 0.225);
	vec3 zenith = vec3(0.075, 0.10, 0.16);
	vec3 color = mix(horizon, zenith, smoothstep(0.0, 0.83, elevation));
	vec2 uv = vec2(fract(SKY_COORDS.x + 0.17), clamp(SKY_COORDS.y + 0.12, 0.0, 1.0));
	vec3 ash = texture(ash_panorama, uv).rgb;
	vec3 edge = texture(ash_panorama, vec2(0.0, uv.y)).rgb;
	ash = mix(ash, edge, smoothstep(0.95, 1.0, uv.x));
	float grey = dot(ash, vec3(0.3, 0.5, 0.2));
	color += vec3(grey * 0.09) * smoothstep(0.02, 0.35, elevation);
	vec3 sun_dir = normalize(vec3(-0.35, 0.23, -0.8));
	float alignment = max(dot(EYEDIR, sun_dir), 0.0);
	color += vec3(0.65, 0.29, 0.11) * pow(alignment, 48.0) * 0.28;
	color += vec3(0.72, 0.48, 0.26) * smoothstep(0.9992, 0.9995, alignment) * 0.75;
	COLOR = color;
}
