// Shared slope and Meadow ledge colour, detail and world-space mapping.
vec3 triplanar(sampler2D t, vec3 p, vec3 n, float s){
 vec3 w=pow(abs(n),vec3(4.0));w/=(w.x+w.y+w.z);
 return texture(t,p.zy*s).rgb*w.x+texture(t,p.xz*s).rgb*w.y+texture(t,p.xy*s).rgb*w.z;
}
float moss_fbm(vec3 p){
 return .5*stone_colour_noise(p)+.3*stone_colour_noise(p*2.07+vec3(5.2,1.3,7.7))+.2*stone_colour_noise(p*4.3+vec3(2.9,8.1,3.3));
}
// Lawn to moss, graded by height above the ground across a wide, warped
// boundary, with broad low-contrast patches of intermediate mixes and a
// slow brightness/warmth drift: no bands, no hard edges.
vec3 grown_colour(vec3 lawn,vec3 moss,float rise,vec3 p){
 float warp=(moss_fbm(p*vec3(.16,.28,.16)+vec3(3.1,7.9,1.7))-.5)*moss_blend_height;
 float low=1.0-smoothstep(-.25*moss_blend_height,1.15*moss_blend_height,rise+warp);
 float patch=moss_fbm(p*vec3(.11,.19,.11)+vec3(7.3,2.1,9.7));
 float t=clamp(low+(patch-.5)*moss_secondary*1.3,0.0,1.0);
 float drift=moss_fbm(p*vec3(.21,.3,.21)+vec3(1.9,4.4,6.2));
 return mix(moss,lawn,t)*mix(vec3(.94,.95,.97),vec3(1.06,1.05,1.0),drift);
}
vec3 slope_green_grade(vec3 p,vec3 n,vec3 tint,float rise,float grade){
 vec3 exact=ground_style(p.xz,texture(ground_palette_texture,grass_uv).rgb*tint);
 vec3 lawn=exact;
 vec3 detail=triplanar(moss_detail,p,n,moss_detail_scale)/max(pow(moss_detail_mean,vec3(2.2)),vec3(.001));
 detail=mix(vec3(1.0),clamp(detail,vec3(.4),vec3(1.8)),moss_detail_strength);
 vec3 moss=lawn*moss_shade*detail;
 lawn*=mix(vec3(1.0),detail,.35);
 // Gentle ground is exactly the terrain's lawn (the same function the
 // terrain uses): moss, detail and drift come in only as the slope steepens
 // (about 18 to 40 degrees), so no light/dark seam where the two meet.
 return mix(exact,grown_colour(lawn,moss,rise,p),smoothstep(.05,.24,grade));
}

vec3 slope_green(vec3 p,vec3 n,vec3 tint,float rise){
 return slope_green_grade(p,n,tint,rise,1.0-n.y);
}
