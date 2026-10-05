// Geometry-beam experiment inspired by joryleech's MIT light-ray material.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 light_color : source_color = vec4(1.0, 0.8, 0.45, 1.0);
varying vec3 local_point;
void vertex() { local_point = VERTEX; }
void fragment() {
	float raw = texture(depth_texture, SCREEN_UV).r;
	vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	float separation = -scene.z / scene.w + VERTEX.z;
	float along = (local_point.y + 9.5) / 19.0;
	float ends = smoothstep(0.0, 0.25, along) * (1.0 - smoothstep(0.7, 1.0, along));
	float face = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	ALBEDO = light_color.rgb;
	ALPHA = 0.045 * ends * face * smoothstep(0.0, 2.0, separation);
}
