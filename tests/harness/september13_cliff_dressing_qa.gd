extends "res://tests/harness/september13_cliff_hierarchy_qa.gd"

func _walk_corridor(world:Node3D) -> void:
	await super._walk_corridor(world)
	var rows := []
	for asset:StringName in [&"kaykit.rock.03",&"kaykit.rock.05",&"kaykit.grass.04"]:
		var nearest := INF
		var chosen := Transform3D.IDENTITY
		var bounds := AABB()
		var count := 0
		for node:MultiMeshInstance3D in world.find_children(String(asset).replace(".","_")+"_*","MultiMeshInstance3D",true,false):
			if node.get_parent().name!=&"Dressing":continue
			for i in node.multimesh.instance_count:
				count+=1
				var pose:=node.global_transform*node.multimesh.get_instance_transform(i)
				var distance:=pose.origin.distance_to(_spot[2])
				if distance<nearest:
					nearest=distance
					chosen=pose
					bounds=pose*node.multimesh.mesh.get_aabb()
		assert(count>0,"The fresh worker/queue must publish %s"%asset)
		var centre:=bounds.get_center()
		_character.visible=false
		for angle in [0,90,180]:
			_camera.fov=55
			_camera.global_position=centre+Vector3(12,8,14).rotated(Vector3.UP,deg_to_rad(angle))
			_camera.look_at(centre)
			await _shot(String(asset).replace(".","_")+"_%d"%angle)
		rows.append({"asset":asset,"count":count,"nearest":nearest,"transform":str(chosen),"bounds":str(bounds)})
	_character.visible=true
	print("CLIFF_GAME_DRESSING ",JSON.stringify(rows))
	FileAccess.open(_output_dir.path_join("dressing.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
