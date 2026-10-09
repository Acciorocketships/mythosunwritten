shader_type fog;
#include "res://scripts/terrain/diagnostics/frontier_density.gdshaderinc"
uniform vec3 fog_color : source_color;
void fog() {
 DENSITY=frontier_density(WORLD_POSITION.xz);
 ALBEDO=mix(fog_color,vec3(0.8),0.35);
 EMISSION=fog_color*0.08;
}
