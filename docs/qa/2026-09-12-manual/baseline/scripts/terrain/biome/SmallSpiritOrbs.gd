extends Node3D

## One canonical orb per ground-following firefly anchor. Geometry is batched;
## nearby instances borrow at most sixteen shadow-free lights in this chunk.
## The pool allocates on demand and returns lights when the camera departs.
const LIGHT_LIMIT := 16
const LIGHT_DISTANCE := 50.0
const VISIBLE_DISTANCE := 90.0
var anchors := PackedVector3Array()
var phases := PackedFloat32Array()
var elapsed := 0.0
var _cores: MultiMeshInstance3D
var _halos: MultiMeshInstance3D
var _lights: Array[OmniLight3D] = []
var _bounds := AABB()

func setup(points: PackedVector3Array) -> void:
	name = "SmallSpiritOrbs"
	anchors = points
	phases.resize(points.size())
	_cores = _batch("Cores",SpiritOrb.core_mesh(SpiritOrb.SMALL_DIAMETER))
	_halos = _batch("Halos",SpiritOrb.halo_mesh(SpiritOrb.SMALL_HALO))
	if not points.is_empty(): _bounds = AABB(points[0],Vector3.ZERO)
	for i in points.size():
		phases[i] = SpiritOrb.phase_at(points[i])
		_bounds = _bounds.expand(points[i])
		var color := SpiritOrb.color_at(phases[i])
		_cores.multimesh.set_instance_color(i,color)
		_halos.multimesh.set_instance_color(i,color)
		var pose := Transform3D(Basis.IDENTITY,points[i]+SpiritOrb.offset_at(0.0,phases[i]))
		_cores.multimesh.set_instance_transform(i,pose)
		_halos.multimesh.set_instance_transform(i,pose)
	_bounds = _bounds.grow(3.0)
	_cores.custom_aabb = _bounds
	_halos.custom_aabb = _bounds

func _batch(label: String, mesh: Mesh) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = label
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.instance_count = anchors.size()
	multi.mesh = mesh
	node.multimesh = multi
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _process(dt: float) -> void:
	elapsed += dt
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	sample(elapsed,to_local(camera.global_position))

func sample(seconds: float, viewer: Vector3) -> void:
	var nearest := viewer.clamp(_bounds.position,_bounds.end)
	if nearest.distance_squared_to(viewer) > VISIBLE_DISTANCE * VISIBLE_DISTANCE:
		visible = false
		_release_lights()
		return
	visible = true
	var candidates: Array = []
	for i in anchors.size():
		var point := anchors[i]+SpiritOrb.offset_at(seconds,phases[i])
		var pose := Transform3D(Basis.IDENTITY,point)
		_cores.multimesh.set_instance_transform(i,pose)
		_halos.multimesh.set_instance_transform(i,pose)
		var distance := point.distance_squared_to(viewer)
		if distance < LIGHT_DISTANCE * LIGHT_DISTANCE:
			candidates.append([distance,i,point])
	candidates.sort_custom(func(a: Array,b: Array) -> bool:
		return a[0]<b[0] if a[0]!=b[0] else a[1]<b[1])
	var count := mini(candidates.size(),LIGHT_LIMIT)
	while _lights.size() < count:
		var light := OmniLight3D.new()
		light.name = "SmallOrbLight"
		SpiritOrb.configure_light(light,true)
		add_child(light)
		_lights.append(light)
	for i in _lights.size():
		_lights[i].visible = i<count
		if i<count:
			_lights[i].position = candidates[i][2]
			_lights[i].light_color = SpiritOrb.color_at(phases[candidates[i][1]])
	if count == 0: _release_lights()

func _release_lights() -> void:
	for light in _lights: light.queue_free()
	_lights.clear()
