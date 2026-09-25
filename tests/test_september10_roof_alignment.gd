extends GutTest

func test_terminal_gables_close_above_the_actual_facade_plane() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for family in ["orange", "slate"]:
		for side in ["rear", "front"]:
			var source_number := "03" if (family=="orange")== (side=="rear") else "06"
			for ending in ["", ".end"]:
				var asset := StringName("lpfv.fabric.roof.compact.%s.%s.%s%s.tight" % [family,source_number,side,ending])
				var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
				var faces := PackedVector3Array()
				for piece: EnvironmentVisualPiece in visual.pieces:
					faces.append_array(EnvironmentBakeGeometry.triangle_faces(piece.mesh,piece.local_transform))
				var direction := -1.0 if side=="rear" else 1.0
				for x in [-0.5,0.0,0.5]:
					for y in [0.4,0.8,1.2]:
						var closed := false
						for i in range(0,faces.size(),3):
							if Geometry3D.segment_intersects_triangle(Vector3(x,y,direction*1.501),Vector3(x,y,direction*1.449),faces[i],faces[i+1],faces[i+2])!=null:
								closed=true
								break
						assert_true(closed,"%s: native gable must reach the wall's outer 5 cm at %.1f/%.1f" % [asset,x,y])

func test_joined_partial_crown_keeps_its_original_end_boundaries() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var plan := frozen.spatial(frozen.read("res://tests/fixtures/september10-skywalk-source.txt"),program).compiled_fabric_cache()
	var found := 0
	for entry: Dictionary in plan.expanded_placements():
		if not String(entry.stable_id).begins_with("spatial.roof.spatial.parcel.maze.house.001.part00.room00.tile00/continuous-roof/"): continue
		found+=1
		var visual: EnvironmentVisual = load(catalog.descriptor(entry.asset_id).visual_path)
		var low := INF
		var high := -INF
		for piece: EnvironmentVisualPiece in visual.pieces:
			for vertex: Vector3 in EnvironmentBakeGeometry.triangle_faces(piece.mesh,entry.transform * piece.local_transform):
				low=minf(low,vertex.z)
				high=maxf(high,vertex.z)
		assert_gte(low,-0.75001,"The photographed half-crown's joined roof may not invent an outward end")
		assert_lte(high,2.25001,"The photographed half-crown's joined roof may not invent an outward end")
	assert_eq(found,3)

func test_bounded_continuous_gables_reach_the_facade_without_an_inset_shelf() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for family in ["orange","slate"]:
		for side in ["start","end"]:
			var asset := StringName("lpfv.fabric.roof.compact.%s.03.run.%s.tight.flush" % [family,side])
			var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
			var faces := EnvironmentBakeGeometry.triangle_faces(visual.pieces[0].mesh)
			var direction := -1.0 if side=="start" else 1.0
			for x in [-0.5,0.0,0.5]:
				var closed := false
				for i in range(0,faces.size(),3):
					if Geometry3D.segment_intersects_triangle(Vector3(x,0.8,direction*1.501),Vector3(x,0.8,direction*1.449),faces[i],faces[i+1],faces[i+2])!=null:
						closed=true
						break
				assert_true(closed,"%s must retain its gable at the supporting wall" % asset)
