shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(0.4, 0.5, 0.3, 1.0);
uniform float grain_scale = 3.0;
uniform float metal = 0.0;
varying vec3 world_position;
float hash(vec3 p) {
 p = fract(p * 0.1031);
 p += dot(p, p.yzx + 33.33);
 return fract((p.x + p.y) * p.z);
}
float noise(vec3 p) {
 vec3 i = floor(p), f = fract(p);
 f = f * f * (3.0 - 2.0 * f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float coarse = noise(world_position * 0.38);
 float grain = noise(world_position * grain_scale);
 float seams = smoothstep(0.94,1.0,sin(world_position.y*4.7+coarse*2.0));
 ALBEDO = base_color.rgb * (0.78 + coarse*0.3 + grain*0.18 - seams*0.08);
 ROUGHNESS = mix(0.92,0.52,metal);
 METALLIC = metal;
}
