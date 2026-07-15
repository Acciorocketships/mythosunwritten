// One clear, stylized material for still water, currents, and falls. Dynamic
// height has three continuous contributors: the slow ambient swell shared by
// every water body, persistent packets transported through the current, and
// interactive ripple simulation. The SAME height displaces geometry and
// derives normals, refraction and caustics; there is no independent scrolling
// streak/noise layer.
shader_type spatial;
render_mode specular_schlick_ggx, depth_draw_always, cull_disabled;

#include "res://terrain/water/water_common.gdshaderinc"
#include "res://terrain/water/water_waves.gdshaderinc"

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// Persistent flow-transported packet field: R = signed height around 0.5,
// G = local breaking energy.
uniform sampler2D packet_tex : repeat_disable, filter_linear;
uniform vec2 packet_origin = vec2(1000000.0, 1000000.0);
uniform float packet_size = 192.0;

// Interactive and current-forced wave simulation: R/G = height/velocity
// around 0.5. Player impulses remain clear; no colour/foam channel exists.
uniform sampler2D ripple_tex : repeat_disable, filter_linear;
uniform vec2 ripple_origin = vec2(1000000.0, 1000000.0);
uniform float ripple_size = 96.0;
uniform float ripple_height : hint_range(0.0, 2.0) = 0.75;
uniform float ripple_normal_strength : hint_range(0.0, 20.0) = 8.0;

// Ambient spectrum remains CPU-mirrored by character.gd for buoyancy.
uniform float wave_height : hint_range(0.0, 1.5) = 0.38;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.26;

// Spectral clear-water budget. Red attenuates first, leaving a restrained
// blue-green cast only with real optical depth; shallow water is almost pure
// transmitted scene light.
uniform vec3 absorption = vec3(0.003, 0.001, 0.0005);
uniform vec3 scatter_color : source_color = vec3(0.16, 0.55, 0.56);
uniform float scatter_strength : hint_range(0.0, 1.0) = 0.02;
uniform vec3 sky_color : source_color = vec3(0.25, 0.55, 0.58);
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.035;
uniform float refraction_strength : hint_range(0.0, 0.12) = 0.045;
uniform float caustic_strength : hint_range(0.0, 1.0) = 0.18;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.22;
uniform float surface_specular : hint_range(0.0, 1.0) = 0.35;

varying vec3 world_pos;
varying float surface_scale;
varying float flow_compression;


float domain_fade(vec2 uv) {
	if (uv.x <= 0.0 || uv.y <= 0.0 || uv.x >= 1.0 || uv.y >= 1.0) {
		return 0.0;
	}
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	return smoothstep(0.0, 0.10, edge);
}


float packet_height_at(vec2 world_xz) {
	vec2 uv = (world_xz - packet_origin) / packet_size;
	return (texture(packet_tex, uv).r - 0.5) * domain_fade(uv);
}


float ripple_height_at(vec2 world_xz) {
	vec2 uv = (world_xz - ripple_origin) / ripple_size;
	return (texture(ripple_tex, uv).r - 0.5) * ripple_height * domain_fade(uv);
}


// Exact restoration of the old interaction-ripple read: adjacent simulation
// texels form a strong clear normal/refraction ring. The simulated height is
// ALSO present in water_dynamic_height(), so the same ring displaces geometry.
vec2 ripple_normal_gradient(vec2 world_xz) {
	vec2 uv = (world_xz - ripple_origin) / ripple_size;
	float fade = domain_fade(uv);
	if (fade <= 0.0) {
		return vec2(0.0);
	}
	float px = 1.0 / 256.0;
	float hl = texture(ripple_tex, uv - vec2(px, 0.0)).r;
	float hr = texture(ripple_tex, uv + vec2(px, 0.0)).r;
	float hd = texture(ripple_tex, uv - vec2(0.0, px)).r;
	float hu = texture(ripple_tex, uv + vec2(0.0, px)).r;
	return vec2(hr - hl, hu - hd) * ripple_normal_strength * fade;
}


// The single surface truth used in BOTH shader stages.
float water_dynamic_height(vec2 world_xz) {
	float ambient = water_wave_h(noise_tex, world_xz, TIME * wave_speed) * wave_height;
	return ambient + packet_height_at(world_xz) + ripple_height_at(world_xz);
}


void vertex() {
	vec3 base_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_scale = COLOR.r;
	flow_compression = CUSTOM1.w;
	float dynamic_height = water_dynamic_height(base_world.xz) * surface_scale;
	VERTEX += NORMAL * dynamic_height;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	vec2 p = world_pos.xz;
	float ep = 0.75;
	float hx1 = water_dynamic_height(p + vec2(ep, 0.0)) * surface_scale;
	float hx0 = water_dynamic_height(p - vec2(ep, 0.0)) * surface_scale;
	float hz1 = water_dynamic_height(p + vec2(0.0, ep)) * surface_scale;
	float hz0 = water_dynamic_height(p - vec2(0.0, ep)) * surface_scale;
	vec2 height_gradient = vec2(hx1 - hx0, hz1 - hz0) / (2.0 * ep);
	vec2 interaction_gradient = ripple_normal_gradient(p) * surface_scale;
	vec2 optical_gradient = height_gradient + interaction_gradient;
	// Only compact flow-transported packets generate the stylized bright
	// focusing pockets. Using the ambient spectrum's curvature here creates
	// endless parallel bands—the rejected streak look—even though it is real
	// geometry rather than a texture.
	float packet_h = packet_height_at(p);
	float packet_hx1 = packet_height_at(p + vec2(ep, 0.0));
	float packet_hx0 = packet_height_at(p - vec2(ep, 0.0));
	float packet_hz1 = packet_height_at(p + vec2(0.0, ep));
	float packet_hz0 = packet_height_at(p - vec2(0.0, ep));
	float packet_curvature = (packet_hx1 + packet_hx0 + packet_hz1
		+ packet_hz0 - 4.0 * packet_h) / (ep * ep) * surface_scale;

	vec3 mesh_world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 water_world_normal = normalize(mesh_world_normal
		+ vec3(-optical_gradient.x, 0.0, -optical_gradient.y));
	vec3 water_view_normal = normalize((VIEW_MATRIX * vec4(water_world_normal, 0.0)).xyz);
	NORMAL = water_view_normal;

	float depth = water_depth_world(depth_texture, SCREEN_UV,
		INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, world_pos.y);
	// Refraction bends with the gradient of the very height that moved this
	// fragment. Low frequency and modest amplitude keep the bottom legible.
	vec3 mesh_view_normal = normalize((VIEW_MATRIX * vec4(mesh_world_normal, 0.0)).xyz);
	vec2 normal_delta = water_view_normal.xy - mesh_view_normal.xy;
	vec2 refraction_offset = (normal_delta * 1.15
		+ vec2(optical_gradient.x, -optical_gradient.y) * 0.25)
		* refraction_strength * smoothstep(0.02, 0.9, depth)
		/ max(1.0, -VERTEX.z * 0.06);
	vec2 refracted_uv = SCREEN_UV + refraction_offset;
	float refracted_height = water_signed_height_world(depth_texture, refracted_uv,
		INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, world_pos.y);
	float valid_refraction = refracted_height < 0.0
		? 0.0 : smoothstep(0.0, 0.25, refracted_height);
	if (water_view_z(depth_texture, refracted_uv, INV_PROJECTION_MATRIX) > VERTEX.z + 0.35) {
		valid_refraction = 0.0;
	}
	refracted_uv = mix(SCREEN_UV, refracted_uv, valid_refraction);
	vec3 scene = texture(screen_texture, refracted_uv).rgb;

	// Surface curvature focuses the transmitted image into soft moving
	// caustics. It cannot become a detached texture because curvature comes
	// from water_dynamic_height itself.
	float caustic = smoothstep(0.0015, 0.025, abs(packet_curvature))
		* exp(-depth * 0.025) * caustic_strength;
	scene *= 1.0 + caustic;

	vec3 transmittance = exp(-absorption * depth);
	vec3 body = scene * transmittance
		+ scatter_color * (vec3(1.0) - transmittance) * scatter_strength;

	// Broad sky reflection. Dynamic detail enters only through the physical
	// surface normal, matching the reference's calm painterly sheen instead of
	// high-frequency shimmer. A screen/depth ray march was actively rejected:
	// its finite hit iterations became concentric bands at the far bank.
	float fresnel = pow(1.0 - clamp(dot(water_view_normal, VIEW), 0.0, 1.0), 5.0);
	float reflection_weight = (0.025 + fresnel * 0.975) * reflection_strength;
	body = mix(body, sky_color, reflection_weight);
	// The old swimmer ripple was readable because its narrow normal-gradient
	// ring caught the sky. Restore that optical cue explicitly while keeping
	// the height impulse colourless: the flat centre contributes nothing, so
	// this can never become the filled white blur produced by ripple foam.
	float interaction_reflection = smoothstep(0.008, 0.05,
		length(interaction_gradient)) * 0.10;
	body = mix(body, sky_color, interaction_reflection);

	// White exists only where persistent wavelets break or the continuous
	// current compresses. Player swim/entry ripples stay entirely clear.
	vec2 packet_uv = (p - packet_origin) / packet_size;
	float packet_breaking = texture(packet_tex, packet_uv).g * domain_fade(packet_uv);
	float foam_amount = clamp(packet_breaking * 0.20
		+ smoothstep(0.18, 0.65, flow_compression) * 0.04, 0.0, 0.30);
	body = mix(body, vec3(0.93, 0.97, 0.94), foam_amount);

	// Keep the refracted scene as emission so it is not lit a second time,
	// while returning the old PBR specular response to the REAL displaced
	// surface normal. This is what makes a clear swim ring and geometric
	// wavelet readable without turning either one into a white albedo decal.
	ALBEDO = vec3(0.0);
	EMISSION = body;
	ROUGHNESS = surface_roughness;
	SPECULAR = surface_specular;
	ALPHA = 1.0;
}
