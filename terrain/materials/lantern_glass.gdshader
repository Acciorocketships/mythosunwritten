shader_type spatial;
render_mode cull_disabled;
uniform sampler2D palette : source_color, filter_linear_mipmap, repeat_enable;
// The native LP Village atlas gives the lamp panes this private gold swatch.
// Metal, chains and the post keep their original lighting and atlas colours.
void fragment() {
 vec3 texel = texture(palette, UV).rgb;
 ALBEDO = texel * COLOR.rgb;
 ROUGHNESS = 1.0;
 bool glass = UV.x > 0.34375 && UV.x < 0.375 && UV.y > 0.0 && UV.y < 0.03125;
 EMISSION = glass ? vec3(1.0, 0.64, 0.25) * 3.0 : vec3(0.0);
}
