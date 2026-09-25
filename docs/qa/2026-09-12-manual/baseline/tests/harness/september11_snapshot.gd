extends RefCounted
## Frozen geometry/physics from a completely streamed production site. This
## accelerates repeated camera tests; generation and readiness tests stay live.
static func save(world: Node3D, actor: Node3D, path: String) -> void:
	var stage := Node3D.new()
	stage.name = "FrozenVillage"
	for source: Node in world.find_children("*","",true,false):
		if source == actor or actor.is_ancestor_of(source): continue
		var copy: Node
		if source is GeometryInstance3D or source is Light3D or source is FogVolume:
			copy = source.duplicate(0)
			for child: Node in copy.get_children(): child.free()
			copy.set_script(null)
			copy.transform = source.global_transform
		elif source is WorldEnvironment:
			copy = source.duplicate(0)
		elif source is CollisionShape3D and source.get_parent() is StaticBody3D:
			var body := StaticBody3D.new()
			body.collision_layer = source.get_parent().collision_layer
			body.collision_mask = source.get_parent().collision_mask
			var shape := CollisionShape3D.new()
			shape.name = source.name
			shape.shape = source.shape
			shape.transform = source.global_transform
			shape.disabled = source.disabled
			body.add_child(shape)
			copy = body
		else: continue
		stage.add_child(copy)
		copy.owner = stage
		for child: Node in copy.get_children(): child.owner = stage
	var globals := {}
	for key: StringName in RenderingServer.global_shader_parameter_get_list():
		globals[key] = RenderingServer.global_shader_parameter_get(key)
	stage.set_meta("shader_globals",globals)
	var packed := PackedScene.new()
	assert(packed.pack(stage)==OK)
	assert(ResourceSaver.save(packed,path)==OK)
	stage.free()
	print("VILLAGE_SNAPSHOT ",path)
