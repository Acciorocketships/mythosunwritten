extends GutTest
const PURE := preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")
const FIT := preload("res://scripts/terrain/features/villages/kit/KitRoofDormerFits.gd")
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
const CONTACTS := preload("res://scripts/terrain/features/villages/kit/KitFacadeRoofContacts.gd")


func test_obstructed_dormer_moves_whole_and_preserves_clear_bays() -> void:
	var kit := PURE.roof_study()
	for axis in 2:
		var mass := BuildingMass.new()
		var wing := mass.add_roof(
			Rect2i(0, 0, 6, 4) if axis == 0 else Rect2i(0, 0, 4, 6), axis, 4, &"red"
		)
		wing.tight_eave = true
		wing.dormers = {Vector2i(0, 1): true, Vector2i(0, 4): true}
		var box := (
			AABB(Vector3(2.5, 6.8, 7.9), Vector3(1, 1.6, 0.8))
			if axis == 0
			else AABB(Vector3(7.9, 6.8, 2.5), Vector3(0.8, 1.6, 1))
		)
		var wall := UNION.box_volume(box)
		wall.open = true
		var result := FIT.fit([wing], kit, {}, [wall])
		assert_eq(result.moved, 1)
		assert_eq(result.omitted, 0)
		assert_true(wing.dormers.has(Vector2i(0, 4)), "the clear original bay keeps its opening")
		assert_true(
			wing.dormers.has(Vector2i(0, 2)),
			"the nearest clear well-spaced bay receives the complete dormer"
		)
		assert_false(wing.dormers.has(Vector2i(0, 1)))
		var ctx := {
			"volumes": [wall],
			"openings": FileAccess.open(CONTACTS.OPENINGS, FileAccess.READ).get_var()
		}
		var count := 0
		for p: Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
			if not String(p.role).ends_with("dormer"):
				continue
			count += 1
			assert_false(CONTACTS.obstructed(p.asset_id, p.transform, ctx))
		assert_eq(count, 2)
		assert_eq(FIT.fit([wing], kit, {}, [wall]).moved, 0)


func test_no_clear_bay_uses_a_complete_plain_roof() -> void:
	var kit := PURE.roof_study()
	var mass := BuildingMass.new()
	var wing := mass.add_roof(Rect2i(0, 0, 6, 4), 0, 4, &"red")
	wing.dormers = {Vector2i(0, 1): true, Vector2i(0, 4): true}
	var wall := UNION.box_volume(AABB(Vector3(-2, 6, -2), Vector3(16, 5, 12)))
	var result := FIT.fit([wing], kit, {}, [wall])
	assert_eq(result.omitted, 2)
	assert_true(wing.dormers.is_empty())
	var eaves := 0
	for p: Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
		assert_false(String(p.role).ends_with("dormer"))
		if String(p.role).ends_with(".eave"):
			eaves += 1
	assert_eq(eaves, 12, "every bay still carries its complete roof course")


func test_every_dormer_family_has_a_measured_opening() -> void:
	var openings: Dictionary = FileAccess.open(CONTACTS.OPENINGS, FileAccess.READ).get_var()
	for kit: BuildingKit in [SuntailBuildingKit.create(), PURE.roof_study()]:
		for role: StringName in kit.roles:
			if not String(role).ends_with("dormer"):
				continue
			for asset: StringName in kit.roles[role]:
				assert_true(openings.has(asset), String(asset))


func test_clear_glass_cannot_keep_a_dormer_with_a_cut_roof_skin() -> void:
	var kit := PURE.roof_study()
	var mass := BuildingMass.new()
	var wing := mass.add_roof(Rect2i(0, 0, 6, 4), 0, 4, &"red")
	wing.tight_eave = true
	wing.dormers = {Vector2i(0, 1): true}
	var geometry := UNION.prepare([wing], [], kit).data as Dictionary
	var part := {}
	for placed: Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
		if String(placed.role).ends_with("dormer"):
			part = placed
	assert_false(part.is_empty())
	var opening_context := {
		"volumes": [], "openings": FileAccess.open(CONTACTS.OPENINGS, FileAccess.READ).get_var()
	}
	var obstruction := {}
	# A small public-air contact on an indexed low roof triangle, away from
	# the opening. This is precisely the gap in a glass-only admission test.
	for surface: Dictionary in geometry[part.asset_id]:
		if not obstruction.is_empty():
			break
		var v: PackedVector3Array = part.transform * surface.vertices
		for i in range(0, surface.indices.size(), 3):
			var point := (
				(v[surface.indices[i]] + v[surface.indices[i + 1]] + v[surface.indices[i + 2]])
				/ 3.0
			)
			if point.y > 6.5:
				continue
			var wall := UNION.box_volume(AABB(point - Vector3.ONE * .08, Vector3.ONE * .16))
			wall.open = true
			opening_context.volumes = [wall]
			if CONTACTS.obstructed(part.asset_id, part.transform, opening_context):
				continue
			var meshes := []
			for raw: Dictionary in geometry[part.asset_id]:
				meshes.append(UNION.trim_surface(raw, part.transform, [wall]))
			if (
				preload("res://scripts/terrain/features/villages/kit/KitRoofEaveFits.gd")
				. removes_surface(
					{"surfaces": geometry[part.asset_id], "meshes": meshes}, part.transform
				)
			):
				obstruction = wall
				break
	assert_false(
		obstruction.is_empty(), "The stock dormer has low roof skin outside its glass opening"
	)
	var result := FIT.fit([wing], kit, {}, [obstruction])
	assert_false(
		wing.dormers.has(Vector2i(0, 1)), "Reject the entire clipped module despite visible glazing"
	)
	assert_eq(result.moved + result.omitted, 1)
