extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var helper = load("res://tests/test_pure_village_cross_roof.gd").new()
	var wall: Node3D = (
		load("res://assets/PureVillage/Models/Architecture/Wall_Peak_30x30_1.glb").instantiate()
	)
	root.add_child(wall)
	var triangles: PackedVector3Array = helper._triangles(wall, false)
	var window: Node3D = (
		load("res://assets/PureVillage/Models/Architecture/WindowSolo_6.glb").instantiate()
	)
	root.add_child(window)
	var points := {}
	for mesh: MeshInstance3D in window.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			if not mesh.get_active_material(surface).resource_name.to_lower().contains("glass_out"):
				continue
			var a := mesh.mesh.surface_get_arrays(surface)
			for index in a[Mesh.ARRAY_INDEX]:
				points[mesh.global_transform * a[Mesh.ARRAY_VERTEX][index]] = true
	print("GLASS_POINTS ", points.size())
	for scale_value in [.77019, 1.0]:
		for y in [.7, .95, 1.2, 1.45, 1.7]:
			for z in [.2, .25, .3, .35]:
				var blocked := 0
				for point: Vector3 in points:
					var at: Vector3 = point * scale_value + Vector3(0, y, z)
					if helper._hit(triangles, at + Vector3.BACK * .005, at + Vector3.BACK * 2):
						blocked += 1
				print("FIT ", scale_value, " ", y, " ", z, " blocked=", blocked)
	helper.free()
	quit()
