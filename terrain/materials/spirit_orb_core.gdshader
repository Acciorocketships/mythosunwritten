shader_type spatial;
render_mode unshaded;
uniform vec4 glow_color : source_color = vec4(1.0);
varying vec3 world_normal;
varying vec4 orb_color;
void vertex() {
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	orb_color = COLOR * glow_color;
}
void fragment() {
	// A luminous interior with a readable round surface under a fixed soft key.
	float key = pow(max(dot(normalize(world_normal),normalize(vec3(-0.4,0.8,0.45))),0.0),1.5);
	vec3 warm = orb_color.rgb;
	ALBEDO = warm * (0.35 + 0.45*key) + mix(warm,vec3(1.0),0.45) * (0.4 + 0.5*key);
}
