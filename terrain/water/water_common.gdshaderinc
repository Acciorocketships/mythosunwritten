// Shared stylized-water building blocks: depth reconstruction only. The
// wave-height functions (pond spectrum + river trains) that used to live
// here moved OUT wholesale in r3 Task 8 to
// terrain/water/water_waves.gdshaderinc — the single wave-constants table
// water_unified.gdshader's vertex() and fragment() both #include, so no
// wave math is duplicated between the two stages (see that file's own
// header). This file keeps only the screen-space/depth-texture helpers that
// have nothing to do with wave shape and are shared as-is.

// View-space Z of the opaque scene point at screen uv (negative; more
// negative = farther from the camera). Lets the refraction guard reject
// FOREGROUND geometry: offsetting the screen sample onto something nearer
// than the water fragment pastes a ghost copy of it into the water.
float water_view_z(sampler2D depth_tex, vec2 uv, mat4 inv_projection) {
	float depth_raw = texture(depth_tex, uv).r;
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth_raw);
	vec4 v = inv_projection * vec4(ndc, 1.0);
	return v.z / v.w;
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
