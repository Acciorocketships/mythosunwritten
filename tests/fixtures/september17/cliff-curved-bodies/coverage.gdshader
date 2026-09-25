shader_type spatial;
render_mode unshaded;
void fragment() {
 ALBEDO=mix(vec3(1.0,.05,.05),vec3(.05,.8,1.0),COLOR.a);
}
