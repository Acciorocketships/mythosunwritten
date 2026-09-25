extends GutTest

var _catalog: EnvironmentCatalog
var _program: SettlementFabricProgram

func test_compact_shed_rear_join_is_buried_in_actual_host_triangles() -> void:
	_check_fit(&"roof.tower.orange.dormer.left",true,false)

func test_wide_shed_keeps_the_complete_glazed_opening_above_the_roof() -> void:
	_check_fit(&"roof.square.orange.dormer.right",false,true)

func test_all_selected_shed_recipe_forms_close_the_back_and_expose_the_window() -> void:
	_catalog = EnvironmentCatalog.load_default()
	_program = SettlementFabricProgram.compile(_catalog)
	for recipe: FabricRecipe in _program.recipes():
		if recipe.has_tag(&"dormer") and recipe.has_tag(&"authored_shed_dormer"):
			_check_fit(recipe.recipe_id,true,true)

func test_fitted_shed_preserves_native_front_width_height_uvs_and_collision() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for asset: StringName in [SettlementFabricProgram.ROOF_WINDOW_03,SettlementFabricProgram.ROOF_WINDOW_04]:
		var source := load(catalog.descriptor(asset).visual_path) as EnvironmentVisual
		var fitted := load(catalog.descriptor(StringName(str(asset)+".deep")).visual_path) as EnvironmentVisual
		assert_eq(fitted.pieces.size(),source.pieces.size())
		var compared := 0
		for i in source.pieces.size():
			var a := source.pieces[i].mesh
			var b := fitted.pieces[i].mesh
			assert_eq(b.get_surface_count(),a.get_surface_count())
			for surface in a.get_surface_count():
				var aa := a.surface_get_arrays(surface)
				var bb := b.surface_get_arrays(surface)
				var av: PackedVector3Array = aa[Mesh.ARRAY_VERTEX]
				var bv: PackedVector3Array = bb[Mesh.ARRAY_VERTEX]
				assert_eq(bv.size(),av.size())
				assert_true(aa[Mesh.ARRAY_INDEX]==bb[Mesh.ARRAY_INDEX],"Every original face survives")
				assert_true(aa[Mesh.ARRAY_TEX_UV]==bb[Mesh.ARRAY_TEX_UV],"Authored UVs survive")
				for vertex in av.size():
					assert_almost_eq(bv[vertex].x,av[vertex].x,.000001)
					assert_almost_eq(bv[vertex].y,av[vertex].y,.000001)
					if av[vertex].z >= .5:
						assert_true(bv[vertex].is_equal_approx(av[vertex]),"Complete native window/front course is unchanged")
						compared += 1
			var visual_faces := EnvironmentBakeGeometry.triangle_faces(b)
			var collision_faces := (fitted.collisions[i].shape as ConcavePolygonShape3D).get_faces()
			assert_true(visual_faces==collision_faces,"Fitted stock keeps exact full mesh collision")
		assert_gt(compared,100)

func _check_fit(id: StringName, check_back: bool, check_glass: bool) -> void:
	if _catalog == null: _catalog = EnvironmentCatalog.load_default()
	if _program == null: _program = SettlementFabricProgram.compile(_catalog)
	var catalog := _catalog
	var recipe := _program.recipe(id)
	var host := PackedVector3Array()
	var dormers := []
	for placement: Dictionary in recipe.placements:
		if str(placement.id).contains("dormer"):
			dormers.append(placement)
			continue
		var visual := load(catalog.descriptor(placement.asset_id).visual_path) as EnvironmentVisual
		for piece: EnvironmentVisualPiece in visual.pieces:
			host.append_array(EnvironmentBakeGeometry.triangle_faces(piece.mesh,placement.transform*piece.local_transform))
	for placement: Dictionary in dormers:
		var visual := load(catalog.descriptor(placement.asset_id).visual_path) as EnvironmentVisual
		var rear := PackedVector3Array()
		var panes := PackedVector3Array()
		for piece: EnvironmentVisualPiece in visual.pieces:
			for surface in piece.mesh.get_surface_count():
				var vertices: PackedVector3Array = piece.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				var is_glass := piece.mesh.surface_get_material(surface).resource_name == "SFV_GLOW_WINDOW"
				for v: Vector3 in vertices:
					if is_glass: panes.append(piece.local_transform*v)
					else: rear.append(piece.local_transform*v)
		var rear_z := INF
		for p: Vector3 in rear: rear_z = minf(rear_z,p.z)
		var back_gap := -INF
		var glass_burial := -INF
		var rear_samples := 0
		for p: Vector3 in rear:
			# The complete back edge, including its raised timber end tips.
			if p.z > rear_z+.16: continue
			var point: Vector3 = placement.transform*p
			back_gap = maxf(back_gap,point.y-_height(host,point))
			rear_samples += 1
		for p: Vector3 in panes:
			var point: Vector3 = placement.transform*p
			glass_burial = maxf(glass_burial,_height(host,point)-point.y)
		assert_gt(rear_samples,0)
		assert_gt(panes.size(),0)
		if check_back: assert_lt(back_gap,-.02,"%s: exposed rear gap %.4f m"%[id,back_gap])
		if check_glass: assert_lt(glass_burial,-.02,"%s: roof covers pane by %.4f m"%[id,glass_burial])

func _height(faces: PackedVector3Array, p: Vector3) -> float:
	var top := -INF
	for i in range(0,faces.size(),3):
		var hit = Geometry3D.segment_intersects_triangle(p+Vector3.UP*10,p-Vector3.UP*10,faces[i],faces[i+1],faces[i+2])
		if hit != null: top = maxf(top,hit.y)
	return top
