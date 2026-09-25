extends GutTest

func test_t_valley_has_actual_roof_triangles_across_the_complete_join() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	for configuration: Array in [[&"building", 0], [&"long", -2], [&"long", 2]]:
		for theme: StringName in [&"blue", &"orange"]:
			for side in [FabricRoofTopologyPlan.Side.EAVE_NEGATIVE,
					FabricRoofTopologyPlan.Side.EAVE_POSITIVE]:
				var recipe := program.recipe(FabricRoofJunctionModuleTable.bisected_valley_recipe_id(
					configuration[0], theme, configuration[1], side))
				var triangles := PackedVector3Array()
				for placement: Dictionary in recipe.placements:
					var visual: EnvironmentVisual = load(catalog.descriptor(placement.asset_id).visual_path)
					for piece: EnvironmentVisualPiece in visual.pieces:
						for surface in piece.mesh.get_surface_count():
							var arrays := piece.mesh.surface_get_arrays(surface)
							var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
							var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
							for index in (vertices.size() if indices.is_empty() else indices.size()):
								triangles.append((placement.transform as Transform3D) * piece.local_transform * vertices[index if indices.is_empty() else indices[index]])
				var uncovered := 0
				for x in range(1, 30):
					for z in range(-29, 30):
						var sign_value := -1.0 if side == FabricRoofTopologyPlan.Side.EAVE_NEGATIVE else 1.0
						var point := Vector3(-0.75 + sign_value * x * 0.1, 8.0, -0.75 + float(configuration[1]) * 0.75 + z * 0.1)
						var hit := false
						for index in range(0, triangles.size(), 3):
							# Native float32 half-roofs meet at a shared ridge. A ten
							# micrometre edge tolerance avoids classifying roundoff on
							# exactly that triangle boundary as an open weather face.
							for delta in [Vector3.ZERO, Vector3(0,0,0.00001), Vector3(0,0,-0.00001)]:
								if Geometry3D.ray_intersects_triangle(point + delta, Vector3.DOWN,
										triangles[index], triangles[index+1], triangles[index+2]) != null:
									hit = true
									break
							if hit: break
						if not hit:
							uncovered += 1
				assert_eq(uncovered, 0, "%s side %s: roof pixels need real weather faces" % [theme, side])
