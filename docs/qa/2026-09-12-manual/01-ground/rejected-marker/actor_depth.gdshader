shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
void vertex() { POSITION = vec4(VERTEX.xy, 0.0, 1.0); }
void fragment() {
 if (CAMERA_VISIBLE_LAYERS != 524288u) { discard; }
 float depth = texture(scene_depth, SCREEN_UV).r;
 vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
 // Millimetre depth in three byte channels. Linearize the bytes before
 // the viewport's output transfer, so the sampling pass receives raw bytes.
 uint code = depth > 0.000001 ? uint(clamp(-view.z / view.w * 1000.0, 1.0, 16777215.0)) : 0u;
 vec3 bytes = vec3(float(code & 255u), float((code >> 8u) & 255u), float((code >> 16u) & 255u)) / 255.0;
 ALBEDO = mix(bytes / 12.92, pow((bytes + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), bytes));
 ALPHA = 1.0;
}
