// Waterfall: an ogee slab rendered with the SAME clear green glass as the
// water sheet — the refracted scene through the shared tint — so crest,
// curtain and plunge pool read as one continuous body of water (owner: "the
// waterfall should be visually continuous with the water next to it", not a
// sheet that "suddenly turns white"). White is an ACCENT that DEVELOPS on
// the way down: streak bands gated by UV.y leave the crest as clean glass
// flush with the upper pool, strengthen into the plunge, and dissolve into
// the pool. UV2.x marks side walls + lip cap: quieter foam and alpha so the
// edge-on wings never read as bright detached shards (owner's "lip issues").
shader_type spatial;
render_mode specular_schlick_ggx, cull_disabled, depth_draw_always;

#include "res://terrain/water/water_common.gdshaderinc"

uniform vec3 color_deep : source_color = vec3(0.33, 0.60, 0.55);
uniform vec3 color_shallow : source_color = vec3(0.55, 0.82, 0.73);
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 0.98);
// SLOW: band scroll is the only self-motion the curtain has; anything fast
// reads as fast-forward footage (owner).
uniform float fall_speed : hint_range(0.5, 8.0) = 1.6;
uniform float refraction_strength : hint_range(0.0, 0.2) = 0.055;
uniform float body_tint : hint_range(0.0, 1.0) = 0.35;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

varying vec3 world_pos;
varying float side_v;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	side_v = UV2.x;
}

void fragment() {
	float col = texture(noise_tex, vec2((world_pos.x + world_pos.z) * 0.11, 0.0)).r;
	// Falling streaks: noise bands streaming down the arc.
	float fall = texture(noise_tex, vec2((world_pos.x + world_pos.z) * 0.07,
			UV.y * 0.6 - TIME * fall_speed * 0.25 + col)).r;
	float band = smoothstep(0.35, 0.75, fall);
	// The refracted scene through the fall: the offset wobbles with the
	// streaks and scrolls downward — the glassy distortion IS the falling
	// water. Reject samples of FOREGROUND geometry (nearer than this
	// fragment), same guard as the sheet.
	float scroll = texture(noise_tex, vec2((world_pos.x + world_pos.z) * 0.045,
			UV.y * 0.35 - TIME * fall_speed * 0.16)).r;
	vec2 roff = vec2(band - 0.5, scroll - 0.5) * refraction_strength
			/ max(1.0, -VERTEX.z * 0.08);
	vec2 suv = SCREEN_UV + roff;
	if (water_view_z(depth_texture, suv, INV_PROJECTION_MATRIX) > VERTEX.z + 0.05) {
		suv = SCREEN_UV;
	}
	vec3 scene = texture(screen_texture, suv).rgb;
	vec3 body = mix(scene * mix(vec3(1.0), color_shallow, 0.18), color_deep, body_tint);
	// Foam DEVELOPS down the fall; the plunge whitens fully, then the slab
	// dissolves into the pool from the fillet on (a streak texture stopping
	// dead against the calm pool read as a hard seam — owner).
	float develop = smoothstep(0.1, 0.7, UV.y);
	float plunge = smoothstep(0.7, 1.0, UV.y);
	float foam = clamp(develop * (0.18 + 0.55 * band) + 0.4 * plunge, 0.0, 1.0);
	foam *= 1.0 - 0.6 * side_v;
	ALBEDO = mix(body, foam_color, foam);
	float fade = 1.0 - smoothstep(0.88, 1.06, UV.y);
	ALPHA = mix(0.92, 0.32, side_v) * fade;
	// Rough enough that direct sun never draws a hard specular beam across
	// the curtain (0.35 left a white laser streak at grazing sun angles).
	ROUGHNESS = 0.5;
}
