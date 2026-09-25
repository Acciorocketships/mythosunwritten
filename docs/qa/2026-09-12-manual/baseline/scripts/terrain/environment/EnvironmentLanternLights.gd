extends RefCounted

## Main-thread lighting semantics for the finite native lantern families.
## Positions are in baked visual coordinates; the placement transform applies
## once. Lights have world-metre ranges, do not cast shadows, and fade at distance.
const SOURCES := {
	&"sfv.light_pole.001": [Vector3(-0.007571,4.495525,0.9382445),18.0,1.8],
	&"lpfv.fabric.prop.lantern.table.01": [Vector3(0.0,0.100772,0.0),12.0,1.1],
	&"lpfv.fabric.prop.lantern.post.02": [Vector3(0.9129635,1.5329055,0.0),18.0,1.8],
}

static func attach(parent: Node3D, asset_id: StringName, placements: Array) -> void:
	if not SOURCES.has(asset_id): return
	var source: Array = SOURCES[asset_id]
	for pose: Transform3D in placements:
		var light := OmniLight3D.new()
		light.name = "LanternLight"
		light.position = pose*Vector3(source[0])
		light.light_color = Color("ffd19a")
		light.light_energy = source[2]
		light.omni_range = source[1]
		light.omni_attenuation = 1.2
		light.shadow_enabled = false
		light.light_volumetric_fog_energy = 0.35
		light.distance_fade_enabled = true
		light.distance_fade_begin = 55.0
		light.distance_fade_length = 25.0
		parent.add_child(light)

static var _glass_materials: Dictionary = {}

static func glass_material(asset_id: StringName, piece: EnvironmentVisualPiece) -> Material:
	if asset_id != &"lpfv.fabric.prop.lantern.table.01" and asset_id != &"lpfv.fabric.prop.lantern.post.02":
		return piece.material_override
	if _glass_materials.has(asset_id): return _glass_materials[asset_id]
	var source := piece.mesh.surface_get_material(0) as StandardMaterial3D
	var material := ShaderMaterial.new()
	material.shader = preload("res://terrain/materials/lantern_glass.gdshader")
	material.set_shader_parameter("palette",source.albedo_texture)
	_glass_materials[asset_id] = material
	return material
