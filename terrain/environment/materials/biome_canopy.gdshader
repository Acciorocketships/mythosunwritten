shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 base_color : source_color = vec4(1.0);
varying vec3 instance_tint;
void vertex() { instance_tint = COLOR.rgb; }
void fragment() {
	vec4 texel = texture(albedo_texture, UV) * base_color;
	float green = smoothstep(0.015, 0.09, texel.g - max(texel.r, texel.b));
	float value = max(texel.r, max(texel.g, texel.b));
	// Hue replacement, not multiplication: pink leaves keep their pink even
	// when the source atlas is green. Bark retains its authored colour.
	vec3 canopy = pow(max(instance_tint, vec3(0.0)), vec3(2.2)) * (0.55 + value * 0.65);
	ALBEDO = mix(texel.rgb, canopy, green);
	ROUGHNESS = 0.92;
	SPECULAR = 0.15;
	BACKLIGHT = canopy * green * 0.12;
}
