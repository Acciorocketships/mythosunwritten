extends CameraVisibilityBubble
var timings := {}

func update_bubble(camera: Camera3D,target: Node3D,feet: Vector3,radius: float,opacity: float,delta: float) -> void:
	timings.clear()
	super.update_bubble(camera,target,feet,radius,opacity,delta)

func _select(camera: Camera3D,target: Node3D,feet: Vector3,radius: float) -> void:
	var start := Time.get_ticks_usec()
	super._select(camera,target,feet,radius)
	timings.select = Time.get_ticks_usec()-start

func _install(node: GeometryInstance3D) -> Dictionary:
	var start := Time.get_ticks_usec()
	var state := super._install(node)
	var elapsed := Time.get_ticks_usec()-start
	timings.install = int(timings.get("install",0))+elapsed
	var kind := node.get_class()
	if node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
		kind += "_%d" % node.multimesh.mesh.get_surface_count()
	var detail: Dictionary = timings.get("install_kinds",{})
	detail[kind] = int(detail.get(kind,0))+elapsed
	timings.install_kinds = detail
	return state

func _adapt(source: Material,state: Dictionary) -> ShaderMaterial:
	var start := Time.get_ticks_usec()
	var material := super._adapt(source,state)
	timings.adapt = int(timings.get("adapt",0))+Time.get_ticks_usec()-start
	timings.materials = _materials.size()
	return material

func _sync_source_parameters() -> void:
	var start := Time.get_ticks_usec()
	super._sync_source_parameters()
	timings.sync = Time.get_ticks_usec()-start
