shader_type sky;

uniform sampler2D frost_panorama : source_color, filter_linear, repeat_enable;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void sky() {
	float h = clamp(EYEDIR.y, 0.0, 1.0);
	vec3 base = mix(vec3(0.063, 0.126, 0.181), vec3(0.009, 0.021, 0.065), smoothstep(0.0, 0.72, h));
	vec3 baked = texture(frost_panorama, SKY_COORDS).rgb;
	base += baked * 0.036 * smoothstep(0.0, 0.3, h);
	vec2 star_uv = SKY_COORDS * vec2(720.0, 360.0);
	vec2 cell = floor(star_uv);
	float seed = hash21(cell);
	float star = (1.0 - smoothstep(0.015, 0.10, length(fract(star_uv) - vec2(0.5)))) * step(0.981, seed);
	base += vec3(0.62, 0.80, 0.95) * star * smoothstep(0.06, 0.28, h);
	vec3 moon_dir = normalize(vec3(0.34, 0.44, -0.82));
	float moon_angle = dot(EYEDIR, moon_dir);
	float moon = smoothstep(0.99942, 0.99952, moon_angle);
	float halo = pow(max(moon_angle, 0.0), 240.0) * 0.055;
	base += vec3(0.58, 0.75, 0.82) * (moon * 0.9 + halo);
	COLOR = mix(vec3(0.054, 0.10, 0.145), base, smoothstep(-0.1, 0.0, EYEDIR.y));
}
