// One restrained warm-gray stone for native cliffs, boulders and field rocks.
// Preserve subtle authored palette variation, independently of turf biome hue.
uniform vec4 stone_color : source_color = vec4(0.40, 0.39, 0.42, 1.0);
vec3 stone_albedo(vec3 texel) {
 float value = dot(texel, vec3(0.2126,0.7152,0.0722));
 return stone_color.rgb * clamp(0.90 + value * 0.40, 0.92, 1.10);
}
