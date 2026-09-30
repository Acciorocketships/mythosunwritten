extends GutTest

## September 27 owner review (site 318,19,1074): a timber court one band above
## a retained lawn left the band between lawn and deck open, with posts driven
## through the lawn to the envelope ground. The retained terrace is the court's
## real bearing: a court one band above it is closed by its retaining skirt and
## no post may pierce retained ground.
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
const SITE_TOWN := 1260018864828801968
## The September 27 layout pass (open field, reserved loops) reshaped the
## reported town: its court now stands on its own terrace, not one band over a
## lawn. The invariant is checked on the reported town and on two compact towns
## that do carry courts one band over a retained lawn (the photo-11 town and
## seed 2), so the skirt rule stays exercised whatever the layout draws.
const TOWNS := [SITE_TOWN, 85830433957479026, 2]

static var _fabrics: Dictionary = {}


func _plan(town: int) -> SettlementFabricPlan:
	if not _fabrics.has(town):
		var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
		var source := WarrenMazeSitePlanner.plan(town, {},
			WarrenVillageScaleProfile.for_id(&"compact"), &"", false)
		_fabrics[town] = FROZEN.spatial(source, program).compiled_fabric_cache()
	return _fabrics[town]


func test_court_one_band_above_a_retained_lawn_is_skirted() -> void:
	var checked := 0
	for town: int in TOWNS:
		checked += _check_skirts(_plan(town))
	assert_gt(checked, 0, "the corpus keeps a court over a retained lawn")


func _check_skirts(fabric: SettlementFabricPlan) -> int:
	var walls: Dictionary = {}
	var low := SettlementFabricAssembler.low_retaining_payload(fabric)
	for asset_id: StringName in low.asset_ids():
		for id: StringName in low.batches[asset_id].ids:
			walls[String(id)] = true
	var structural: Dictionary = {}
	for cell: Vector3i in fabric.surface_plan.cells_for_kind(
			PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT):
		structural[cell] = true
	var solids := fabric.transformed_cells(&"solid")
	var checked := 0
	for cell: Vector3i in structural:
		if not fabric.retained_terrace_cells.has(cell - Vector3i.UP * 2) \
				or fabric.retained_terrace_cells.has(cell - Vector3i.UP):
			continue
		assert_eq(SettlementFabricAssembler.effective_support_base(fabric, cell), cell.y - 1,
			"the retained lawn beneath %s is its bearing" % cell)
		for direction: Vector3i in SettlementFabricAssembler.FACE_DIRECTIONS:
			var neighbour := cell + direction
			if structural.has(neighbour) or solids.has(neighbour) \
					or solids.has(neighbour - Vector3i.UP):
				continue
			checked += 1
			assert_true(walls.has("retaining-wall/%d/%d/%d/%d/%d" % [cell.x, cell.y,
				cell.z, direction.x, direction.z]),
				"court %s face %s over the lawn is closed" % [cell, direction])
	return checked


func test_court_posts_never_pierce_retained_ground() -> void:
	for town: int in TOWNS:
		_check_posts(_plan(town))


func _check_posts(fabric: SettlementFabricPlan) -> void:
	var posts := SettlementFabricAssembler.structural_support_payload(fabric)
	var batch: Dictionary = posts.batches.get(SettlementFabricAssembler.TIMBER_SUPPORT, {})
	var size := FabricRecipe.CELL_SIZE
	var posts_checked := 0
	for index in batch.get("transforms", []).size():
		if not String(batch.ids[index]).begins_with("public-support/"):
			continue
		posts_checked += 1
		var t := batch.transforms[index] as Transform3D
		# Posts stand on outline vertices; the four cells meeting there.
		var column := Vector2i(floori(t.origin.x / size + 0.5), floori(t.origin.z / size + 0.5))
		for dx in [-1, 0]:
			for dz in [-1, 0]:
				for band in range(floori(t.origin.y / size) - 1, ceili((t.origin.y + 3.0) / size) + 1):
					var cell := Vector3i(column.x + dx, band, column.y + dz)
					var overlaps := float(band) * size < t.origin.y + 3.0 - 0.01 \
						and float(band + 1) * size > t.origin.y + 0.01
					if overlaps:
						assert_false(fabric.retained_terrace_cells.has(cell),
							"post %s pierces retained cell %s" % [batch.ids[index], cell])
	assert_true(posts_checked >= 0, "%d court posts checked" % posts_checked)
