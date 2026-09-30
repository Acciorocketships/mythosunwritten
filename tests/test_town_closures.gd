extends GutTest

## September 27 owner review, second pass: every gap in the town closed.
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
## Site 2 (1224,528): the lane under a bridge-house and the ramp beside it.
const SITE_TOWN := 2695877283924445960
## September 29 re-pin: SITE_TOWN's lane is now crossed by an open timber
## bridge (skywalks stream: spans landing on walk surfaces are open bridges),
## and its only storey left over public air was the uncarried tunnel ceiling
## the floating stream releases. Town B of the Sept 29 review (seed
## 2697992464 super cell (0,0)) keeps two enclosed bridge-houses and two
## passage-houses over its lanes.
const AIR_TOWN := 1998423929946073270
const BOARD := &"suntail.floor.floor_2"

static var _towns: Dictionary = {}


func _site(city: int = SITE_TOWN) -> Dictionary:
	if not _towns.has(city):
		var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
		var source := WarrenMazeSitePlanner.plan(city, {},
			WarrenVillageScaleProfile.for_id(&"compact"), &"", false)
		var spatial := FROZEN.spatial(source, program)
		_towns[city] = {"spatial": spatial, "fabric": spatial.compiled_fabric_cache(),
			"built": KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(),
				SuntailBuildingKit.create())}
	return _towns[city]


## (1210.9,24.5,579.3): looking up the lane, the owner saw into a floorless
## bridge-house (pale inner walls, gable timbers, sky). A storey over public
## air must close its underside wherever nothing of its own stands below.
func test_rooms_over_public_air_have_a_closed_underside() -> void:
	var town := _site(AIR_TOWN)
	var spatial: WarrenSpatialPlan = town.spatial
	var payload: EnvironmentInstancePayload = town.built.payload
	var boards: Dictionary = {}
	var batch: Dictionary = payload.batches.get(BOARD, {})
	for index in batch.get("transforms", []).size():
		var o := (batch.transforms[index] as Transform3D).origin
		boards[Vector3i(roundi(o.x / 1.5), roundi(o.y / 1.5), roundi(o.z / 1.5))] = true
	var checked := 0
	for mass: BuildingMass in town.built.masses:
		# Rooms only: a roofless retained/tunnel course is stone, not a storey.
		if String(mass.stable_id).begins_with("kit.retained") \
				or String(mass.stable_id).begins_with("kit.tunnel"):
			continue
		for storey: Dictionary in mass.storeys:
			var floor := int(storey.floor_band)
			var below := mass.cells_at_band(floor - 1)
			for cell: Vector2i in storey.cells:
				if below.has(cell):
					continue
				var under := Vector3i(cell.x, floor - 1, cell.y)
				if not spatial.grid.contains(under) or spatial.grid.use_at(under) \
						not in [WarrenSpatialGrid.Use.PUBLIC_AIR, WarrenSpatialGrid.Use.DAYLIGHT_AIR]:
					continue
				checked += 1
				assert_true(boards.has(Vector3i(cell.x, floor, cell.y)),
					"%s storey %d cell %s hangs over public air without a soffit" % [
						mass.stable_id, floor, cell])
	assert_gt(checked, 0, "the site keeps rooms over public air")


## The right-hand ramp rail at the same site ran into a house wall with no
## post: a clipped rail end must finish on a post seated outside the wall.
func test_rail_clipped_by_a_wall_ends_on_a_post() -> void:
	var transition := WarrenVolumeTransition.new(&"wall-ended", Vector3i.ZERO,
		Vector3i(0, 1, 2), WarrenVolumeTransition.Kind.STAIR, [])
	assert_true(transition.seal())
	# A wall block covers the upper part of the flight's +x side (the flight
	# runs z 2.25..5.25 at x 0.75 +/- 1.5; regular posts stand at z 2.25,
	# 3.75, 5.25), so the rail is clipped at z 4.1 between two posts.
	var wall := AABB(Vector3(1.3, -1.0, 4.1), Vector3(1.5, 6.0, 3.0))
	var payload := WarrenTransitionSurfaceBuilder.build(&"wall-ended", transition,
		[Vector3i.ZERO], [wall])
	var faces: PackedVector3Array = payload.collision_faces
	# Where does the clipped upper rail end? Probe along the run just outside
	# the wall face at rail height: the post must stand between rail tip and wall.
	var side_x := WarrenTransitionSurfaceBuilder.MACRO_SIZE * 0.5 + 0.75
	var hit_post := false
	for step in 12:
		var z := wall.position.z - 0.02 - float(step) * 0.01
		var floor_y := (z - 2.25) / 3.0 * 1.5
		# Between the two rails: only a post can be hit here.
		var y := floor_y + WarrenTransitionSurfaceBuilder.GUARD_HEIGHT * 0.76
		var a := Vector3(side_x - 0.3, y, z)
		var b := Vector3(side_x + 0.3, y, z)
		for i in range(0, faces.size(), 3):
			if Geometry3D.segment_intersects_triangle(a, b, faces[i], faces[i + 1], faces[i + 2]) != null:
				hit_post = true
	assert_true(hit_post, "a post finishes the rail against the wall face")


## (1261.3,24.0,546.7): the one-band retained course around the lawn in front
## of a house was tiled from the pack's corner plinth, whose taller corner pier
## repeats at every 2 m module and juts past one run end: a gap-toothed wall
## with stepped ends. A course is a flush masonry panel like the storeys above.
func test_retained_courses_are_flush_masonry_not_corner_plinths() -> void:
	var payload: EnvironmentInstancePayload = _site().built.payload
	var courses := 0
	for asset_id: StringName in payload.asset_ids():
		var batch: Dictionary = payload.batches[asset_id]
		for id: StringName in batch.ids:
			if not String(id).begins_with("kit.retained/"):
				continue
			assert_ne(asset_id, &"suntail.stone.stone_base",
				"retained course %s is tiled from the corner plinth" % id)
			if String(asset_id).begins_with("suntail.stone.stone_wall"):
				courses += 1
	assert_gt(courses, 0, "the site keeps retained stone courses")


## (1252.5,24.0,526.8): at the convex corner of the raised lawn's retaining
## wall the two wall panels' top beams stopped short of each other and their
## edge posts stood side by side, leaving a stepped notch under the rail/cap.
## Every exposed convex corner of a kit wall ring is closed by one corner post.
func test_convex_wall_corners_are_closed_by_one_post() -> void:
	var payload: EnvironmentInstancePayload = _site().built.payload
	var posts: Array[Vector3] = []
	var batch: Dictionary = payload.batches.get(&"suntail.decor.support_3", {})
	for index in batch.get("transforms", []).size():
		if String(batch.ids[index]).begins_with("kit.retained/"):
			posts.append((batch.transforms[index] as Transform3D).origin)
	var retained: BuildingMass = null
	for mass: BuildingMass in _site().built.masses:
		if mass.stable_id == &"kit.retained":
			retained = mass
	assert_not_null(retained)
	var corners := 0
	for storey: Dictionary in retained.storeys:
		for run: Dictionary in BuildingKitAssembler.boundary_runs(storey.cells):
			for at_end in [false, true]:
				if not bool(run.end_convex if at_end else run.start_convex):
					continue
				var p := BuildingKitAssembler._run_point(run, at_end)
				var corner := Vector2(p) * 1.5 - Vector2(0.75, 0.75)
				# Only a corner in the open: all three outside cells are air.
				var open := true
				var band := int(storey.floor_band)
				for cell: Vector2i in [p - Vector2i.ONE, p - Vector2i(0, 1), p - Vector2i(1, 0), p]:
					if storey.cells.has(cell): continue
					var probe := Vector3i(cell.x, band, cell.y)
					var grid: WarrenSpatialGrid = _site().spatial.grid
					open = open and (not grid.contains(probe) or grid.use_at(probe) in [
						WarrenSpatialGrid.Use.OUTSIDE, WarrenSpatialGrid.Use.ALLOCATABLE,
						WarrenSpatialGrid.Use.PUBLIC_AIR, WarrenSpatialGrid.Use.DAYLIGHT_AIR])
				if not open: continue
				corners += 1
				var found := false
				for post: Vector3 in posts:
					if Vector2(post.x, post.z).distance_to(corner) < 0.2 \
							and absf(post.y - float(int(storey.floor_band)) * 1.5) < 1.6:
						found = true
				assert_true(found, "retained storey %d corner %s has no corner post" % [
					int(storey.floor_band), corner])
	assert_gt(corners, 0)
