shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Pooled surface-damage decal for the impact FX lane (player_fx/mark_pool.gd).
//
// One quad lying in a real queried surface plane, offset along the confirmed
// normal. World depth testing stays enabled (a mark behind cover changes zero
// pixels) and depth is never written, so marks cannot occlude gameplay. The
// Compatibility renderer has no Decal node; this is the shader substitute.
//
// "3D surface damage" is faked honestly from an analytic height field: the
// fragment evaluates the same height function at two small offsets, derives the
// in-plane gradient, tilts the surface normal with it and shades against a
// presentation light. The bright rim, the dark pock floor and the radial cracks
// are therefore lighting terms of a displaced surface, not painted sprites.
//
// Kinds:
//   0 pock   - bullet/fragment damage: dark pock + bright rim + radial cracks
//   1 scorch - explosion soot: soft irregular blotch, warm ember rim that ages
//   2 ring   - shockwave: one expanding band for large blasts (short-lived)
//
// Families: 0 metal, 1 stone, 2 ice, 3 ground. Each family has its own pock
// depth, rim colour and crack character. Low quality passes detail = 0 and the
// crack pass collapses to the plain pock (still a lit dish, never a flat sprite).

uniform int family = 1;      // 0 metal, 1 stone, 2 ice, 3 ground
uniform int kind = 0;        // 0 pock, 1 scorch, 2 ring
uniform float seed = 0.0;
uniform float opacity = 1.0; // pooled slot fade (life recycling)
uniform float age = 0.0;     // 0 fresh .. 1 end of life: soot dulls, rim cools
uniform float detail = 1.0;  // 0 at F9 Low: radial cracks disabled
uniform float progress = 0.0; // 0..1 for the shockwave ring expansion
uniform vec3 light_dir = vec3(0.36, 0.86, 0.36); // presentation light, world space

varying vec3 v_light; // light_dir expressed in the quad's local frame

void vertex() {
	// The quad's local +Z is the confirmed surface normal (mark_pool.gd builds
	// the basis that way) and the node scale is uniform, so the model columns
	// are an orthogonal frame and the world light maps into it by projection.
	vec3 x_axis = normalize(MODEL_MATRIX[0].xyz);
	vec3 y_axis = normalize(MODEL_MATRIX[1].xyz);
	vec3 z_axis = normalize(MODEL_MATRIX[2].xyz);
	v_light = vec3(dot(light_dir, x_axis), dot(light_dir, y_axis), dot(light_dir, z_axis));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.23) * 43758.5453);
}

// Radial crack field: six golden-angle rays whose angular width narrows with
// distance. A zero detail amount collapses this to zero and leaves the plain
// pock (F9 Low), never a flat sprite: the dish relief stays.
float cracks(vec2 q, float reach_scale, float detail_amount) {
	if (detail_amount < 0.5) { return 0.0; }
	float d = length(q);
	float a = atan(q.y, q.x);
	float amount = 0.0;
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float ca = seed * 6.2831853 + fi * 2.3999632 + hash(vec2(fi, 3.0)) * 0.6;
		float da = abs(mod(a - ca + 3.14159265, 6.2831853) - 3.14159265);
		float reach = (0.38 + 0.52 * hash(vec2(fi, 7.0))) * reach_scale;
		float wobble = 0.75 + 0.25 * sin(d * 26.0 + seed * 11.0 + fi * 1.7);
		float ray = 1.0 - smoothstep(0.0, (0.045 + 0.05 * hash(vec2(fi, 9.0))) * (0.6 + d * 1.6), da * wobble);
		ray *= 1.0 - smoothstep(reach * 0.35, reach, d);
		amount = max(amount, ray);
	}
	return amount;
}

// Signed height of the damaged surface. Negative is a depression. The gradient
// of this function tilts the shading normal below.
float damage_height(vec2 q, float radius, float depth, float detail_amount) {
	float d = length(q);
	float dish = -depth * (1.0 - smoothstep(radius * 0.35, radius, d));
	float crack = cracks(q, radius * 1.25, detail_amount);
	return dish - depth * 0.85 * crack;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float e = 0.045;
	float radius = 0.52 + 0.12 * hash(vec2(2.0, 5.0));
	float depth = 0.4;
	float detail_amount = detail;
	vec3 dark = vec3(0.09);
	vec3 rim_color = vec3(0.72, 0.70, 0.64);
	float grit = 0.7;
	float sparkle = 0.0;
	if (family == 0) {
		// Metal: deep pock, blued/dark floor, burnished bright rim, tight cracks.
		dark = vec3(0.035, 0.038, 0.05);
		rim_color = vec3(0.72, 0.75, 0.82);
		depth = 0.55;
		grit = 1.0;
		sparkle = 0.35;
	} else if (family == 2) {
		// Ice: pale chip, blue shadow, bright fracture lines.
		dark = vec3(0.16, 0.30, 0.40);
		rim_color = vec3(0.84, 0.93, 0.98);
		depth = 0.5;
		grit = 0.9;
		sparkle = 0.25;
	} else if (family == 3) {
		// Ground: shallow crater, warm dust rim, few soft cracks.
		dark = vec3(0.15, 0.10, 0.07);
		rim_color = vec3(0.70, 0.62, 0.49);
		depth = 0.35;
		grit = 1.15;
		detail_amount *= 0.6;
	} else {
		// Stone: chipped dish, pale dust rim, wider cracks.
		dark = vec3(0.09, 0.085, 0.078);
		rim_color = vec3(0.66, 0.63, 0.56);
		depth = 0.45;
		grit = 1.1;
	}

	if (kind == 2) {
		// Shockwave ring: an expanding dust band, no relief.
		float inner = 0.12 + 0.78 * progress;
		float outer = inner + 0.24 - 0.10 * progress;
		float band = smoothstep(inner, inner + 0.10, d) * (1.0 - smoothstep(outer - 0.10, outer, d));
		float grain = 0.75 + 0.5 * hash(floor(p * 14.0));
		float alpha = band * grain * opacity;
		if (alpha < 0.006) { discard; }
		ALBEDO = mix(vec3(0.82, 0.76, 0.62), vec3(1.0, 0.86, 0.6), progress);
		ALPHA = min(alpha, 0.72);
	} else if (kind == 1) {
		// Scorch: stacked hashed blobs read as one irregular soot pool, with a
		// warm ember rim while the mark is fresh that cools as it ages.
		float body = 0.0;
		for (int i = 0; i < 6; i++) {
			float fi = float(i);
			float a = hash(vec2(fi, 1.0)) * 6.2831853;
			float r = 0.20 + hash(vec2(fi, 2.0)) * 0.42;
			vec2 center = vec2(cos(a), sin(a)) * (0.05 + hash(vec2(fi, 4.0)) * 0.42);
			float dist = length((p - center) * vec2(1.0, 0.75 + hash(vec2(fi, 6.0)) * 0.5));
			body = max(body, 1.0 - smoothstep(r * 0.25, r, dist));
		}
		body = max(body, (1.0 - smoothstep(0.2, 0.92, d)) * 0.92);
		float soot = 0.55 + 0.45 * hash(floor(p * 16.0) + floor(seed * 7.0));
		// Ember reads as a hot rim around dark soot, not a filled orange disc,
		// and cools with age.
		float ember = smoothstep(0.30, 0.55, d) * (1.0 - smoothstep(0.62, 0.90, d));
		ember *= (1.0 - age) * 0.55;
		vec3 albedo = mix(vec3(0.035, 0.031, 0.03), dark, soot * 0.3);
		albedo = mix(albedo, vec3(0.46, 0.21, 0.08), ember);
		float alpha = body * opacity * (0.72 + 0.18 * soot);
		if (alpha < 0.006) { discard; }
		ALBEDO = albedo;
		ALPHA = min(alpha, 0.88);
	} else {
		// Pock: height-field relief. The gradient of the same damage_height()
		// the shading normal is built from keeps the dish and the cracks solid.
		// The presentation light gets a normal-facing component so a mark on a
		// face the world light does not reach still reads as a lit dish instead
		// of a flat silhouette.
		float h = damage_height(p, radius, depth, detail_amount);
		float hx = damage_height(p + vec2(e, 0.0), radius, depth, detail_amount);
		float hy = damage_height(p + vec2(0.0, e), radius, depth, detail_amount);
		vec2 grad = vec2(hx - h, hy - h) / e;
		vec3 normal = normalize(vec3(-grad.x * depth * 10.0, -grad.y * depth * 10.0, 1.0));
		vec3 light = normalize(v_light + vec3(0.0, 0.0, 0.45));
		float diffuse = clamp(dot(normal, light), 0.0, 1.0);
		float crack = cracks(p, radius * 1.25, detail_amount);
		float rim = smoothstep(radius * 0.74, radius * 0.97, d) * (1.0 - smoothstep(radius * 0.97, radius * 1.12, d));
		float floor_mask = 1.0 - smoothstep(radius * 0.55, radius * 0.95, d);
		float grain = 0.8 + grit * 0.25 * hash(floor(p * 18.0));
		vec3 albedo = mix(rim_color, dark, floor_mask);
		albedo *= 0.42 + 0.92 * diffuse;
		albedo = mix(albedo, dark * 0.45, crack * 0.85);
		albedo += rim_color * rim * (0.18 + 0.55 * diffuse);
		albedo += vec3(sparkle) * rim * diffuse * max(0.0, 1.0 - d / (radius * 1.2));
		albedo *= mix(1.0, 0.82, age);
		float body = 1.0 - smoothstep(radius * 0.86, radius * 1.08, d);
		float alpha = body * grain * opacity;
		if (alpha < 0.006) { discard; }
		ALBEDO = albedo;
		ALPHA = min(alpha, 0.96);
	}
}
