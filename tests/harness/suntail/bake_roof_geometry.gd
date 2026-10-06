extends SceneTree
## Rebuild worker-side triangle data from the catalog after changing kit assets.
func _init() -> void:
	var kit := SuntailBuildingKit.create()
	if OS.get_cmdline_user_args().has("--pure-village"):
		kit = preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").roof_study()
	if OS.get_cmdline_user_args().has("--tower"):
		kit = BuildingKit.new()
		kit.roles[&"roof.tower"] = [&"pure_village.tower.roof"]
		kit.roof_geometry_path = "res://terrain/environment/geometry/pure_village_tower_roof.bin"
	if OS.get_cmdline_user_args().has("--roof-turret"):
		kit = BuildingKit.new()
		kit.roles[&"roof.tower"] = [&"pure_village.roof_turret.middle", &"pure_village.roof_turret.roof"]
		kit.roof_geometry_path = "res://terrain/environment/geometry/pure_village_roof_turret.bin"
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var data := {}
	var families: Array[BuildingKit] = [kit]
	if OS.get_cmdline_user_args().has("--pure-village") and not OS.get_cmdline_user_args().has("--tower"):
		# The worker cache is shared by all style seeds, including arch and
		# rectangular attic windows. Bake both role selections together.
		families.append(preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").roof_study(1))
		for palette: StringName in [&"wood_red", &"wood_blue", &"sage"]:
			var variant := preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").roof_study()
			preload("res://scripts/terrain/features/villages/kit/TownRoofPalette.gd").apply(variant,palette)
			families.append(variant)
	for family: BuildingKit in families:
		for role: StringName in family.roles:
			if not (String(role).begins_with("roof.") or String(role).begins_with("gable.") or String(role).begins_with("trim.") or String(role).begins_with("chimney.")):
				continue
			for id: StringName in family.roles[role]:
				if data.has(id): continue
				var visual := cache.visual(id)
				var surfaces: Array = []
				for pi in visual.pieces.size():
					var piece: EnvironmentVisualPiece = visual.pieces[pi]
					for si in piece.mesh.get_surface_count():
						var a := piece.mesh.surface_get_arrays(si)
						var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
						var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
						for i in vertices.size():
							vertices[i] = piece.local_transform * vertices[i]
							normals[i] = (piece.local_transform.basis.inverse().transposed() * normals[i]).normalized()
						var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
						if indices.is_empty():
							for i in vertices.size(): indices.append(i)
						surfaces.append({"vertices": vertices, "normals": normals, "uvs": a[Mesh.ARRAY_TEX_UV], "indices": indices, "piece": pi, "surface": si})
				data[id] = surfaces
	var file := FileAccess.open(kit.roof_geometry_path, FileAccess.WRITE)
	file.store_var(data)
	print("BAKED_ROOFS ", data.size())
	quit()
