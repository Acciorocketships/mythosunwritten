// Waterfall: an arced curtain of foam bands falling over the shared water
// palette, plus a churning splash apron where the fall lands. UV.y runs
// crest(0) -> plunge(1) -> apron tip(~1.3); world-x/z noise decorrelates the
// columns so side-by-side falls never read as one repeating sheet.
shader_type spatial;
render_mode specular_schlick_ggx, cull_disabled, depth_draw_always;

uniform vec3 color_deep : source_color = vec3(0.13, 0.46, 0.44);
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 0.98);
uniform float fall_speed : hint_range(0.5, 8.0) = 2.6;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float col = texture(noise_tex, vec2((world_pos.x + world_pos.z) * 0.11, 0.0)).r;
	float splash = smoothstep(1.0, 1.06, UV.y);
	// Falling curtain: noise bands streaming down the arc.
	float fall = texture(noise_tex, vec2((world_pos.x + world_pos.z) * 0.07,
			UV.y * 0.6 - TIME * fall_speed * 0.25 + col)).r;
	float band = smoothstep(0.35, 0.75, fall);
	// Crest curls over white; the plunge churns white into the splash.
	float ends = max(smoothstep(0.25, 0.0, UV.y), smoothstep(0.7, 1.0, UV.y));
	float curtain_foam = clamp(0.35 + 0.6 * band + 0.35 * ends, 0.0, 1.0);
	// Splash apron: boiling two-octave foam drifting downstream (toward
	// +UV.y), dissolving to nothing by the apron tip.
	vec2 suv = vec2((world_pos.x + world_pos.z) * 0.09, UV.y * 2.0 - TIME * 0.6);
	float churn = texture(noise_tex, suv).r * 0.6
		+ texture(noise_tex, suv * 2.3 + vec2(0.37, TIME * 0.22)).r * 0.4;
	float fade = 1.0 - smoothstep(1.05, 1.3, UV.y);
	float splash_foam = clamp(0.55 + 0.8 * (churn - 0.35), 0.0, 1.0);
	float foam = mix(curtain_foam, splash_foam, splash);
	ALBEDO = mix(color_deep, foam_color, foam);
	float alpha_curtain = 0.82 + 0.13 * band;
	float alpha_splash = fade * clamp(0.35 + churn, 0.0, 0.95);
	ALPHA = mix(alpha_curtain, alpha_splash, splash);
	// Rough enough that direct sun never draws a hard specular beam across
	// the curtain (0.35 left a white laser streak at grazing sun angles).
	ROUGHNESS = mix(0.5, 0.65, splash);
}
