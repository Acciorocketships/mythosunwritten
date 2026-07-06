// Shared stylized-water building blocks (ponds + rivers). Extracted from
// Water.gdshader so both surfaces keep one visual language: rolling world-
// space waves, vertical-depth tinting, animated shore foam.

// Long-wavelength swells: two crossing directional waves plus a broad noise
// drift. Pure function of world position — seamless across chunk meshes.
float water_wave_h(sampler2D noise_tex, vec2 p, float t) {
	float h = sin(p.x * 0.11 + t * 0.9) * cos(p.y * 0.085 + t * 0.66);
	h += 0.7 * sin(dot(p, vec2(0.071, 0.052)) - t * 1.05);
	h += 1.0 * (textureLod(noise_tex, p * 0.0045 + vec2(t * 0.006, -t * 0.0045), 0.0).r - 0.5);
	return h;
}

// Crest-sharpened wave trains advected downstream at `speed` (m/s): sharp
// ridges, flat troughs (1-|sin| profile), two wavelengths (~14m and ~26m),
// decorrelated by world noise so crests never read as parallel bars.
// Roughly zero-mean so the sheet's average level doesn't rise.
float water_chop_h(sampler2D noise_tex, vec2 p, vec2 fdir, float speed, float t) {
	float along = dot(p, fdir);
	float across = dot(p, vec2(-fdir.y, fdir.x));
	float brk = textureLod(noise_tex, p * 0.03, 0.0).r;
	float w1 = 1.0 - abs(sin((along - t * speed) * 0.45 + across * 0.18 + brk * 4.0));
	float w2 = 1.0 - abs(sin((along - t * speed * 1.30) * 0.24 - across * 0.10 + brk * 2.5));
	return w1 * w1 * 0.65 + w2 * w2 * 0.35 - 0.45;
}

// VERTICAL water depth at this fragment: reconstruct the opaque scene point
// behind it and measure how far below the (displaced) water surface it sits.
float water_depth_world(sampler2D depth_tex, vec2 screen_uv, mat4 inv_projection, mat4 inv_view, float surface_world_y) {
	float depth_raw = texture(depth_tex, screen_uv).r;
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth_raw);
	vec4 scene_view = inv_projection * vec4(ndc, 1.0);
	scene_view.xyz /= scene_view.w;
	vec4 scene_world = inv_view * vec4(scene_view.xyz, 1.0);
	return max(surface_world_y - scene_world.y, 0.0);
}

// Animated lapping shore-foam mask from vertical depth.
float water_foam_mask(sampler2D noise_tex, vec2 world_xz, float t, float depth, float foam_width) {
	float foam_noise = texture(noise_tex, world_xz * 0.11 + vec2(t * 0.03, -t * 0.022)).r;
	float foam_edge = foam_width * (0.5 + 0.7 * foam_noise);
	float mask = 1.0 - smoothstep(foam_edge * 0.55, foam_edge, depth);
	return mask * (0.8 + 0.2 * sin(t * 1.9 + foam_noise * 6.0));
}
