extends GutTest

func test_landmark_frontage_is_kept_before_optional_descent() -> void:
	# Reserving after the descent left one admitted landmark in each town.
	# Mandatory gates and reserved cottage entrances retain priority. The compact
	# fixture formerly admitted a second landmark across the cottage approach;
	# that is no longer a fitting site. Keep its remaining exact site below.
	for job: Array in [[1998423929946073270,&"compact"],[6,&"large"]]:
		var source := WarrenMazeSitePlanner.plan(job[0],{},WarrenVillageScaleProfile.for_id(job[1]),&"",false)
		assert_not_null(source)
		if source == null: continue
		var count := 0
		for plot: Dictionary in source.plots:
			count += int(plot.kind==WarrenMazeSourcePlan.PLOT_ASSET)
		assert_gte(count,1 if job[1]==&"compact" else 2,"retain fitting native sites: %s" % str(job))

func test_committed_landmark_bands_stop_optional_boring() -> void:
	var massif := WarrenMassifBuilder.build(6,{},WarrenVillageScaleProfile.for_id(&"large"))
	var excavation := WarrenExcavation.new(6)
	var checked := 0
	for column: Vector2i in massif.columns:
		var cell := Vector3i(column.x,massif.base_at(column),column.y)
		if not WarrenPassageLatticeRules.slot_is_borable(massif,excavation,cell,2): continue
		excavation.construction_reservations[cell+Vector3i.UP] = true
		assert_false(WarrenPassageLatticeRules.slot_is_borable(massif,excavation,cell,2))
		excavation.construction_reservations.clear()
		excavation.construction_reservations[cell+Vector3i.UP*3] = true
		assert_true(WarrenPassageLatticeRules.slot_is_borable(massif,excavation,cell,2),"reservation is volumetric, not a whole-column ban")
		excavation.construction_reservations.clear()
		checked += 1
		if checked == 10: break
	assert_eq(checked,10)

func test_towns_retain_every_valid_precarve_landmark_site() -> void:
	for job: Array in [[1998423929946073270,&"compact"],[6,&"large"],[9,&"standard"]]:
		var source := WarrenMazeSitePlanner.plan(job[0],{},WarrenVillageScaleProfile.for_id(job[1]),&"",false)
		assert_not_null(source)
		if source == null: return
		var held: Array = source.audit.preselected_landmarks
		assert_gt(held.size(),0,"exercise actual selected sites")
		for site: Dictionary in held:
			var retained := false
			for plot: Dictionary in source.plots:
				if plot.kind != WarrenMazeSourcePlan.PLOT_ASSET: continue
				if plot.floor == site.floor and plot.top == site.top and plot.cells == site.cells: retained = true
			assert_true(retained,"the exact valid site survives optional carving: %s" % site.id)
		for cell: Vector3i in source.excavation.construction_reservations:
			assert_false(source.excavation.carved.has(cell),"optional carving preserves committed body and bearing")

func test_green_allows_roof_clearance_but_never_building_bearing() -> void:
	var massif := WarrenMassif.new(1)
	massif.columns[Vector2i.ZERO] = {"base":0,"top":8,"terrace":8}
	massif.columns[Vector2i.RIGHT] = {"base":0,"top":8,"terrace":8,"reserved_ground":true}
	var source := WarrenMazeSourcePlan.new(1,WarrenVillageScaleProfile.for_id(&"compact"),massif,WarrenExcavation.new(1))
	var own := {Vector2i.ZERO:true}
	var blocked := {Vector2i.RIGHT:true}
	var reach := WarrenPlotReservations._fine_box_reservation(source,own,blocked,Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,3,0,0)
	assert_true(reach.fits,"roof clearance may overhang a protected garden")
	assert_false(WarrenPlotReservations._fine_box_bears(source,Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,3,0,0,0),"the same footprint may not put a building on that garden")
	massif.columns[Vector2i.RIGHT].erase("reserved_ground")
	reach = WarrenPlotReservations._fine_box_reservation(source,own,blocked,Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,3,0,0)
	assert_false(reach.fits,"another building's claim still blocks the envelope")

func test_complete_low_landmark_fits_below_citadel_wall() -> void:
	var massif := WarrenMassif.new(1)
	massif.columns[Vector2i.ZERO] = {"base":0,"top":4,"terrace":4}
	massif.columns[Vector2i.RIGHT] = {"base":0,"top":10,"terrace":10,"plinth":4}
	var source := WarrenMazeSourcePlan.new(1,WarrenVillageScaleProfile.for_id(&"compact"),massif,WarrenExcavation.new(1))
	assert_true(WarrenPlotReservations._fine_box_bears(source,Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,0,0,0,0,{}, {},4))
	assert_false(WarrenPlotReservations._fine_box_bears(source,Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,0,0,0,0,{}, {},5))

func test_optional_descent_does_not_leave_streets_above_fixed_landmarks() -> void:
	var source := WarrenMazeSitePlanner.plan(9,{},WarrenVillageScaleProfile.for_id(&"standard"),&"carve",false)
	assert_not_null(source)
	if source == null: return
	var streets := WarrenPlotPlanner.street_bands(source)
	assert_gt(source.audit.preselected_landmarks.size(),0)
	for site: Dictionary in source.audit.preselected_landmarks:
		for column: Vector2i in site.cells:
			for band: int in streets.get(column,[]):
				assert_true(band<int(site.floor) or band==int(site.top),
					"A reserved fixed-height landmark cannot bear an optional street above its roof.")
