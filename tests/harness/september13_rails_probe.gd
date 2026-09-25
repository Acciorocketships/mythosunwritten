extends SceneTree

func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/04-path/source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	var town := Transform3D(Basis.from_scale(Vector3(-2,2,-2)),Vector3(-214.5,8.08,-944.5))
	var footprints := SettlementFabricAssembler.maze_module_footprints(fabric)
	var report := {"transitions":[],"walls":[]}
	for transition: WarrenVolumeTransition in spatial.source_volume.transitions:
		if not transition.is_vertical(): continue
		var ends := WarrenTransitionSurfaceBuilder._span_endpoints(transition)
		var a: Vector3 = town*ends.start
		var b: Vector3 = town*ends.end
		if a.distance_to(Vector3(-233.4,12.4,-954.4))<15:
			report.transitions.append({"id":str(transition.stable_id),"from":str(a),"to":str(b)})
	for mesh: Dictionary in fabric.surface_plan.mesh_payloads:
		var points: PackedVector3Array = mesh.vertices
		for i in range(0,points.size(),24):
			if i+24>points.size(): continue
			var box := AABB(town*points[i],Vector3.ZERO)
			for j in 24: box = box.expand(town*points[i+j])
			var p := box.get_center()
			if p.x > -232.5 and p.x < -229.5 and p.z > -961 and p.z < -954 and p.y>12 and p.y<17:
				print("MEMBER ",mesh.stable_id," ",i," ",box)
	for index in footprints.boxes.size():
		var box: AABB = town*footprints.boxes[index]
		if box.intersects(AABB(Vector3(-232,12,-961),Vector3(3,5,7))):
			report.walls.append({"asset":str(footprints.assets[index]),"box":str(box)})
	print("RAILS ",JSON.stringify(report,"  "))
	quit()
