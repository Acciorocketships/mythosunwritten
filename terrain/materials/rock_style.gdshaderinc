// One restrained warm-gray stone for native cliffs, boulders and field rocks.
// Preserve subtle authored palette variation, independently of turf biome hue.
uniform vec4 stone_color : source_color = vec4(0.40, 0.39, 0.42, 1.0);
vec3 stone_albedo(vec3 texel) {
 float value = dot(texel, vec3(0.2126,0.7152,0.0722));
 return stone_color.rgb * clamp(0.90 + value * 0.40, 0.92, 1.10);
}

// A continuous world-space mineral field shared by native walls and added
// stone. Broad patches vary value and warmth without outlining mesh facets.
float stone_colour_hash(vec3 p) {
 p = fract(p * vec3(.1031, .1030, .0973));
 p += dot(p, p.yxz + 33.33);
 return fract((p.x + p.y) * p.z);
}
float stone_colour_noise(vec3 p) {
 vec3 cell=floor(p), f=fract(p);
 f=f*f*f*(f*(f*6.0-15.0)+10.0);
 return mix(mix(mix(stone_colour_hash(cell),stone_colour_hash(cell+vec3(1,0,0)),f.x),
                mix(stone_colour_hash(cell+vec3(0,1,0)),stone_colour_hash(cell+vec3(1,1,0)),f.x),f.y),
            mix(mix(stone_colour_hash(cell+vec3(0,0,1)),stone_colour_hash(cell+vec3(1,0,1)),f.x),
                mix(stone_colour_hash(cell+vec3(0,1,1)),stone_colour_hash(cell+vec3(1,1,1)),f.x),f.y),f.z);
}
vec3 stone_albedo(vec3 texel, vec3 world_position) {
 float broad=stone_colour_noise(world_position*.14+vec3(17.3,3.1,29.7));
 float mineral=stone_colour_noise(world_position*.43+vec3(41.7,19.3,7.1));
 float tone=smoothstep(.15,.85,mix(broad,mineral,.23));
 vec3 temperature=mix(vec3(.97,.995,1.04),vec3(1.06,1.015,.955),broad);
 return stone_albedo(texel)*mix(.84,1.16,tone)*temperature;
}
