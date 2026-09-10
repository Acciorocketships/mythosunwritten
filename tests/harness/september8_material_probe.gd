extends SceneTree
func _init() -> void:
	var catalog:=EnvironmentCatalog.load_default()
	for asset:StringName in [SettlementFabricProgram.ROCK_PLAIN,SettlementFabricAssembler.MAZE_STONE_MODULE]:
		var visual:EnvironmentVisual=load(catalog.descriptor(asset).visual_path)
		var heights:Dictionary={}
		for piece:EnvironmentVisualPiece in visual.pieces:
			for surface in piece.mesh.get_surface_count():
				var material:=piece.mesh.surface_get_material(surface) as StandardMaterial3D
				var image:=material.albedo_texture.get_image()
				if image.is_compressed():image.decompress()
				var arrays:=piece.mesh.surface_get_arrays(surface)
				var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
				var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				for i in uvs.size():
					var uv:=uvs[i]
					var color:=image.get_pixel(clampi(int(uv.x*image.get_width()),0,image.get_width()-1),clampi(int(uv.y*image.get_height()),0,image.get_height()-1))
					if color.r>color.b*1.3 and color.g>color.b*1.15:
						var h:=roundi(vertices[i].y*1000)
						heights[h]=int(heights.get(h,0))+1
		var keys:=heights.keys();keys.sort()
		print(asset," WARM ",keys)
	quit()
