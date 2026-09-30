shader_type spatial;
render_mode cull_disabled;
varying vec3 leaf_color;
void vertex() {
 vec3 origin = MODEL_MATRIX[3].xyz;
 float leaf = COLOR.a;
 // Bark has alpha zero; only crowns and blades respond to wind.
 float gust = sin(TIME*1.3 + origin.x*0.21 + origin.z*0.13);
 VERTEX.x += leaf * (sin(TIME*2.1+VERTEX.y*1.7+origin.z)*0.035+gust*0.065) * min(VERTEX.y,3.0);
 leaf_color = mix(COLOR.rgb, sqrt(max(COLOR.rgb,vec3(0.0))), leaf*0.5) * (0.85 + 0.15*INSTANCE_CUSTOM.x);
}
void fragment() { ALBEDO = leaf_color; ROUGHNESS = 0.94; BACKLIGHT = leaf_color*0.3; }
