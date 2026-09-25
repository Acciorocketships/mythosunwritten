shader_type sky;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){vec2 a=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(h(a),h(a+vec2(1,0)),f.x),mix(h(a+vec2(0,1)),h(a+vec2(1,1)),f.x),f.y);}
void sky(){
 float elev=max(EYEDIR.y,0.0);
 vec3 air=mix(vec3(.50,.67,.67),vec3(.13,.36,.52),pow(elev,.45));
 vec2 p=EYEDIR.xz/max(EYEDIR.y+.12,.05)*2.1;
 float cloud=n(p)*.58+n(p*2.1)*.26+n(p*4.3)*.11+n(p*9.0)*.05;
 cloud=smoothstep(.49,.67,cloud)*smoothstep(.015,.12,elev);
 COLOR=mix(air,vec3(.86,.87,.78),cloud*.72);
}
