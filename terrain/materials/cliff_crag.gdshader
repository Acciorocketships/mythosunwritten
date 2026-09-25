shader_type spatial;
#include "res://terrain/materials/ground_style.gdshaderinc"
#include "res://terrain/materials/rock_style.gdshaderinc"
// Ground-up moss (owner review, September 23). UV2.x is the height above the
// terrain just outside the rock, UV2.y the full cliff height there: cover is
// complete from the ground up and thins into patches only near the crest.
// The lowest band blends into the exact lawn colour, so there is no seam.
uniform sampler2D ground_palette_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec2 grass_uv;
uniform float moss_amount = 0.0;
uniform float moss_upward = 0.45;
uniform bool moss_slopes = false;
// The whole-wall sheet: moss all the way up to the lip.
uniform bool moss_full = false;
uniform float moss_blend_height = 4.0;
uniform float moss_secondary = 0.9;
// Darker, cooler than the lawn it grows from.
uniform vec3 moss_shade = vec3(.40,.58,.50);
// Pack detail: colour texture (relative to its mean colour) and coverage mask.
uniform sampler2D moss_detail : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec3 moss_detail_mean = vec3(1.0);
uniform float moss_detail_strength = 0.0;
uniform float moss_detail_scale = 0.55;
uniform sampler2D moss_mask : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float moss_mask_weight = 0.0;
uniform float moss_mask_scale = 0.35;
// Crack mode (Suntail): the mask's brightest lines keep bare stone.
uniform bool moss_mask_cracks = false;
uniform vec2 moss_mask_range = vec2(.0,1.0);
// Prop mode: pack rocks set into the slopes keep their own facet texture as
// value variation on the cliff stone, with moss on their upward faces.
uniform bool prop_mode = false;
uniform sampler2D prop_albedo : source_color, filter_linear_mipmap, hint_default_white;
varying vec3 stone_position;
varying vec2 stone_rise;
varying vec3 stone_normal;
// Prop mode: the slope plane under the rock (normal, offset) and ground height.
varying vec4 prop_slope;
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
void vertex(){
 stone_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 stone_rise=UV2;
 stone_normal=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);
 prop_slope=prop_mode?INSTANCE_CUSTOM:vec4(0.0);
}
void fragment(){
 vec3 stone=stone_albedo(vec3(.25),stone_position);
 float rise=stone_rise.x;
 float above_slope=0.0;
 if(prop_mode){
  float value=dot(texture(prop_albedo,UV).rgb,vec3(.2126,.7152,.0722));
  stone*=clamp(.55+value*1.4,.6,1.35);
  vec3 n=vec3(prop_slope.x,sqrt(max(0.0,1.0-prop_slope.x*prop_slope.x-prop_slope.y*prop_slope.y)),prop_slope.y);
  above_slope=dot(stone_position,n)-prop_slope.z;
  rise=stone_position.y-prop_slope.w;
 }
 if(moss_amount<=0.0){ALBEDO=stone;ROUGHNESS=1.0;SPECULAR=0.0;}
 else{
  vec3 lawn=ground_style(stone_position.xz,texture(ground_palette_texture,grass_uv).rgb*COLOR.rgb);
  vec3 detail=triplanar(moss_detail,stone_position,stone_normal,moss_detail_scale)/max(pow(moss_detail_mean,vec3(2.2)),vec3(.001));
  detail=mix(vec3(1.0),clamp(detail,vec3(.4),vec3(1.8)),moss_detail_strength);
  vec3 moss=lawn*moss_shade*detail;
  // A lighter trace of the same grain keeps the lawn end from reading flat.
  lawn*=mix(vec3(1.0),detail,.35);
  float up=smoothstep(.12,.8,stone_normal.y);
  float density;
  if(prop_mode){
   // Upward faces and the buried base, which grows out of the slope.
   float noise=stone_colour_noise(stone_position*1.3+vec3(4.1,9.3,2.2));
   // A crisp grass top on upward ledges, like the pack's own summer rocks,
   // and the slope's lawn growing over the buried base.
   float top=smoothstep(.6,.7,stone_normal.y+(noise-.5)*.25);
   density=max(top,1.0-smoothstep(.05,.2+.3*noise,above_slope));
  }
  else{
   // Relative height up this cliff; a minimum scale keeps short walls graded.
   float height=max(stone_rise.y,3.0);
   float t=clamp(stone_rise.x/height,0.0,1.0);
   // Thick moss from the ground up; it thins only toward the very top.
   density=mix(.25,1.0,1.0-smoothstep(.6,1.0,t));
   // Slopes and ledges hold moss; on mossy slopes they are fully covered.
   density=max(density,(moss_slopes?1.0:moss_upward)*up);
   if(moss_full)density=1.0;
  }
  float patches=stone_colour_noise(stone_position*vec3(.55,.9,.55)+vec3(3.7,11.1,5.3));
  float fine=stone_colour_noise(stone_position*2.3+vec3(9.1,1.7,4.4));
  float mask=dot(triplanar(moss_mask,stone_position,stone_normal,moss_mask_scale),vec3(.333));
  float field=mix(patches,fine,.3);
  if(moss_mask_cracks)field=max(field,smoothstep(moss_mask_range.x,moss_mask_range.y,mask)*moss_mask_weight);
  else field=mix(field,1.0-mask,moss_mask_weight);
  // A wide transition: moss thins into stone rather than ending at an edge.
  float cover=smoothstep(field-.2,field+.2,density*1.1-.05)*moss_amount;
  // Full cover near the ground regardless of noise.
  if(!prop_mode)cover=max(cover,(1.0-smoothstep(0.0,2.5,stone_rise.x))*moss_amount);
  // A mossy slope is fully grown; stone shows only as it steepens into the wall.
  if(moss_slopes&&!prop_mode){
   float edge=moss_fbm(stone_position*vec3(.45,.8,.45)+vec3(6.1,2.7,8.3))-.5;
   cover=max(cover,smoothstep(.35,.8,stone_normal.y+edge*.5)*moss_amount);
  }
  ALBEDO=mix(stone,grown_colour(lawn,moss,rise,stone_position),cover);
  ROUGHNESS=1.0;SPECULAR=0.0;
 }
}
