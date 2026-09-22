shader_type sky;
// Static, single-resolution sky: no TIME, noise textures, cubemap faces or mesh dome.
uniform vec4 zenith : source_color;
uniform vec4 horizon : source_color;
uniform vec4 ground : source_color;
uniform vec4 sun_color : source_color;
uniform sampler2D panorama : source_color, filter_linear, repeat_enable;
uniform bool has_panorama = false;
uniform float panorama_strength = 0.0;
uniform float panorama_rotation = 0.0;
uniform float veil_strength = 0.0;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform float disk_strength = 0.0;

void sky() {
	float elevation = clamp(EYEDIR.y, -1.0, 1.0);
	// Both curves have zero slope at the shared horizon; no sign-step or division.
	float upper = smoothstep(0.0, 0.88, max(elevation, 0.0));
	float lower = smoothstep(0.0, 0.72, max(-elevation, 0.0));
	vec3 base = mix(horizon.rgb, zenith.rgb, upper);
	base = mix(base, ground.rgb, lower);
	// Broad, static high-altitude veil. Kept above sightlines and intentionally faint.
	float veil = 0.5 + 0.5 * sin(SKY_COORDS.x * 18.849556 + elevation * 13.0);
	veil *= smoothstep(0.08, 0.35, elevation) * (1.0 - smoothstep(0.65, 0.98, elevation));
	base = mix(base, horizon.rgb, veil * veil_strength);
	if (has_panorama) {
		// Lift the baked equatorial nebula into the upper sky, never the ground.
		vec2 uv = vec2(fract(SKY_COORDS.x + panorama_rotation), clamp(SKY_COORDS.y + 0.16, 0.0, 1.0));
		vec3 baked = texture(panorama, uv).rgb;
		// Arbitrary source edges may not tile. Crossfade the last 4% to the first
		// edge; the wrap itself meets at exactly the same texel on either side.
		vec3 edge = texture(panorama, vec2(0.0, uv.y)).rgb;
		baked = mix(baked, edge, smoothstep(0.96, 1.0, uv.x));
		float reveal = smoothstep(0.08, 0.46, elevation) * panorama_strength;
		// Compress only the panorama highlights; authored horizon remains stable.
		baked = baked / (vec3(1.0) + baked * 0.30);
		base = mix(base, baked, reveal);
	}
	float alignment = clamp(dot(EYEDIR, sun_direction), 0.0, 1.0);
	float halo = pow(alignment, 32.0) * 0.075;
	float disk = smoothstep(0.99972, 0.99988, alignment) * 0.65;
	base += sun_color.rgb * (halo + disk) * disk_strength * smoothstep(0.0, 0.06, elevation);
	COLOR = max(base, vec3(0.0));
}
