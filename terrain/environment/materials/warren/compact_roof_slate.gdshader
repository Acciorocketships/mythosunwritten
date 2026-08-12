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
	float warm_hue = smoothstep(0.035, 0.13, sampled.r - sampled.g)
		* smoothstep(0.008, 0.055, sampled.g - sampled.b);
	// The compact mesh uses the whole orange ramp for individual shingles,
	// including its dark end; brightness therefore cannot distinguish timber
	// from tile without leaving conspicuous orange squares. The pale plaster
	// ramp is separable and remains untouched. Dark warm details become the
	// slate's shadow tones, which reads as one deliberately varied roof.
	float not_pale = 1.0 - smoothstep(0.54, 0.70, maximum);
	float tile_mask = smoothstep(0.10, 0.48,
		warm_hue * not_pale * smoothstep(0.02, 0.10, saturation));
	// The LPFV compact roof is the only complete gable that fits a 3 m room,
	// but both authored variants sample the same orange atlas ramp. Re-map that
	// bright tile ramp to weathered blue slate while leaving dark timber, pale
	// plaster, and metal details on their original atlas colours.
	float value = clamp(dot(sampled.rgb, vec3(0.28, 0.58, 0.14)), 0.0, 1.0);
	// Preserve much more of the source tile-value range. The earlier square-root
	// lift compressed almost the entire roof into pale cyan, making a varied slate
	// texture read like one painted plastic sheet at village scale.
	float slate_value = smoothstep(0.24, 0.72, value);
	vec3 slate = mix(vec3(0.045, 0.11, 0.16), vec3(0.23, 0.43, 0.50),
		slate_value);
	sampled.rgb = mix(sampled.rgb, slate, tile_mask);
	ALBEDO = sampled.rgb;
	// Deliberately do not write ALPHA. The source compact roof is an opaque
	// double-sided mesh with internal backing faces. Entering the transparent
	// pipeline disables the depth ordering those layers rely on and makes the
	// backing read as holes or broad pale sheets over the tiles.
	ROUGHNESS = 0.88;
}
