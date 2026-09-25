shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 medium_color : source_color = vec3(0.10,0.28,0.31);
uniform vec3 owner_eye;
uniform float immersion = 0.0;
uniform float extinction = 0.065;
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
void fragment() {
 if (distance(INV_VIEW_MATRIX[3].xyz,owner_eye)>0.01) { discard; }
 float depth = texture(scene_depth,SCREEN_UV).r;
 vec4 point = INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,depth,1.0);
 float distance_in_water = depth < 0.000001 ? 1000.0 : length(point.xyz / point.w);
 ALBEDO = medium_color;
 ALPHA = immersion*(1.0-exp(-extinction*distance_in_water));
}
