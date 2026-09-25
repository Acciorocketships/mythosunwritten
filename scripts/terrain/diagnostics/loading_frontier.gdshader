shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D loaded_cells : repeat_disable, filter_nearest;
uniform vec2 first_cell;
uniform vec2 cell_count;
uniform vec3 owner_eye;
uniform vec3 fog_color : source_color;
uniform float feather = 48.0;

bool loaded(vec2 cell) {
 vec2 offset = cell - first_cell;
 if (any(lessThan(offset,vec2(0.0))) || any(greaterThanEqual(offset,cell_count))) { return false; }
 return textureLod(loaded_cells,(offset+0.5)/cell_count,0.0).r > 0.5;
}
vec2 boundary_distance(vec2 eye, vec2 ray) {
 vec2 cell = floor(eye/192.0);
 if (!loaded(cell)) { return vec2(0.0,1.0); }
 if (length(ray)<0.000001) { return vec2(1e20,1.0); }
 vec2 stride = sign(ray);
 vec2 delta = vec2(192.0)/max(abs(ray),vec2(0.0000001));
 vec2 next = ((cell+max(stride,vec2(0.0)))*192.0-eye)/mix(vec2(0.0000001),ray,greaterThan(abs(ray),vec2(0.0000001)));
 if (abs(ray.x)<0.0000001) { next.x = 1e20; }
 if (abs(ray.y)<0.0000001) { next.y = 1e20; }
 // The bounded residency map has at most 32 cells along either axis.
 for (int i=0; i<64; i++) {
  float d = min(next.x,next.y);
  bvec2 crossed = lessThanEqual(next,vec2(d));
  if (crossed.x) { cell.x += stride.x; next.x += delta.x; }
  if (crossed.y) { cell.y += stride.y; next.y += delta.y; }
  if (!loaded(cell)) { return vec2(max(d,0.0),crossed.x ? abs(ray.x) : abs(ray.y)); }
 }
 return vec2(0.0,1.0);
}
void vertex() { POSITION = vec4(VERTEX.xy,1.0,1.0); }
void fragment() {
 if (distance(INV_VIEW_MATRIX[3].xyz,owner_eye)>0.01) { discard; }
 float depth = texture(scene_depth,SCREEN_UV).r;
 bool sky = depth < 0.000001;
 vec4 view_point = INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,max(depth,0.000001),1.0);
 vec3 relative = mat3(INV_VIEW_MATRIX)*(view_point.xyz/view_point.w);
 float horizontal = length(relative.xz);
 vec2 ray = relative.xz/max(horizontal,0.000001);
 vec2 edge = boundary_distance(owner_eye.xz,ray);
 // Keep the near field clear when the camera approaches a missing neighbor.
 // A fixed 48 m fade would otherwise wash out the actor and its footing.
 // Measure perpendicular distance to the frontier, so an oblique look does
 // not stretch the haze along the boundary. At and beyond it opacity is 1.
 float fade_width = max(0.001,min(feather,edge.x*edge.y*0.35));
 float inward_distance = (edge.x-horizontal)*edge.y;
 float opacity = 1.0-smoothstep(0.0,fade_width,inward_distance);
 // Preserve the overhead sky; the horizon and downward void receive mist.
 if (sky) { opacity *= 1.0-smoothstep(0.0,0.18,normalize(relative).y); }
 ALBEDO = fog_color;
 ALPHA = opacity;
}
