shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;

varying vec4 authored_color;


void vertex() {
	// StandardMaterial3D's `vertex_color_use_as_albedo` was part of the source
	// roof's look. Preserve that authored palette channel explicitly: fragment
	// COLOR on a MultiMesh contains the instance tint, not this mesh colour.
	authored_color = COLOR;
}


void fragment() {
	vec4 sampled = texture(albedo_texture, UV) * authored_color;
	float maximum = max(sampled.r, max(sampled.g, sampled.b));
	float minimum = min(sampled.r, min(sampled.g, sampled.b));
	float saturation = maximum - minimum;
	// `source_color` sampling is linear here: the visibly orange atlas ramp has
	// a much smaller green-minus-blue interval than its sRGB preview suggests.
	float warm_hue = smoothstep(0.025, 0.12, sampled.r - sampled.g)
		* smoothstep(0.002, 0.045, sampled.g - sampled.b);
	float tile_value = smoothstep(0.24, 0.50, maximum)
		* smoothstep(0.06, 0.18, saturation);
	float tile_mask = smoothstep(0.16, 0.55, warm_hue * tile_value);
	// The LPFV compact roof is the only complete gable that fits a 3 m room,
	// but both authored variants sample the same orange atlas ramp. Re-map that
	// bright tile ramp to weathered blue slate while leaving dark timber, pale
	// plaster, and metal details on their original atlas colours.
	float value = clamp(dot(sampled.rgb, vec3(0.28, 0.58, 0.14)), 0.0, 1.0);
	vec3 slate = mix(vec3(0.12, 0.27, 0.36), vec3(0.34, 0.61, 0.70),
		sqrt(value));
	sampled.rgb = mix(sampled.rgb, slate, tile_mask);
	ALBEDO = sampled.rgb * COLOR.rgb;
	ALPHA = sampled.a * COLOR.a;
	ROUGHNESS = 0.88;
}
