extends SceneTree

func _init() -> void:
	var terraces := preload("res://scripts/terrain/field/CliffTerraces.gd")
	var started := Time.get_ticks_usec()
	terraces.prepare()
	var prepare_usec := Time.get_ticks_usec() - started
	var rows := []
	for asset: StringName in terraces._definitions:
		var definition: Dictionary = terraces._definitions[asset]
		var physical: PackedVector3Array = definition.collision_faces
		var native: PackedVector3Array = definition.faces
		var box: AABB = definition.bounds
		var physical_box := AABB(physical[0], Vector3.ZERO)
		for point in physical: physical_box = physical_box.expand(point)
		rows.append({"asset":asset,"native_triangles":native.size()/3,"physical_triangles":physical.size()/3,
			"native_bounds":str(box),"physical_bounds":str(physical_box),
			"profile":"native mesh" if asset == terraces.ROCK else "native flat cap and vertical terrain sides"})
	var output := {"prepare_usec":prepare_usec,"assets":rows,"shape":"ConcavePolygonShape3D; one aggregate static shape per nonempty chunk"}
	FileAccess.open("res://docs/qa/2026-09-13-manual/23-terraces/collision-inventory.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	print(JSON.stringify(output))
	quit()
