extends GutTest

## September 27 owner review: "canopies should not be on the ramps, and they
## should be better aligned with the buildings". A kit canopy is a four-post
## lean-to standing on the floor in front of its wall. Its posts must stand on
## a flat public floor at the storey's own level (never on a flight, a gate
## approach or open air), its footprint must be exactly one wall module wide,
## centred on the wall module it shelters, with its back beam on that wall.
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
const CANOPY := &"suntail.decor.wooden_canopy_1"
## (city seed, profile): the reported site-1 town plus a small corpus.
const TOWNS := [[1260018864828801968, &"compact"], [2, &"compact"],
	[4, &"compact"], [3, &"standard"], [7, &"standard"]]

static var _towns: Array = []


func _built_towns() -> Array:
	if not _towns.is_empty():
		return _towns
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for job: Array in TOWNS:
		var source := WarrenMazeSitePlanner.plan(int(job[0]), {},
			WarrenVillageScaleProfile.for_id(job[1]), &"", false)
		if source == null:
			continue
		var spatial := FROZEN.spatial(source, program)
		var fabric := spatial.compiled_fabric_cache()
		var built := KitVillageBuildings.build(spatial, fabric, SuntailBuildingKit.create())
		_towns.append({"id": "%d/%s" % [job[0], job[1]], "spatial": spatial,
			"fabric": fabric, "built": built})
	return _towns


static func _canopy_boxes(payload: EnvironmentInstancePayload, local: AABB) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not payload.batches.has(CANOPY):
		return out
	var batch: Dictionary = payload.batches[CANOPY]
	for index in batch.transforms.size():
		var t := batch.transforms[index] as Transform3D
		out.append({"transform": t, "box": t * local, "id": batch.ids[index]})
	return out


## Fine lattice cells whose square overlaps the box's XZ footprint.
static func _cells_under(box: AABB) -> Array[Vector2i]:
	var size := FabricRecipe.CELL_SIZE
	var eps := 0.02
	var out: Array[Vector2i] = []
	for x in range(floori((box.position.x + eps) / size + 0.5), floori((box.end.x - eps) / size + 0.5) + 1):
		for z in range(floori((box.position.z + eps) / size + 0.5), floori((box.end.z - eps) / size + 0.5) + 1):
			out.append(Vector2i(x, z))
	return out


func test_canopies_stand_on_flat_public_floor_never_on_flights() -> void:
	var local := EnvironmentCatalog.load_default().descriptor(CANOPY).measured_aabb
	var checked := 0
	for town: Dictionary in _built_towns():
		var fabric: SettlementFabricPlan = town.fabric
		var spatial: WarrenSpatialPlan = town.spatial
		# Every stair band per column: a flight passing well above a canopy
		# (the September 27 layout threads flights over ground lanes) is not
		# one it stands on; only a flight within its own height is.
		var stairs: Dictionary = {}
		for cell: Vector3i in fabric.surface_plan.cells_for_kind(
				PublicRealmSurfacePlan.SurfaceKind.STAIR):
			var column := Vector2i(cell.x, cell.z)
			if not stairs.has(column):
				stairs[column] = []
			(stairs[column] as Array).append(cell.y)
		var approaches: Array[Rect2] = []
		for spec: Dictionary in VillageWarrenFabricSolver.terrain_contact_specs(spatial, fabric):
			var geometry := VillageWarrenFabricSolver.terrain_contact_local_geometry(spec)
			var a := geometry.inner_centre as Vector3
			var b := geometry.outer_centre as Vector3
			var lateral := Vector3(spec.lateral) * float(geometry.half_width)
			var rect := Rect2(Vector2(a.x, a.z), Vector2.ZERO)
			for p: Vector3 in [a - lateral, a + lateral, b - lateral, b + lateral]:
				rect = rect.expand(Vector2(p.x, p.z))
			approaches.append(rect)
		for canopy: Dictionary in _canopy_boxes(town.built.payload, local):
			var box := canopy.box as AABB
			var band := roundi(box.position.y / WarrenVolumePlan.VERTICAL_BAND_SIZE_M)
			checked += 1
			var footprint := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
			for rect: Rect2 in approaches:
				assert_false(footprint.grow(-0.02).intersects(rect),
					"%s canopy %s stands on a gate approach flight" % [town.id, canopy.id])
			for cell: Vector2i in _cells_under(box):
				var top := ceili(box.end.y / WarrenVolumePlan.VERTICAL_BAND_SIZE_M)
				for stair_band: int in stairs.get(cell, []):
					assert_true(stair_band < band - 1 or stair_band > top,
						"%s canopy %s stands on a public flight at %s" % [town.id, canopy.id, cell])
				var floor_cell := Vector3i(cell.x, band, cell.y)
				assert_true(KitVillageBuildings._walked(spatial.grid, floor_cell),
					"%s canopy %s leg cell %s band %d is not a flat public floor" % [
						town.id, canopy.id, cell, band])
	assert_gt(checked, 0, "the corpus must exercise canopies")


func test_canopies_fit_and_centre_on_one_wall_module() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var local := catalog.descriptor(CANOPY).measured_aabb
	var checked := 0
	for town: Dictionary in _built_towns():
		var payload: EnvironmentInstancePayload = town.built.payload
		var walls: Array[Transform3D] = []
		var fronts: Array[float] = []
		for asset_id: StringName in payload.asset_ids():
			var id := String(asset_id)
			if id.begins_with("suntail.frame.frame_wall") or id.begins_with("suntail.stone.stone_wall"):
				# Deep masonry (September 27 details) stands prouder than timber.
				var front := catalog.descriptor(asset_id).measured_aabb.end.z
				for t: Transform3D in payload.batches[asset_id].transforms:
					walls.append(t)
					fronts.append((t.basis.z * front).length())
		var boxes := _canopy_boxes(payload, local)
		for i in boxes.size():
			var t := boxes[i].transform as Transform3D
			var along := t.basis.x.normalized()
			var out := t.basis.z.normalized()
			var centre := (t * local.get_center())
			var width := (t.basis.x * local.size.x).length()
			assert_lte(width, FabricRecipe.CELL_SIZE + 0.001,
				"%s canopy %s is wider than its wall module" % [town.id, boxes[i].id])
			# Its own wall module: same facing, same along-facade centre.
			var back := t * Vector3(local.get_center().x, 0.0, local.position.z)
			var owner_found := false
			for w in walls.size():
				var wall := walls[w]
				if wall.basis.z.normalized().dot(out) < 0.99: continue
				var delta := back - wall.origin
				if absf(delta.dot(along)) > 0.02: continue
				# The back beam meets the wall's outer face, not buried or floating.
				var gap := delta.dot(out) - fronts[w]
				if gap > -0.05 and gap < 0.14:
					owner_found = true
			assert_true(owner_found, "%s canopy %s is not centred and flush on a wall module" % [
				town.id, boxes[i].id])
			checked += 1
			var a := boxes[i].box as AABB
			for j in range(i + 1, boxes.size()):
				var b := boxes[j].box as AABB
				assert_false(a.grow(-0.03).intersects(b.grow(-0.03)),
					"%s canopies %s and %s overlap" % [town.id, boxes[i].id, boxes[j].id])
	assert_gt(checked, 0)
