uniform sampler2D loaded_cells : repeat_disable, filter_linear;
uniform vec2 first_cell;
uniform vec2 cell_count;
uniform float feather = 80.0;
bool loaded(vec2 cell) {
 vec2 offset = cell-first_cell;
 if(any(lessThan(offset,vec2(0))) || any(greaterThanEqual(offset,cell_count))) return false;
 return textureLod(loaded_cells,(offset+0.5)/cell_count,0.0).r>0.5;
}
// Bilinear coverage rounds corners and supplies a continuous inward band.
// One texture lookup per ray step keeps this full-screen continuation cheap.
float frontier_clearance(vec2 p) {
 vec2 uv=(p/192.0-first_cell)/cell_count;
 if(any(lessThan(uv,vec2(0))) || any(greaterThan(uv,vec2(1)))) return 0.0;
 float coverage=textureLod(loaded_cells,uv,0.0).r;
 return feather*clamp((coverage-0.5)*2.0,0.0,1.0);
}
float frontier_density(vec2 p) {
 float t=1.0-smoothstep(0.0,feather,frontier_clearance(p));
 return 0.3*t*t;
}
