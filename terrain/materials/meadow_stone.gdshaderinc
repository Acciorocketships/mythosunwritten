// The bedrock sheet's Meadow stone (rock_style's meadow_stone), shared with
// the Meadow asset rocks set into it. Include after rock_style and
// slope_green (triplanar, moss_fbm).
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float rock_scale = .22;
// The bedrock sheet's stone at world point p with surface normal n.
vec3 bedrock_stone(vec3 p,vec3 n){
 return meadow_stone(triplanar(rock_albedo,p,n,rock_scale))*mix(.9,1.1,stone_colour_noise(p*.14+vec3(17.3,3.1,29.7)));
}
// The share of bare stone the sheet shows at p for its rock exposure.
float bedrock_bare(vec3 p,float exposure){
 float grain=moss_fbm(p*vec3(.6,.9,.6)+vec3(1.3,7.7,3.1));
 float fine=stone_colour_noise(p*3.1+vec3(4.,2.,9.));
 return smoothstep(.46,.5,exposure+(grain-.5)*.3+(fine-.5)*.06);
}
// Level treads (normal.y `up`) keep their turf even on bare stone.
float bedrock_tread(vec3 p,float up){
 return smoothstep(.8,.9,up+(stone_colour_noise(p*3.1+vec3(4.,2.,9.))-.5)*.08);
}
