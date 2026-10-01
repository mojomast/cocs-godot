shader_type spatial;
// Only authored campaign light/conduit meshes. Opaque, no geometry displacement
// and no global color grading. Static etching remains calm under reduced motion.
uniform vec4 tint : source_color = vec4(0.4,0.9,0.8,1.0);
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	float band = abs(sin((local_position.x+local_position.y+local_position.z)*38.0));
	float etched = smoothstep(0.08,0.22,band);
	float fresnel = pow(1.0-clamp(dot(normalize(VIEW),NORMAL),0.0,1.0),3.0);
	ALBEDO = tint.rgb * mix(0.23,0.68,etched);
	EMISSION = tint.rgb * (0.4*etched + 0.55*fresnel);
	METALLIC = 0.35;
	ROUGHNESS = 0.3;
}
