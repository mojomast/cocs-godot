shader_type particles;
render_mode disable_force, disable_velocity;

// One pooled fluid emitter profile. Every uniform is set by
// blood_fx/controller.gd when the emitter starts; nothing is per particle and
// nothing is per frame. No shader TIME: pausing speed_scale truly freezes the
// transport and every CUSTOM age, exactly like combat_particles.

uniform vec3 origin;
uniform vec3 direction = vec3(0.0, 0.0, -1.0);
uniform vec3 up_axis = vec3(0.0, 1.0, 0.0);
uniform int profile = 1;          // 0 mist, 1 jet, 2 arterial, 3 death burst, 4 drip
uniform float cone = 0.35;        // 0 tight .. 1 wide
uniform float speed_min = 2.0;
uniform float speed_max = 8.0;
uniform float life = 0.8;
uniform float stagger = 0.55;     // fraction of life used to stagger spawns
uniform float gravity = 9.8;
uniform float drag = 1.4;
uniform float pulse_count = 1.0;
uniform float pulse_depth = 0.0;
uniform float density_gain = 1.0;
uniform float spawn_radius = 0.05;
uniform float event_seed = 1.0;
uniform vec3 tint = vec3(0.56, 0.022, 0.035);

float hash(float x) {
	return fract(sin(x * 127.1 + event_seed * 19.19) * 43758.5453);
}

void start() {
	float n = float(INDEX);
	float r0 = hash(n + 1.0);
	float r1 = hash(n + 2.0);
	float r2 = hash(n + 3.0);
	float r3 = hash(n + 4.0);
	float r4 = hash(n + 5.0);
	vec3 axis = direction;
	float axis_length = length(axis);
	axis = axis_length > 0.0001 ? axis / axis_length : vec3(0.0, 0.0, -1.0);
	vec3 up = up_axis;
	vec3 right = cross(axis, up);
	float right_length = length(right);
	right = right_length > 0.0001 ? right / right_length : vec3(1.0, 0.0, 0.0);
	vec3 upward = cross(right, axis);
	float angle = r1 * 6.2831853;
	vec3 lateral = (right * cos(angle) + upward * sin(angle)) * r0;
	vec3 dir;
	float speed;
	if (profile == 0) {
		// Entry mist: wide, slow, back toward the shooter's side of the wound.
		dir = normalize(axis + lateral * (0.6 + r2 * 1.8) + up * (r3 - 0.5) * 1.1 + vec3(0.0, 0.0001, 0.0));
		speed = speed_min + r4 * max(0.0, speed_max - speed_min);
	} else if (profile == 3) {
		// Death burst: full sphere with a downward bias; gravity does the rest.
		float z = r0 * 2.0 - 1.0;
		float a = r1 * 6.2831853;
		float s = sqrt(max(0.0, 1.0 - z * z));
		dir = normalize(vec3(s * cos(a), z * 0.72 - 0.24, s * sin(a)) + vec3(0.0, 0.0001, 0.0));
		speed = speed_min + r2 * max(0.0, speed_max - speed_min);
	} else if (profile == 4) {
		// Drip: mostly downward with a slight surface-hugging drift.
		dir = normalize(vec3(lateral.x * 0.6, -1.0, lateral.z * 0.6) + vec3(0.0, 0.0001, 0.0));
		speed = speed_min + r3 * max(0.0, speed_max - speed_min);
	} else {
		// Jet and arterial: a cone around the authoritative shot direction.
		float spread = cone * (0.2 + 0.8 * r0);
		dir = normalize(axis + lateral * spread + up * (r3 - 0.5) * cone * 0.6 + vec3(0.0, 0.0001, 0.0));
		speed = speed_min + r2 * max(0.0, speed_max - speed_min);
	}
	float pulse = 1.0;
	if (pulse_count > 1.0) {
		pulse = mix(1.0, 0.22, pulse_depth * (0.5 + 0.5 * sin(r3 * 6.2831853 * pulse_count + r4 * 0.7)));
	}
	VELOCITY = dir * speed * pulse;
	// Columns 0-2 carry velocity/up/right for the draw-pass stretch and never
	// leak into gameplay: this is the particle's own transform.
	TRANSFORM[0].xyz = VELOCITY;
	TRANSFORM[1].xyz = up;
	TRANSFORM[2].xyz = right;
	TRANSFORM[3].xyz = origin + lateral * spawn_radius + up * (r2 - 0.5) * spawn_radius * 0.5;
	CUSTOM = vec4(-r0 * life * stagger, life * (0.75 + r4 * 0.5), 0.0, 0.55 + r2 * 0.85);
	COLOR = vec4(tint, 1.0);
	ACTIVE = true;
}

void process() {
	float dt = min(DELTA, 0.05);
	float age = CUSTOM.x + dt;
	CUSTOM.x = age;
	float span = max(0.05, CUSTOM.y);
	VELOCITY.y -= gravity * dt;
	VELOCITY *= exp(-dt * drag);
	vec3 position = TRANSFORM[3].xyz + VELOCITY * dt;
	TRANSFORM[0].xyz = VELOCITY;
	TRANSFORM[3].xyz = position;
	float fade = clamp(1.0 - age / span, 0.0, 1.0);
	float born = smoothstep(0.0, 0.045, age);
	COLOR.a = born * fade * fade * density_gain;
	CUSTOM.z = CUSTOM.w * (0.5 + 0.7 * fade);
	ACTIVE = true;
}
