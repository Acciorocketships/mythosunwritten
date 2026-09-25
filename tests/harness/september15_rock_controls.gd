extends "res://tests/harness/september15_reported_qa.gd"
## Toggle only the new baked rock/plant batches in a frozen production world.
## This is a dressing-isolation control, not a historical world-generation replay.
func _capture_views(world:Node3D)->void:
	if "--bare-rocks" in OS.get_cmdline_user_args():
		var rocks=preload("res://scripts/terrain/field/CliffRockDressing.gd")
		rocks.prepare()
		var hidden:=0
		for node:MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
			var mesh:=node.multimesh.mesh
			for asset:StringName in rocks._visuals:
				for piece:EnvironmentVisualPiece in rocks._visuals[asset].pieces:
					if mesh.get_aabb().is_equal_approx(piece.mesh.get_aabb()) and mesh.get_faces().size()==piece.mesh.get_faces().size():
						node.visible=false;hidden+=1
		print("ROCK_CONTROL hidden_batches=",hidden)
		assert(hidden>0)
		if "--bare-rock-collision" in OS.get_cmdline_user_args():
			for shape:CollisionShape3D in world.find_children("*","CollisionShape3D",true,false):
				if shape.name in [&"CliffRocks",&"NativeTerraces"]:shape.disabled=true
	if "--settled-feet" in OS.get_cmdline_user_args():
		await get_tree().physics_frame
		var feet:Vector3=_spot[2]
		var query:=PhysicsRayQueryParameters3D.create(feet+Vector3.UP*10,feet-Vector3.UP*20)
		query.exclude=[_character.get_rid()]
		var hit:=_camera.get_world_3d().direct_space_state.intersect_ray(query)
		assert(not hit.is_empty())
		_spot=_spot.duplicate()
		_spot[2]=hit.position
		print("ROCK_CONTROL settled_feet original=",feet," actual=",hit.position)
	await super._capture_views(world)
