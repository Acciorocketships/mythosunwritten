extends GutTest
const PURE := preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")

func test_native_end_courses_face_outward_on_both_axes() -> void:
	var kit := PURE.roof_study()
	for axis in 2:
		for depth in [4,5]:
			var mass := BuildingMass.new()
			var wing := mass.add_roof(Rect2i(0,0,6,depth) if axis == 0 else Rect2i(0,0,depth,6),axis,4,&"red")
			wing.ridge_peaks = false
			var placements := BuildingKitAssembler.new(kit).assemble(mass)
			var ends := 0
			for p: Dictionary in placements:
				var role := String(p.role)
				if not (role.begins_with("roof.") or role.begins_with("trim.ridge")) or not (role.ends_with(".start") or role.ends_with(".end")): continue
				var pose: Transform3D = p.transform
				var along := Vector3.RIGHT if axis == 0 else Vector3.BACK
				var centre := along * 6.0
				var toward_inside := centre - pose.origin
				# Native Start pieces have the closed end at -X; End at +X.
				var inward := pose.basis.x if role.ends_with(".start") else -pose.basis.x
				assert_gt(inward.dot(toward_inside),0.0,"native closure faces outward: %s" % role)
				ends += 1
			assert_gte(ends,8,"both sides and courses use native edge closures")

func test_native_roof_roles_have_measured_mesh_and_collision() -> void:
	var kit := PURE.roof_study()
	var catalog := EnvironmentCatalog.load_default()
	var geometry: Dictionary = FileAccess.open(kit.roof_geometry_path,FileAccess.READ).get_var()
	var checked := {}
	for id: StringName in kit.all_asset_ids():
		if not String(id).begins_with("pure_village.roof.") and not String(id).begins_with("pure_village.gable."): continue
		var descriptor := catalog.descriptor(id)
		assert_not_null(descriptor)
		if descriptor == null: continue
		assert_gt(descriptor.collision_piece_count,0,String(id))
		assert_true(descriptor.measured_aabb.has_volume(),String(id))
		assert_true(geometry.has(id),"worker-side roof union includes %s" % id)
		checked[id] = true
	assert_eq(checked.size(),17)

func test_native_caps_supplement_full_bays_without_roof_holes() -> void:
	var kit := PURE.roof_study()
	var geometry: Dictionary = FileAccess.open(kit.roof_geometry_path,FileAccess.READ).get_var()
	for axis in 2:
		for depth in [4,5]:
			var mass := BuildingMass.new()
			mass.add_roof(Rect2i(0,0,4,depth) if axis == 0 else Rect2i(0,0,depth,4),axis,0,&"red")
			var points: Array[Vector3] = []
			for i in 31:
				for j in depth * 4:
					var u := 0.125 + float(i)*0.25
					var v := 0.25 + float(j)*0.5
					points.append(Vector3(u,20,v) if axis == 0 else Vector3(v,20,u))
			kit.roof_edge_caps = true
			var correct := BuildingKitAssembler.new(kit).assemble(mass)
			assert_eq(_roof_misses(correct,geometry,points),0,
				"continuous tile surface across axis %d, depth %d" % [axis,depth])
			# Reproduce the rejected assembly: replacing complete boundary strips
			# with narrow caps left holes before the first regular bay.
			kit.roof_edge_caps = false
			var replaced := BuildingKitAssembler.new(kit).assemble(mass)
			assert_gt(_roof_misses(replaced,geometry,points),0,"the fixture exposes the old gaps")

func test_mixed_roof_union_cuts_both_families_and_keeps_collision() -> void:
	var union_script := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
	var base := SuntailBuildingKit.create()
	var pure := PURE.roof_study()
	var roofs: Array[Dictionary] = []
	var placements: Array[Dictionary] = []
	for i in 2:
		var mass := BuildingMass.new()
		mass.stable_id = StringName("mixed_%d" % i)
		var wing := mass.add_roof(Rect2i(i * 6,0,4,4),0,0,&"red")
		wing.union_index = i
		roofs.append(wing)
		placements.append_array(BuildingKitAssembler.new(base if i == 0 else pure).assemble(mass))
	# One continuous public strip crosses both eaves and roof slopes.
	var box := AABB(Vector3(-2,-2,1),Vector3(26,15,2))
	var wall := union_script.box_volume(box)
	wall.open = true
	var kits := {1:pure}
	var ctx := union_script.prepare(roofs,[wall],base,kits)
	assert_true(ctx.data.has(&"pure_village.roof.eave"),"native triangles cannot silently bypass the union")
	var payload := EnvironmentInstancePayload.new()
	union_script.append(placements,roofs,[wall],base,Transform3D.IDENTITY,payload,kits)
	var families := {}
	var intrusions := 0
	var collision_errors := 0
	for mesh: Dictionary in payload.surface_meshes:
		families[String(mesh.material_asset_id).get_slice(".",0)] = true
		for i in range(0,mesh.indices.size(),3):
			var centre := Vector3.ZERO
			for j in 3:
				var vertex: Vector3 = mesh.vertices[mesh.indices[i+j]]
				centre += vertex / 3.0
				collision_errors += int(not vertex.is_equal_approx(mesh.collision_faces[i+j]))
			intrusions += int(box.grow(-0.0002).has_point(centre))
	assert_true(families.has("suntail"),"Suntail eave is cut")
	assert_true(families.has("pure_village"),"Pure Village eave is cut")
	assert_eq(intrusions,0,"both families clear the public strip")
	assert_eq(collision_errors,0,"trimmed render and collision agree")
	assert_true(payload.validate())

func test_native_peak_has_no_narrow_slots() -> void:
	var kit := PURE.roof_study()
	var geometry: Dictionary = FileAccess.open(kit.roof_geometry_path,FileAccess.READ).get_var()
	for depth in [4,5]:
		var mass := BuildingMass.new()
		mass.add_roof(Rect2i(0,0,4,depth),0,0,&"red")
		var points: Array[Vector3] = []
		for u in [0.53,2.53,4.53,6.53]:
			for j in depth * 200:
				points.append(Vector3(u,20,float(j)*0.01+0.003))
		assert_eq(_roof_misses(BuildingKitAssembler.new(kit).assemble(mass),geometry,points),0,
			"centimetre sampling across all courses, depth %d" % depth)

func test_tight_eaves_keep_full_roof_courses_closed_on_both_axes() -> void:
	var kit := PURE.roof_study()
	var geometry: Dictionary = FileAccess.open(kit.roof_geometry_path,FileAccess.READ).get_var()
	for axis in 2:
		for depth in [4,5]:
			var mass := BuildingMass.new()
			var wing := mass.add_roof(Rect2i(0,0,4,depth) if axis == 0 else Rect2i(0,0,depth,4),axis,0,&"red")
			wing.tight_eave = true
			var points: Array[Vector3] = []
			for i in 32:
				for j in depth*8:
					var u := float(i)*0.25+0.013
					var v := float(j)*0.25+0.017
					points.append(Vector3(u,20,v) if axis == 0 else Vector3(v,20,u))
			assert_eq(_roof_misses(BuildingKitAssembler.new(kit).assemble(mass),geometry,points),0)

func test_native_dormers_keep_windows_and_close_their_roof_bays() -> void:
	var kit := PURE.roof_study()
	for tight in [false,true]:
		var mass := BuildingMass.new()
		var wing := mass.add_roof(Rect2i(0,0,4,4),0,0,&"red")
		wing.tight_eave = tight
		wing.dormers = {Vector2i(0,1):true,Vector2i(1,2):true}
		var placements := BuildingKitAssembler.new(kit).assemble(mass)
		var count := 0
		for p: Dictionary in placements:
			if String(p.role).ends_with("eave_tight_dormer" if tight else "eave_dormer"):
				assert_eq(p.asset_id,(&"pure_village.roof.dormer_tight" if tight else &"pure_village.roof.dormer"),"a requested dormer is not a plain roof")
				count += 1
		assert_eq(count,2)
		var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
		var visual := cache.visual((&"pure_village.roof.dormer_tight" if tight else &"pure_village.roof.dormer"))
		var glass := false
		for piece in visual.pieces:
			for i in piece.mesh.get_surface_count():
				glass = glass or piece.mesh.surface_get_material(i).resource_name == "Glass_Out"
		assert_true(glass,"native glazed opening survives the adapter")
		var geometry: Dictionary = FileAccess.open(kit.roof_geometry_path,FileAccess.READ).get_var()
		var points: Array[Vector3] = []
		for x in 32:
			for z in 32:
				points.append(Vector3(float(x)*0.25+0.013,20,float(z)*0.25+0.017))
		assert_eq(_roof_misses(placements,geometry,points),0,"dormers and plain bays make one closed roof")

func _roof_misses(placements: Array[Dictionary], geometry: Dictionary,
		points: Array[Vector3], ray_direction := Vector3.DOWN, union_context: Dictionary = {}) -> int:
	var pieces: Array[Dictionary] = []
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	for p: Dictionary in placements:
		if not String(p.role).begins_with("roof.") and not String(p.role).begins_with("trim.ridge"): continue
		var visual := cache.visual(p.asset_id)
		var realized := {} if union_context.is_empty() else preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd").realize(p,union_context)
		for si in geometry[p.asset_id].size():
			var source: Dictionary = geometry[p.asset_id][si]
			var surface: Dictionary = source if realized.is_empty() else realized.meshes[si]
			if surface.vertices.is_empty(): continue
			var material := visual.pieces[int(source.piece)].mesh.surface_get_material(int(source.surface))
			if material.resource_name not in ["RoofTiles", "RoofTopTiles"]: continue
			var bounds := AABB(surface.vertices[0],Vector3.ZERO)
			for vertex: Vector3 in surface.vertices: bounds = bounds.expand(vertex)
			pieces.append({"inverse":(p.transform as Transform3D).affine_inverse() if realized.is_empty() else Transform3D.IDENTITY,
				"bounds":bounds,"surface":surface})
	var misses := 0
	for point: Vector3 in points:
		var hit := false
		for piece: Dictionary in pieces:
			var local: Vector3 = piece.inverse * point
			var box: AABB = piece.bounds
			var direction: Vector3 = (piece.inverse as Transform3D).basis * ray_direction
			if box.intersects_ray(local,direction) == null: continue
			var surface: Dictionary = piece.surface
			var vertices: PackedVector3Array = surface.vertices
			var indices: PackedInt32Array = surface.indices
			for t in range(0,indices.size(),3):
				var normal: Vector3 = surface.normals[indices[t]] + surface.normals[indices[t+1]] + surface.normals[indices[t+2]]
				if normal.dot(direction) >= 0: continue
				if Geometry3D.ray_intersects_triangle(local,direction,vertices[indices[t]],vertices[indices[t+1]],vertices[indices[t+2]]) != null:
					hit = true
					break
			if hit: break
		misses += int(not hit)
	return misses

func test_short_verges_keep_whole_ridge_caps_and_closed_course_seams() -> void:
	var union_script := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
	for axis in 2:
		var kit := PURE.roof_study()
		var mass := BuildingMass.new()
		var wing := mass.add_roof(Rect2i(0,0,4,4),axis,0,&"red")
		wing.union_index = 0
		wing.verge_min = kit.wall_face
		wing.verge_max = kit.wall_face
		var ctx := union_script.prepare([wing],[],kit)
		var parts := BuildingKitAssembler.new(kit).assemble(mass)
		var caps := 0
		for p: Dictionary in parts:
			if p.role not in [&"trim.ridge.start",&"trim.ridge.end"]: continue
			caps += 1
			assert_true(union_script.realize(p,ctx).is_empty(),"the fitted cap survives whole, not as a sliced cross-section")
		assert_eq(caps,2)
		var points: Array[Vector3] = []
		for i in 411:
			for v in [3.85,4.0,4.15]:
				var u := -0.1+float(i)*0.02
				points.append(Vector3(u,20,v) if axis==0 else Vector3(v,20,u))
		assert_eq(_roof_misses(parts,ctx.data,points,Vector3.DOWN,ctx),0,"finished cap/body seams stay closed")
		kit.ridge_cap_reach = Vector2.ZERO
		var cut := 0
		for p: Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
			if p.role in [&"trim.ridge.start",&"trim.ridge.end"] and not union_script.realize(p,ctx).is_empty(): cut += 1
		assert_eq(cut,2,"the unfitted assembly reproduces both clipped caps")

func test_native_and_mixed_junctions_remain_closed() -> void:
	var pure := PURE.roof_study()
	var suntail := SuntailBuildingKit.create()
	for pair: Array in [[pure,pure],[pure,suntail],[suntail,pure]]:
		await _assert_mixed_closed_roof(Rect2i(2,4,2,3),1,pair[0],pair[1])
		await _assert_mixed_closed_roof(Rect2i(6,0,3,2),0,pair[0],pair[1])

func _assert_mixed_closed_roof(branch_rect: Rect2i, axis: int, host_kit: BuildingKit, branch_kit: BuildingKit) -> void:
	var kit := SuntailBuildingKit.create()
	var a := BuildingMass.new()
	a.stable_id = &"host"
	var b := BuildingMass.new()
	b.stable_id = &"branch"
	a.add_roof(Rect2i(0, 0, 6, 4), 0, 4, &"red")
	b.add_roof(branch_rect, axis, 4, &"red")
	var masses: Array[BuildingMass] = [a, b]
	preload("res://scripts/terrain/features/villages/kit/KitRoofJunctions.gd").join(masses)
	var roofs: Array[Dictionary] = [a.roofs[0], b.roofs[0]]
	var placements: Array[Dictionary] = []
	for i in masses.size():
		roofs[i].union_index = i
		placements.append_array(BuildingKitAssembler.new(host_kit if i == 0 else branch_kit).assemble(masses[i]))
	var payload := EnvironmentInstancePayload.new()
	preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd").append(
		placements, roofs, [], kit, Transform3D.IDENTITY, payload, {0:host_kit,1:branch_kit})
	var stage := Node3D.new()
	add_child(stage)
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	EnvironmentCollisionBuilder.commit(stage, payload, cache, &"native")
	var body := StaticBody3D.new()
	stage.add_child(body)
	for mesh: Dictionary in payload.surface_meshes:
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(mesh.collision_faces)
		var instance := CollisionShape3D.new()
		instance.shape = shape
		body.add_child(instance)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := stage.get_world_3d().direct_space_state
	var misses: Array[Vector2] = []
	for xi in range(1, 72):
		for zi in range(1, 56):
			# Avoid rays exactly on native mesh triangle/instance boundaries;
			# those are ambiguous in Godot's triangle intersection kernel.
			var p := Vector2(xi * 0.25 + 0.013, zi * 0.25 + 0.017)
			if not (Rect2(0, 0, 12, 8).has_point(p) or Rect2(Vector2(branch_rect.position) * 2, Vector2(branch_rect.size) * 2).has_point(p)): continue
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				Vector3(p.x, 20, p.y), Vector3(p.x, 5.9, p.y)))
			if hit.is_empty(): misses.append(p)
	assert_eq(misses.size(), 0, "native union stays closed, missing rays: %s" % str(misses.slice(0, 12)))

	stage.queue_free()
	await get_tree().process_frame

func test_native_ridge_contact_closes_oblique_sightlines() -> void:
	var kit := PURE.roof_study()
	var geometry: Dictionary = FileAccess.open(kit.roof_geometry_path,FileAccess.READ).get_var()
	for depth in [3,4]:
		var mass := BuildingMass.new()
		mass.add_roof(Rect2i(0,0,4,depth),0,4,&"red")
		var placements := BuildingKitAssembler.new(kit).assemble(mass)
		for side: int in [-1,1]:
			var direction := Vector3(0,-0.5,-side).normalized()
			var points: Array[Vector3] = []
			# Trace the small band around the cap/skirt contact from outside.
			# Back faces of the far roof cannot count as a closed near roof.
			for u in [0.53,2.53,4.53,6.53]:
				for i in 100:
					var z := float(depth) + side * 0.33
					var y := 6.0 + float(depth)*1.5 - 0.05 + float(i)*0.002
					points.append(Vector3(u,y,z)-direction*5.0)
			assert_eq(_roof_misses(placements,geometry,points,direction),0,
				"front-facing closure at depth %d, side %d" % [depth,side])

func test_public_verge_fit_keeps_the_native_gable_face() -> void:
	var kit := PURE.roof_study()
	var mass := BuildingMass.new()
	mass.stable_id = &"native_gable_verge"
	mass.add_storey(0,BuildingMass.rect_cells(Rect2i(0,0,4,2)),&"timber")
	var wing := mass.add_roof(Rect2i(0,0,4,2),0,2,&"red")
	wing.verge_min = kit.wall_face
	var audit := preload("res://tests/fixtures/kit_roof_audit.gd")
	var built := audit.assemble([mass],kit)
	assert_eq(int(audit.audit(built,kit).gable_holes),0,
		"fitting a roof verge must not peel away its own outward-facing gable")

func test_shortened_verges_keep_complete_native_end_caps_on_both_axes() -> void:
	const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
	var kit := PURE.roof_study()
	var catalog := EnvironmentCatalog.load_default()
	for id: StringName in kit.roof_cap_x_bounds:
		var box := catalog.descriptor(id).measured_aabb
		var measured: Vector2 = kit.roof_cap_x_bounds[id]
		assert_almost_eq(measured.x, box.position.x, 0.000001, "Cap metadata follows the actual native mesh.")
		assert_almost_eq(measured.y, box.end.x, 0.000001, "Cap metadata follows the actual native mesh.")
	for axis in 2:
		for depth in [4, 5]:
			var mass := BuildingMass.new()
			var wing := mass.add_roof(Rect2i(0, 0, 4, depth) if axis == 0 else Rect2i(0, 0, depth, 4), axis, 4, &"red")
			wing.union_index = 0
			wing.verge_min = kit.wall_face
			wing.verge_max = 0.28
			var ctx := UNION.prepare(mass.roofs, [], kit)
			var checked := 0
			for placement: Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
				if not kit.roof_cap_x_bounds.has(placement.asset_id): continue
				checked += 1
				var box: AABB = placement.transform * catalog.descriptor(placement.asset_id).measured_aabb
				var coordinate := 0 if axis == 0 else 2
				assert_gte(box.position[coordinate], -float(wing.verge_min) - 0.00001,
					"The intact cap still respects the near public-clearance plane.")
				assert_lte(box.end[coordinate], 8.0 + float(wing.verge_max) + 0.00001,
					"The intact cap still respects the far public-clearance plane.")
				assert_true(UNION.realize(placement, ctx).is_empty(),
					"Verge fitting must keep the authored closure, not chop its outer face off.")
			assert_gte(checked, 8, "Both gables and slopes include native closures.")

func test_full_gable_bays_have_native_windows_and_close_when_obstructed() -> void:
	const CONTACTS = preload("res://scripts/terrain/features/villages/kit/KitFacadeRoofContacts.gd")
	const UNION = preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
	for axis in 2:
		var kit := PURE.roof_study(1)
		var mass := BuildingMass.new()
		mass.stable_id = &"gable_windows"
		mass.add_roof(Rect2i(0,0,4,4),axis,4,&"blue")
		var parts := BuildingKitAssembler.new(kit).assemble(mass)
		var contacts := CONTACTS.prepare([],kit,{})
		var geometry := UNION.prepare(mass.roofs,[],kit)
		var windows := 0
		var obstruction := AABB()
		var obstructed_id: StringName
		for part: Dictionary in parts:
			if part.role != &"gable.wall": continue
			assert_true(geometry.data.has(part.asset_id),"The whole native window panel participates in roof junction cuts.")
			assert_true(contacts.openings.has(part.asset_id),"Full gable bays contain actual native glazing.")
			if not contacts.openings.has(part.asset_id): continue
			windows += 1
			obstruction = part.transform * contacts.openings[part.asset_id]
			obstructed_id = part.stable_id
		assert_gt(windows,0,"Both gable orientations have window bays.")
		assert_eq(CONTACTS.fit_gables(parts,kit,contacts),0,"Clear gable windows survive.")
		contacts.volumes = [UNION.box_volume(obstruction.grow(0.3))]
		assert_gt(CONTACTS.fit_gables(parts,kit,contacts),0)
		for part: Dictionary in parts:
			if part.stable_id == obstructed_id:
				assert_eq(part.asset_id,&"pure_village.wall.plaster.plain","An obstructed bay retains a complete closing panel.")
