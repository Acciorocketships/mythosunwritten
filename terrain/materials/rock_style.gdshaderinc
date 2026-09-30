// One stone colour for every rock, overlaid on the Meadow rocks' neutral
// grey albedos (their means are 0.50-0.52 sRGB in every channel): native
// cliffs, field rocks, the bedrock sheet and the Meadow asset rocks all take
// it (owner, September 27 judging: make the cliffs a bit warmer, to match
// the rocks). A low-saturation warm grey-tan, between the old cool bedrock
// tint (.5,.46,.42) and the pack's saturated S_Props rock tint
// (.552,.418,.342), which read salmon once the cliffs took it.
const vec3 MEADOW_STONE_TINT = vec3(.52,.475,.40);
// The Meadow stone for a (linear) grey albedo texel.
vec3 meadow_stone(vec3 texel){
 return clamp(mix(2.0*texel*MEADOW_STONE_TINT,1.0-2.0*(1.0-texel)*(1.0-MEADOW_STONE_TINT),step(vec3(.5),MEADOW_STONE_TINT)),vec3(0),vec3(1));
}
// Other stone takes the Meadow stone of the Meadow albedos' mean grey (0.5
// sRGB), preserving subtle authored palette variation, independently of
// turf biome hue.
vec3 stone_albedo(vec3 texel) {
 float value = dot(texel, vec3(0.2126,0.7152,0.0722));
 return meadow_stone(vec3(0.214)) * clamp(0.90 + value * 0.40, 0.92, 1.10);
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
