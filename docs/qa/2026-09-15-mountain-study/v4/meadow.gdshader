shader_type spatial;
render_mode cull_disabled;
uniform bool blades = false;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;if(blades){NORMAL=vec3(0.0,1.0,0.0);}}
void fragment(){
 float patch=.5+.5*sin(p.x*.10+sin(p.z*.047)*3.0)*cos(p.z*.083);
 vec3 grass=mix(vec3(.075,.135,.025),vec3(.14,.22,.045),patch);
 float lane=abs(p.x-(5.0*sin(p.z*.038)+5.0));
 float edge=smoothstep(2.0,4.0+sin(p.z*.37)*.35,lane);
 float grit=fract(sin(dot(floor(p.xz*15.0),vec2(127.1,311.7)))*43758.5453);
 vec3 soil=vec3(.18,.16,.09)*(.94+.06*grit);
 ALBEDO=blades?grass*mix(.7,1.05,UV.y):mix(soil,grass,edge);
 ROUGHNESS=1.0;SPECULAR=.15;
}
