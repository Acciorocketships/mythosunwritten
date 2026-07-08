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
	// The refracted scene through the fall: the offset wobbles with the
	// streaks and scrolls downward — the glassy distortion IS the falling
	// water. The crest passes the scene through UNDISTORTED (clean glass,
	// continuous with the pool above); foreground geometry rejects, same
	// guard as the sheet.
	float scroll = texture(noise_tex, vec2((world_pos.x + world_pos.z) * 0.045,
			UV.y * 0.35 - TIME * fall_speed * 0.16)).r;
	vec2 roff = vec2(band - 0.5, scroll - 0.5) * refraction_strength
			* smoothstep(0.15, 1.4, fallen) / max(1.0, -VERTEX.z * 0.08);
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
	// Foam DEVELOPS with the fall: clean glass for the first metre past the
	// lip, streaks building as the water accelerates, full white into the
	// plunge, then the slab dissolves into the pool from the fillet on (a
	// streak texture stopping dead against the calm pool read as a seam).
	float develop = smoothstep(0.9, 3.2, fallen);
	float plunge = smoothstep(0.7, 1.0, UV.y);
	float foam = clamp(develop * (0.18 + 0.55 * band) + 0.4 * plunge, 0.0, 1.0);
	foam *= 1.0 - 0.6 * side_v;
	ALBEDO = mix(body, foam_color, foam);
	float fade = 1.0 - smoothstep(0.88, 1.06, UV.y);
	ALPHA = mix(0.92, 0.24, side_v) * fade;
	// Glassy where clear (the sun path continues over the lip), rough where
	// foamy — never mirror-tight (a hard specular beam at grazing sun).
	ROUGHNESS = mix(0.28, 0.55, max(foam, 0.35 * side_v));
	SPECULAR = mix(0.35, 0.6, fres);
}
