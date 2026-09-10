extends GutTest

func test_reported_retained_facade_panels_stay_inside_their_shared_corner() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var fabric := frozen.spatial(frozen.read("res://tests/fixtures/september7-manual-source.txt"),program).compiled_fabric_cache()
	var payload := SettlementFabricAssembler.structural_support_payload(fabric)
	var wanted := {&"maze-stone/-1/2/0/1":1.0, &"maze-stone/-1/2/0/2":-1.0, &"maze-stone/-4/2/2/2":1.0}
	var checked := 0
	for asset: StringName in payload.batches:
		var batch: Dictionary = payload.batches[asset]
		for i in batch.ids.size():
			if not wanted.has(batch.ids[i]): continue
			var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
			var excess := -INF
			for piece: EnvironmentVisualPiece in visual.pieces:
				for v: Vector3 in piece.local_transform * piece.mesh.get_faces():
					excess = maxf(excess,float(wanted[batch.ids[i]])*v.x-v.z-(0.75-SettlementFabricAssembler.FACADE_FRONT_DEPTH))
			# The baked compressed vertex stream quantizes the cut by up to 0.1 mm.
			assert_lte(excess,0.0001,"%s exposes its square end beyond the shared corner by %.4f m" % [batch.ids[i],excess])
			checked += 1
	assert_eq(checked,3,"The timber and mixed masonry photo corners must participate")

func test_corner_ownership_rotates_and_leaves_straight_runs_unchanged() -> void:
	for side in 4:
		var key := Vector4i(4,3,7,side)
		var normal: Vector3i = SettlementFabricAssembler.STONE_FACE_DIRECTIONS[side]
		var tangent := Vector3i(normal.z,0,-normal.x)
		var treatments := {key:SettlementFabricAssembler.SkinTreatment.FACADE}
		assert_eq(SettlementFabricAssembler.maze_facade_corner_mask(key,treatments),0)
		for end in 2:
			var other_normal := tangent * (-1 if end == 0 else 1)
			var other := Vector4i(key.x,key.y,key.z,SettlementFabricAssembler.STONE_FACE_DIRECTIONS.find(other_normal))
			var pair := treatments.duplicate()
			pair[other] = SettlementFabricAssembler.SkinTreatment.FACADE
			assert_eq(SettlementFabricAssembler.maze_facade_corner_mask(key,pair),1<<end)
			pair.erase(other)
			other.y += 1
			pair[other] = SettlementFabricAssembler.SkinTreatment.FACADE
			assert_eq(SettlementFabricAssembler.maze_facade_corner_mask(key,pair),0,
				"A mismatched course cannot withdraw this wall's end")

func test_baked_corners_retain_the_original_visual_envelope() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var assets := {}
	for pool: Array[StringName] in [SettlementFabricProgram.WOOD_CELL_FACADE_BLUE,
			SettlementFabricProgram.WOOD_CELL_FACADE_ORANGE,SettlementFabricProgram.WOOD_CELL_FACADE_AMBER]:
		for base: StringName in pool: assets[base] = true
	for base: StringName in assets:
		var stock := catalog.descriptor(base).measured_aabb.grow(0.0002)
		for mask in range(1,4):
			var asset := StringName("%s.retaining_miter%d" % [base,mask])
			var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
			var contained := true
			for piece: EnvironmentVisualPiece in visual.pieces:
				for v: Vector3 in piece.local_transform * piece.mesh.get_faces():
					contained = contained and stock.has_point(v)
			assert_true(contained,"%s must remain inside the reserved stock" % asset)

func test_photo14_room_panels_have_referenced_faces_closing_both_miters() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for base: StringName in [&"sfv.fabric.wall.wood.window.004.mirror_x",&"sfv.fabric.wall.wood.window.040"]:
		var front := catalog.descriptor(base).measured_aabb.end.z
		var visual: EnvironmentVisual = load(catalog.descriptor(StringName("%s.miter3.course_open" % base)).visual_path)
		for end in 2:
			var plane := Plane(Vector3(-1 if end==0 else 1,0,-1),1.5-front)
			var caps := 0
			for piece: EnvironmentVisualPiece in visual.pieces:
				var faces := piece.local_transform * piece.mesh.get_faces()
				for k in range(0,faces.size(),3):
					if absf(plane.normal.dot(faces[k])-plane.d)<0.0002 \
							and absf(plane.normal.dot(faces[k+1])-plane.d)<0.0002 \
							and absf(plane.normal.dot(faces[k+2])-plane.d)<0.0002:
						caps += 1
			assert_gt(caps,0,"%s end %d must close the cut with referenced triangles" % [base,end])

func test_photo14_stone_to_room_joint_blocks_the_exposed_party_wall_sliver() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var fabric := frozen.spatial(frozen.read("res://tests/fixtures/september8-night-center-source.txt"),program).compiled_fabric_cache()
	var payload := SettlementFabricAssembler.structural_support_payload(fabric)
	var town := Transform3D(Basis.from_scale(Vector3.ONE*2),Vector3(352.5,20.08,498.5))
	var origin := Vector3(355.5507,34.1,510.0482)
	var exposed_plaster := Vector3(357.3628,33.08165,501.0842)
	var ray := (exposed_plaster-origin).normalized()
	var nearest := INF
	for asset: StringName in payload.batches:
		var batch: Dictionary = payload.batches[asset]
		var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
		for pose: Transform3D in batch.transforms:
			var world_pose := town*pose
			if (world_pose*catalog.descriptor(asset).measured_aabb).intersects_ray(origin,ray)==null: continue
			for piece: EnvironmentVisualPiece in visual.pieces:
				var faces := world_pose*piece.local_transform*piece.mesh.get_faces()
				for k in range(0,faces.size(),3):
					var hit = Geometry3D.ray_intersects_triangle(origin,ray,faces[k],faces[k+1],faces[k+2])
					if hit != null: nearest = minf(nearest,origin.distance_to(hit))
	assert_lt(nearest,origin.distance_to(exposed_plaster)-0.1,
		"The material junction must close before the photographed ray reaches the room's buried side wall")

func test_material_seam_posts_stay_in_the_two_occupied_cells_in_every_orientation() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var post: EnvironmentVisual = load(catalog.descriptor(SettlementFabricAssembler.TIMBER_SUPPORT).visual_path)
	for outward: Vector3i in SettlementFabricAssembler.FACE_DIRECTIONS:
		var along := Vector3i(outward.z,0,-outward.x)
		var face := Vector4i(0,0,0,SettlementFabricAssembler.STONE_FACE_DIRECTIONS.find(outward))
		var payload := SettlementFabricAssembler.masonry_room_seams({Vector3i.ZERO:true},{along:true},{},
			{face:SettlementFabricAssembler.SkinTreatment.MASONRY})
		var batch: Dictionary = payload.batches.get(SettlementFabricAssembler.TIMBER_SUPPORT,{})
		assert_false(batch.is_empty())
		if batch.is_empty(): continue
		assert_eq(batch.transforms.size(),1)
		var first := AABB(Vector3(-0.75,0,-0.75),Vector3(1.5,1.5,1.5))
		var second := AABB(first.position+Vector3(along)*1.5,first.size)
		var inside := true
		for piece: EnvironmentVisualPiece in post.pieces:
			for v: Vector3 in (batch.transforms[0] as Transform3D)*piece.local_transform*piece.mesh.get_faces():
				inside = inside and (first.grow(0.0002).has_point(v) or second.grow(0.0002).has_point(v))
		assert_true(inside,"No shared post may protrude into public air")
