// Waterfall: an ogee slab of foam bands falling over the shared water
// palette. UV.y runs crest(0) -> plunge(1) -> submerged runout(~1.08);
// world-x/z noise decorrelates the columns so side-by-side falls never read
// as one repeating sheet. The plunge foam is PARTICLE mist built beside the
// mesh — no painted churn apron (owner: the textured splash looked bad).
shader_type spatial;
render_mode specular_schlick_ggx, cull_disabled, depth_draw_always;

uniform vec3 color_deep : source_color = vec3(0.26, 0.55, 0.52);
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 0.98);
// SLOW: band scroll is the only self-motion the curtain has; anything fast
// reads as fast-forward footage (owner).
uniform float fall_speed : hint_range(0.5, 8.0) = 1.6;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float col = texture(noise_tex, vec2((world_pos.x + world_pos.z) * 0.11, 0.0)).r;
	// Falling curtain: noise bands streaming down the arc.
	float fall = texture(noise_tex, vec2((world_pos.x + world_pos.z) * 0.07,
			UV.y * 0.6 - TIME * fall_speed * 0.25 + col)).r;
	float band = smoothstep(0.35, 0.75, fall);
	// Crest curls over white; the plunge whitens into the mist.
	// Crest whitening kept SOFT: at grazing angles the bright cap reads as a
	// floating white hairline across the water behind it.
	float ends = max(0.6 * smoothstep(0.22, 0.0, UV.y), smoothstep(0.7, 1.0, UV.y));
	// Foam floor kept high: several translucent layers stack when looking
	// through the slab (front + back + side walls) and a dark base colour
	// compounds into a murky wedge at grazing side views.
	float foam = clamp(0.42 + 0.55 * band + 0.35 * ends, 0.0, 1.0);
	ALBEDO = mix(color_deep, foam_color, foam);
	// Dissolve into the plunge pool EARLY (from the fillet on): the curtain's
	// streak texture stopping dead against the calm pool read as a sudden
	// visual seam (owner) — now it fades through the last bend.
	float fade = 1.0 - smoothstep(0.88, 1.06, UV.y);
	ALPHA = (0.78 + 0.12 * band) * fade;
	// Rough enough that direct sun never draws a hard specular beam across
	// the curtain (0.35 left a white laser streak at grazing sun angles).
	ROUGHNESS = 0.5;
}
