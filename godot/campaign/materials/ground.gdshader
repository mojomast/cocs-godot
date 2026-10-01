shader_type spatial;
render_mode cull_back, depth_draw_opaque;
uniform vec4 ground_color : source_color = vec4(.32,.43,.27,1.);
uniform vec4 trail_color : source_color = vec4(.61,.66,.46,1.);
uniform vec4 stone_color : source_color = vec4(.44,.51,.48,1.);
uniform vec4 weather_color : source_color = vec4(.26,.34,.22,1.);
uniform float moisture = 0.0;
uniform int biome_index = 0;
varying vec3 world_pos;
varying vec2 blend_mask;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 blend_mask=COLOR.rg;
}
void fragment() {
 vec2 p=world_pos.xz;
 float coarse=noise(p*.13);
 float patches=noise(p*.42+vec2(10.7,-3.4));
 float grains=noise(p*4.1);
 // Distort only colour boundaries: the triangle positions and trail authority never change.
 float trail=clamp(blend_mask.x+(patches-.5)*.14,0.,1.);
 float rock=clamp(blend_mask.y+(coarse-.5)*.10,0.,1.);
 vec3 base=mix(ground_color.rgb,trail_color.rgb,trail);
 base=mix(base,stone_color.rgb,rock*.9);
 float drainage=smoothstep(.58,.84,coarse)*(.45+.4*moisture)*(1.-trail*.6);
 base=mix(base,weather_color.rgb,drainage*.32);
 float detail=0.;
 if (biome_index == 0) {
  // Interleaved patches of humus under the canopy, continuous across chunks.
  detail=smoothstep(.51,.77,noise(p*.23+vec2(9.,17.)))*.19;
 } else if (biome_index == 1) {
  // Elongated, unequal silt deposits parallel to the channel.
  detail=smoothstep(.43,.72,noise(vec2(p.x*.21,p.y*.057)+vec2(31.,-4.)))*.24;
 } else if (biome_index == 2) {
  // Broad cooled flows and fine oxidation along exposed shelves.
  detail=smoothstep(.48,.77,noise(vec2(p.x*.10+p.y*.028,p.y*.14)))*.22;
 } else {
  detail=smoothstep(.57,.83,noise(p*.31+vec2(-12.,7.)))*.17;
 }
 base=mix(base,weather_color.rgb,detail*(1.-trail*.7));
 // Micro-aggregate variation and damp seams along slopes; continuous world-space mapping.
 base*=.86+coarse*.14+patches*.13+grains*.08;
 ALBEDO=base;
 ROUGHNESS=clamp(.92-moisture*.14-rock*.10+grains*.03,.65,1.);
 METALLIC=0.;
}
