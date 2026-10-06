extends RefCounted
## Native fire sockets, in each baked asset's coordinates. One lightweight
## emitter follows each complete prop through streaming ownership and removal.
const SOURCES := {
	&"sfbp.campfire.001": [Vector3(0,.18,0),.55,.65],
	&"suntail.prop.bonfire": [Vector3(0,.08,0),.60,.65],
}
static var _mesh: QuadMesh
static var _process_material: ParticleProcessMaterial

static func attach(parent: Node3D, asset_id: StringName, placements: Array) -> void:
	if not SOURCES.has(asset_id): return
	_prepare()
	var source: Array = SOURCES[asset_id]
	for pose: Transform3D in placements:
		var fire := GPUParticles3D.new()
		fire.name = "CampfireFlames"
		fire.transform = pose*Transform3D(Basis.from_scale(Vector3(source[1],source[2],source[1])),source[0])
		fire.amount = 12
		fire.lifetime = .85
		fire.preprocess = 1.0
		fire.randomness = .4
		fire.fixed_fps = 30
		fire.local_coords = true
		fire.visibility_aabb = AABB(Vector3(-1,-.2,-1),Vector3(2,2.8,2))
		fire.visibility_range_end = 90.0
		fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fire.process_material = _process_material
		fire.draw_pass_1 = _mesh
		parent.add_child(fire)
		var light := OmniLight3D.new()
		light.name = "CampfireLight"
		light.position = pose*(Vector3(source[0])+Vector3.UP*.35)
		light.light_color = Color("ff9b40")
		light.light_energy = 1.2
		light.omni_range = 5.0*pose.basis.get_scale().length()/sqrt(3.0)
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = 35.0
		light.distance_fade_length = 20.0
		parent.add_child(light)

static func _prepare() -> void:
	if _mesh != null: return
	var material := ShaderMaterial.new()
	material.shader = preload("res://terrain/materials/campfire_flame.gdshader")
	_mesh = QuadMesh.new()
	_mesh.size = Vector2(.7,1.0)
	_mesh.material = material
	_process_material = ParticleProcessMaterial.new()
	_process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_process_material.emission_sphere_radius = .22
	_process_material.direction = Vector3.UP
	_process_material.spread = 12.0
	_process_material.initial_velocity_min = .65
	_process_material.initial_velocity_max = 1.0
	_process_material.gravity = Vector3(0,.3,0)
	_process_material.scale_min = .65
	_process_material.scale_max = 1.15
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0,.15,.55,1])
	ramp.colors = PackedColorArray([Color(1,.8,.2,0),Color(1,.65,.09,.9),Color(1,.19,.015,.6),Color(.7,.04,0,0)])
	var texture := GradientTexture1D.new()
	texture.gradient = ramp
	_process_material.color_ramp = texture
