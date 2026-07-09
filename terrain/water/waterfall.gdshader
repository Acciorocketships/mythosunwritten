// Waterfall: an ogee slab rendered with the SAME clear green glass as the
// water sheet — the refracted scene through the shared tint, the same
// fresnel-to-pale-sky grazing response and sun sheen — so crest, curtain and
// plunge pool read as one continuous body of water from EVERY angle (owner:
// falls "suddenly turned white"; later, from above the crest, the fall read
// as a dark slab against the sun-sheened pool). White is an ACCENT that
// develops in METRES below the crest (UV.y × UV2.y): the first stretch past
// the lip is clean glass, so no pale scalloped band hugs the crest line
// (owner's "detached diagonal skirt"), strengthening into the plunge, which
// dissolves into the pool. UV2.x marks side walls + lip cap: quieter foam
// and alpha so edge-on wings never read as bright detached shards.
shader_type spatial;
render_mode specular_schlick_ggx, cull_disabled, depth_draw_always;

#include "res://terrain/water/water_common.gdshaderinc"

uniform vec3 color_deep : source_color = vec3(0.33, 0.60, 0.55);
uniform vec3 color_shallow : source_color = vec3(0.55, 0.82, 0.73);
uniform vec3 color_sky : source_color = vec3(0.78, 0.90, 0.87);
uniform float sky_reflect : hint_range(0.0, 1.0) = 0.5;
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 0.98);
// SLOW: band scroll is the only self-motion the curtain has; anything fast
// reads as fast-forward footage (owner).
uniform float fall_speed : hint_range(0.5, 8.0) = 1.6;
uniform float refraction_strength : hint_range(0.0, 0.2) = 0.055;
uniform float body_tint : hint_range(0.0, 1.0) = 0.24;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

varying vec3 world_pos;
varying float side_v;
varying float drop_h;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	side_v = UV2.x;
	drop_h = UV2.y;
}

void fragment() {
	// Metres of water fallen since the crest: the visual driver for foam and
	// distortion, independent of how tall this particular fall is.
	float fallen = UV.y * drop_h;
	float col = texture(noise_tex, vec2((world_pos.x + world_pos.z) * 0.11, 0.0)).r;
	// Falling streaks: noise bands streaming down the arc.
	float fall = texture(noise_tex, vec2((world_pos.x + world_pos.z) * 0.07,
			UV.y * 0.6 - TIME * fall_speed * 0.25 + col)).r;
	float band = smoothstep(0.35, 0.75, fall);
	// The refracted scene through the fall. The distortion field is
	// CONTINUOUS with the sheet's (same noise, same coords, same drift near
	// the lip) and cross-fades into downward-scrolling fall motion as the
	// water accelerates — one water pattern flowing over the edge, never two
	// materials meeting at a line (owner: "make the texture/simulation
	// continuous, not per element"). Foreground geometry rejects, same
	// guard as the sheet.
	float wa = texture(noise_tex, world_pos.xz * 0.045
			+ vec2(TIME * 0.021, -TIME * 0.017)).r;
	float wb = texture(noise_tex, world_pos.xz * 0.045 + vec2(37.7, 11.3)
			+ vec2(-TIME * 0.019, TIME * 0.023)).r;
	float scroll = texture(noise_tex, vec2((world_pos.x + world_pos.z) * 0.045,
			UV.y * 0.35 - TIME * fall_speed * 0.16)).r;
	float develop = smoothstep(0.9, 3.2, fallen);
	vec2 wob = mix(vec2(wa, wb) - 0.5, vec2(band, scroll) - 0.5, develop);
	vec2 roff = wob * refraction_strength * smoothstep(0.1, 1.0, fallen)
			/ max(1.0, -VERTEX.z * 0.08);
	vec2 suv = SCREEN_UV + roff;
	if (water_view_z(depth_texture, suv, INV_PROJECTION_MATRIX) > VERTEX.z + 0.05) {
		suv = SCREEN_UV;
	}
	vec3 scene = texture(screen_texture, suv).rgb;
	vec3 body = mix(scene * mix(vec3(1.0), color_shallow, 0.18), color_deep, body_tint);
	// Same grazing response as the sheet: glancing views mirror the pale sky
	// tint — without it the slab read DARK against the sun-sheened pool from
	// above the crest, a hard diagonal seam right along the lip.
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 5.0);
	body = mix(body, color_sky, fres * sky_reflect);
	// The base converges to the POOL'S body tone (the screen texture cannot
	// see transparent water, so the fall's see-through showed the BED where
	// the pool shows its own deep tint — the bottom never blended).
	body = mix(body, color_deep, 0.30 * smoothstep(0.45, 1.0, UV.y));
	// Foam DEVELOPS with the fall: a thin BREAK LINE right at the lip (marks
	// every weir crest even at grazing angles, where a bare 2m step read as
	// a mysterious tone seam), clean glass through the first metre, streaks
	// building as the water accelerates, full white into the plunge, then
	// the slab dissolves into the pool from the fillet on.
	float lip_line = 0.22 * smoothstep(0.08, 0.28, fallen)
			* (1.0 - smoothstep(0.5, 0.95, fallen));
	// The base rises toward the sheet's plunge-churn whiteness (0.3..0.75
	// boil) so the alpha cross-fade at the pool lands white-on-white — the
	// hand-off line disappears into shared churn.
	float plunge = smoothstep(0.6, 1.0, UV.y);
	float foam = clamp(lip_line + develop * (0.18 + 0.55 * band) + 0.45 * plunge,
			0.0, 1.0);
	foam *= 1.0 - 0.6 * side_v;
	ALBEDO = mix(body, foam_color, foam);
	// The lower half grows TRANSLUCENT before the plunge dissolve: the pool's
	// own tone (often the terrain's shadow) bleeds through the falling water,
	// so the fall grades into the pool instead of pinning bright white
	// against a dark surface (owner: "not even close to blending here").
	float sink = mix(1.0, 0.62, smoothstep(0.5, 0.95, UV.y));
	float fade = 1.0 - smoothstep(0.85, 1.05, UV.y);
	// The overlap strip tucked UNDER the drooped sheet is fully transparent:
	// transparent-pass sorting sometimes draws it over the sheet, and its
	// edge showed as a thin bright line crossing the crest (round-7 raycast).
	float lip_in = smoothstep(0.0, 0.04, UV.y);
	ALPHA = mix(0.92, 0.24, side_v) * fade * sink * lip_in;
	// Glassy where clear (the sun path continues over the lip), rough where
	// foamy — never mirror-tight (a hard specular beam at grazing sun).
	ROUGHNESS = mix(0.28, 0.55, max(foam, 0.35 * side_v));
	SPECULAR = mix(0.35, 0.6, fres);
}
