shader_type spatial;
render_mode unshaded, fog_disabled, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D actor_depth : repeat_disable, filter_nearest;
uniform vec3 view_eye;
uniform vec2 actor_focus_uv;
void vertex() { POSITION = vec4(VERTEX.xy, 0.0, 1.0); }
float hidden_depth(vec2 uv, mat4 inv_projection) {
 vec3 bytes = round(texture(actor_depth, uv).rgb * 255.0);
 float actor_z = -dot(bytes, vec3(1.0, 256.0, 65536.0)) / 1000.0;
 if (actor_z >= 0.0) { return 0.0; }
 float depth = texture(scene_depth, uv).r;
 vec4 scene = inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
 return scene.z / scene.w - actor_z;
}
void fragment() {
 if (distance(INV_VIEW_MATRIX[3].xyz, view_eye) > 0.1) { discard; }
 // Ordinary grass at the feet does not call for a marker while the head
 // remains visible. Actual scene depth, rather than collision, decides.
 if (hidden_depth(actor_focus_uv, INV_PROJECTION_MATRIX) <= 0.08) { discard; }
 if (hidden_depth(SCREEN_UV, INV_PROJECTION_MATRIX) <= 0.08) { discard; }
 ALBEDO = vec3(0.37, 0.28, 0.64);
 ALPHA = 0.72;
}
