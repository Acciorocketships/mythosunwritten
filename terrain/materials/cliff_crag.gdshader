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
uniform bool prop_inclusion = false;
uniform sampler2D prop_albedo : source_color, filter_linear_mipmap, hint_default_white;
// Study (September 25): rock exposed in the slope surface itself. COLOR.a is
// the exposure; bare rock takes Meadow's authored stone, flat benches grass.
uniform bool exposure_rock = false;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec3 rock_tint = vec3(.5,.46,.42);
uniform float rock_scale = .22;
varying vec3 stone_position;
varying vec2 stone_rise;
varying vec3 stone_normal;
// Prop mode: the slope plane under the rock (normal, offset) and ground height.
varying vec4 prop_slope;
#include "res://terrain/materials/slope_green.gdshaderinc"
void vertex(){
 stone_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 stone_rise=UV2;
 stone_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
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
  float up=smoothstep(.12,.8,stone_normal.y);
  float density;
  if(prop_mode){
   // Upward faces and the buried base, which grows out of the slope.
   float noise=stone_colour_noise(stone_position*1.3+vec3(4.1,9.3,2.2));
   // A crisp grass top on upward ledges, like the pack's own summer rocks,
   // and the slope's lawn growing over the buried base.
   float top=smoothstep(.6,.7,stone_normal.y+(noise-.5)*.25);
   density=prop_inclusion ? 1.0-smoothstep(-.02,.08+.06*noise,above_slope) : max(top,1.0-smoothstep(.05,.2+.3*noise,above_slope));
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
  if(exposure_rock&&!prop_mode){
   vec3 w=pow(abs(stone_normal),vec3(4.0));w/=(w.x+w.y+w.z);
   vec3 tex=texture(rock_albedo,stone_position.zy*rock_scale).rgb*w.x+texture(rock_albedo,stone_position.xz*rock_scale).rgb*w.y+texture(rock_albedo,stone_position.xy*rock_scale).rgb*w.z;
   stone=clamp(mix(2.0*tex*rock_tint,1.0-2.0*(1.0-tex)*(1.0-rock_tint),step(vec3(.5),rock_tint)),vec3(0),vec3(1));
   stone*=mix(.9,1.1,stone_colour_noise(stone_position*.14+vec3(17.3,3.1,29.7)));
   float grain=moss_fbm(stone_position*vec3(.6,.9,.6)+vec3(1.3,7.7,3.1));
   float fine=stone_colour_noise(stone_position*3.1+vec3(4.,2.,9.));
   float bare=smoothstep(.46,.5,COLOR.a+(grain-.5)*.3+(fine-.5)*.06);
   // Flat facets on bare rock: crisp block planes instead of smooth lighting.
   vec3 facet=normalize(cross(dFdx(VERTEX),dFdy(VERTEX)));
   if(dot(facet,NORMAL)<0.0)facet=-facet;
   vec3 world_facet=normalize((INV_VIEW_MATRIX*vec4(facet,0.0)).xyz);
   float tread=smoothstep(.8,.9,world_facet.y+(fine-.5)*.08);
   NORMAL=normalize(mix(NORMAL,facet,bare*(1.0-tread)*.85));
   cover=min(cover,max(1.0-bare,tread)*moss_amount);
  }
  ALBEDO=mix(stone,slope_green(stone_position,stone_normal,COLOR.rgb,rise),cover);
  ROUGHNESS=1.0;SPECULAR=0.0;
 }
}
