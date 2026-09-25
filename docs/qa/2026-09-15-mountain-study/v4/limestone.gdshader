shader_type spatial;
render_mode diffuse_burley;
uniform vec4 stone : source_color = vec4(0.48,0.49,0.43,1.0);
uniform vec4 moss : source_color = vec4(0.15,0.25,0.075,1.0);
uniform float moss_amount = 0.53;
varying vec3 world_p;
varying vec3 world_n;
float hash(vec3 p) {return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p) {
 vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
 mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){world_p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_n=MODEL_NORMAL_MATRIX*NORMAL;}
void fragment(){
 vec3 p=world_p;
 float broad=noise(p*0.11)+0.35*noise(p*0.37);
 float grain=noise(p*2.7)*0.7+noise(p*11.0)*0.3;
 float hanging=noise(vec3(p.x*.22,p.y*.055,p.z*.22));
 float cover=smoothstep(0.46,0.73,broad*.55+hanging*.35+max(world_n.y,0.0)*.45+(moss_amount-.5));
 vec3 rock=stone.rgb*(0.77+0.23*broad+0.1*grain);
 ALBEDO=mix(rock,moss.rgb*(.8+.3*grain),cover);
 float height=noise(p*1.1)*.085+noise(p*4.8)*.012;
 vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX);
 vec3 rx=cross(dy,NORMAL),ry=cross(NORMAL,dx);
 float det=dot(dx,rx);
 if(abs(det)>.000001){NORMAL=normalize(abs(det)*NORMAL-sign(det)*(dFdx(height)*rx+dFdy(height)*ry));}
 ROUGHNESS=.92;SPECULAR=.22;
}
