extends GutTest
## September 29 town review, stream "floating" (owner photos 1, 2, 6, 10):
## stone-walled, plank-bottomed boxes with no roof hanging over lanes and
## roofs, and an "L-shaped skywalk" that is the same box seen from above.
## They are crowns -- bored tunnel ceilings and rock shoulders left over a
## street -- that no construction stands on. See
## docs/qa/2026-09-29-town-review/floating/result.md.

## The two photographed towns (seed 2697992464 super cells (0,1) and (0,0))
## and a spread of other cities and scales.
const PINNED := [[1260018864828801968, &"compact"], [1998423929946073270, &"compact"]]
const CORPUS := [[1, &"compact"], [3, &"standard"], [4, &"large"], [6, &"compact"],
	[8, &"compact"], [9, &"standard"], [11, &"compact"], [12, &"grand"]]

## A town whose bore is covered whole (the positive case of the cover rule).
const COVER_PIN := [[7, &"large"]]

var _program: SettlementFabricProgram


func before_all() -> void:
	_program = SettlementFabricProgram.compile(EnvironmentCatalog.load_default())


func _audit(city: int, profile: StringName) -> Dictionary:
	var spatial := WarrenVolumetricSolver.generate(city, {}, _program,
		WarrenVillageScaleProfile.for_id(profile))
	assert_not_null(spatial, "%d/%s builds: %s" % [city, profile,
		WarrenVolumetricSolver.last_failure])
	if spatial == null:
		return {"count": -1}
	var fabric := spatial.compiled_fabric_cache()
	var built := KitVillageBuildings.build(spatial, fabric, SuntailBuildingKit.create())
	var audit := KitFloatingMassAudit.audit(spatial, fabric, built.masses)
	audit["spatial"] = spatial
	audit["masses"] = built.masses
	return audit


func test_photographed_towns_have_no_floating_boxes() -> void:
	for job: Array in PINNED:
		var audit := _audit(job[0], job[1])
		assert_eq(audit.unborne_crown_cells, [] as Array[Vector3i],
			"%d/%s: no stone crown hangs over a lane carrying nothing" % job)
		assert_eq(audit.floating_storey_cells, [] as Array[Vector3i],
			"%d/%s: no roofless kit box hangs over a lane" % job)
		assert_eq(audit.incomplete_skywalks, [] as Array[StringName],
			"%d/%s: every skywalk is a whole corridor or an open deck" % job)


func test_photographed_boxes_were_tunnel_ceilings_and_shoulders() -> void:
	# Town A photo 1: the bored tunnel at macro (-1,1,3)-(-1,1,4) had an
	# eight-cell ceiling at band 4 with open sky above; photo 2 is the two-cell
	# rock shoulder at band 3 over the lane at macro (0,0). Re-pinned after the
	# edges stream's perimeter lane (September 29) re-laid Town A: those fine
	# cells are now open sky or a house's own rooms, never stone over a lane,
	# and any tunnel ceiling still bored carries a room or a walk.
	var audit := _audit(PINNED[0][0], PINNED[0][1])
	var spatial := audit.spatial as WarrenSpatialPlan
	for cell: Vector3i in [Vector3i(-2, 4, 6), Vector3i(-1, 4, 9), Vector3i(0, 3, 1),
			Vector3i(1, 3, 1)]:
		assert_true(spatial.grid.use_at(cell) in [WarrenSpatialGrid.Use.OUTSIDE,
			WarrenSpatialGrid.Use.PRIVATE_VOLUME],
			"crown %s is released or inhabited" % cell)
	var houses: Dictionary = {}
	for mass: BuildingMass in audit.masses:
		if String(mass.stable_id).begins_with("kit.retained") \
				or String(mass.stable_id).begins_with("kit.tunnel"):
			continue
		for storey: Dictionary in mass.storeys:
			for band in range(int(storey.floor_band),
					int(storey.floor_band) + int(storey.get("bands", 2))):
				for cell: Vector2i in storey.cells:
					houses[Vector3i(cell.x, band, cell.y)] = true
	for mass: BuildingMass in audit.masses:
		if mass.stable_id != &"kit.tunnel-ceilings":
			continue
		for storey: Dictionary in mass.storeys:
			var top := int(storey.floor_band) + int(storey.get("bands", 2))
			for cell: Vector2i in storey.cells:
				var above := Vector3i(cell.x, top, cell.y)
				assert_true(houses.has(above) or KitVillageBuildings._walked(
					spatial.grid, above), "tunnel ceiling %s carries a room or a walk" % above)


func test_corpus_has_no_floating_masses() -> void:
	var total := 0
	for job: Array in CORPUS:
		var audit := _audit(job[0], job[1])
		var count := int(audit.count)
		if count != 0:
			gut.p("%d/%s floating: crowns=%s storeys=%s skywalks=%s" % [job[0], job[1],
				audit.unborne_crown_cells, audit.floating_storey_cells,
				audit.incomplete_skywalks])
		total += count
	assert_eq(total, 0, "no floating box or incomplete skywalk anywhere in the corpus")


func test_grid_release_frees_only_the_owners_own_cells() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i.ZERO, Vector3i(4, 4, 4))
	var claim := grid.begin_transaction(&"stone")
	var cells: Array[Vector3i] = [Vector3i(1, 1, 1)]
	assert_true(claim.assign_use(cells, WarrenSpatialGrid.Use.STRUCTURAL_VOLUME, &"stone"))
	assert_true(claim.reserve(cells, WarrenSpatialGrid.Reservation.FEATURE, &"stone"))
	assert_true(claim.commit())
	var theft := grid.begin_transaction(&"other")
	assert_true(theft.release(cells, &"other"))
	assert_false(theft.commit(), "another owner cannot free the stone")
	assert_eq(grid.use_at(cells[0]), WarrenSpatialGrid.Use.STRUCTURAL_VOLUME)
	var release := grid.begin_transaction(&"stone")
	assert_true(release.release(cells, &"stone"))
	assert_true(release.commit())
	assert_eq(grid.use_at(cells[0]), WarrenSpatialGrid.Use.OUTSIDE)
	assert_eq(grid.reservation_bits_at(cells[0]), 0)
	var reclaim := grid.begin_transaction(&"room")
	assert_true(reclaim.assign_use(cells, WarrenSpatialGrid.Use.PRIVATE_VOLUME, &"room"))
	assert_true(reclaim.commit(), "a released cell is free construction space again")


## Follow-up (tunnel-roof rule): a bored passage whose crown bears on two real
## jambs is covered by the storey of the adjacent house that lands just above
## it (`WarrenPlotPlanner.cover_tunnels`), decided in the plot stage, built by
## composition as that house's back room and re-proved on the built town. A
## cover is realized whole -- crown kept, lane headroom kept, room on top -- or
## not at all (crown released), never half a storey over the lane.
func test_passage_covers_are_whole_or_absent() -> void:
	var realized: Array[String] = []
	for job: Array in PINNED + CORPUS + COVER_PIN:
		var spatial := WarrenVolumetricSolver.generate(job[0], {}, _program,
			WarrenVillageScaleProfile.for_id(job[1]))
		assert_not_null(spatial, "%d/%s builds" % job)
		if spatial == null:
			continue
		var source := spatial.source_volume.mass_context.get(
			&"maze_source_plan") as WarrenMazeSourcePlan
		for plot: Dictionary in source.plots:
			if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_OVER:
				continue
			var column := (plot["cells"] as Array)[0] as Vector2i
			var crown := int(plot["crown"])
			var uses: Dictionary = {}
			var rooms := WarrenVolumetricSolver.building_private_cells(
				spatial.buildings)
			for fine: Vector3i in WarrenVolumetricSolver._fine_square(
					Vector3i(column.x, int(plot["floor"]), column.y)):
				var use := spatial.grid.use_at(fine)
				# A feature's own volume (a balcony carried on its braces over
				# the lane) is not a house storey: only rooms make a cover.
				if use == WarrenSpatialGrid.Use.PRIVATE_VOLUME and not rooms.has(fine):
					use = WarrenSpatialGrid.Use.OUTSIDE
				uses[use] = true
			for fine: Vector3i in WarrenVolumetricSolver._fine_square(
					Vector3i(column.x, crown, column.y)):
				assert_eq(spatial.grid.use_at(fine + Vector3i.DOWN),
					WarrenSpatialGrid.Use.PUBLIC_AIR,
					"%d/%s: the lane under %s keeps its headroom" % [job[0],
						job[1], column])
				uses[spatial.grid.use_at(fine) + 100] = true
			var whole := uses.keys() == [WarrenSpatialGrid.Use.PRIVATE_VOLUME,
				WarrenSpatialGrid.Use.STRUCTURAL_VOLUME + 100]
			var absent := not uses.has(WarrenSpatialGrid.Use.PRIVATE_VOLUME) \
				and uses.has(WarrenSpatialGrid.Use.OUTSIDE + 100) \
				and uses.size() == 2
			assert_true(whole or absent, "%d/%s: cover over %s is whole or absent: %s"
				% [job[0], job[1], column, uses])
			if whole:
				realized.append("%d/%s:%s" % [job[0], job[1], column])
	# Town A's bore at macro (2,3,-4) runs between two houses; house.008's
	# storey continues over it (re-measured Sep 29 after the edges stream's
	# perimeter lane re-laid the corpus; the earlier pins 12/grand (0,-2) and
	# 7/large (-1,1) moved with the citadel platform and the lane).
	assert_has(realized, "1260018864828801968/compact:(2, -4)",
		"a borne bore is covered: %s" % [realized])
