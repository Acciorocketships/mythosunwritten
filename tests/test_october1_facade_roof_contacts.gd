extends GutTest
const CONTACTS := preload("res://scripts/terrain/features/villages/kit/KitFacadeRoofContacts.gd")
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
const PURE := preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")

func test_roof_crossing_an_opening_replaces_its_panel_and_window_box_only() -> void:
	for kit: BuildingKit in [SuntailBuildingKit.create(),PURE.create()]:
		var mass := BuildingMass.new()
		mass.stable_id = &"roof_contact"
		var storey := mass.add_storey(0,BuildingMass.rect_cells(Rect2i(0,0,2,2)),&"timber")
		var front := Vector3i(0,1,1)
		var door := Vector3i(0,0,3)
		storey.openings[door] = BuildingMass.OPENING_DOOR
		mass.decor = [{"kind":&"window_box","centre":Vector2(0.5,2),"dir":1,"y":0.0},
			{"kind":&"window_box","centre":Vector2(2,0.5),"dir":0,"y":0.0}]
		var ctx := CONTACTS.prepare([],kit,{})
		# Narrow roof contact crosses the centre of the actual opening;
		# checking only its corners would miss it.
		ctx.volumes = [UNION.box_volume(AABB(Vector3(0.9,1.8,4),Vector3(0.2,0.3,1)))]
		assert_eq(CONTACTS.fit(mass,BuildingKitAssembler.new(kit),ctx),1)
		assert_eq(storey.openings[front],BuildingMass.OPENING_PLAIN)
		assert_eq(storey.openings[door],BuildingMass.OPENING_DOOR,"door access is preserved")
		assert_eq(mass.decor.size(),1)
		assert_eq(mass.decor[0].centre,Vector2(2,0.5),"the unobstructed window keeps its box")

func test_roofs_below_a_sill_do_not_remove_clear_windows() -> void:
	var kit := SuntailBuildingKit.create()
	var ctx := CONTACTS.prepare([],kit,{})
	ctx.volumes = [UNION.box_volume(AABB(Vector3(-1,0,-1),Vector3(2,0.9,2)))]
	for yaw in [0.0,PI*0.5,PI,PI*1.5]:
		assert_false(CONTACTS.obstructed(&"suntail.frame.frame_wall_1_w",Transform3D(Basis(Vector3.UP,yaw),Vector3.ZERO),ctx))

func test_every_window_and_bay_variant_has_measured_opening_bounds() -> void:
	var ctx := CONTACTS.prepare([],SuntailBuildingKit.create(),{})
	for kit: BuildingKit in [SuntailBuildingKit.create(),PURE.create(0),PURE.create(1)]:
		for role: StringName in kit.roles:
			if not ((String(role).begins_with("wall.") and String(role).ends_with(".window")) or String(role).begins_with("bay.")): continue
			for id: StringName in kit.roles[role]:
				assert_true(ctx.openings.has(id),String(id))
				if ctx.openings.has(id):
					var b: AABB = ctx.openings[id]
					assert_gt(b.size.x*b.size.y,0.1,"real opening, not an empty fallback")

func test_a_lower_variant_preserves_windows_below_a_cornice() -> void:
	var kit := PURE.create(1)
	var mass := BuildingMass.new()
	mass.stable_id = &"window_fit"
	mass.add_storey(0,BuildingMass.rect_cells(Rect2i(0,0,2,2)),&"timber")
	var ctx := CONTACTS.prepare([],kit,{})
	ctx.volumes = [UNION.box_volume(AABB(Vector3(-1,2.6,-1),Vector3(6,1,6)))]
	var assembler := BuildingKitAssembler.new(kit)
	assert_eq(CONTACTS.fit(mass,assembler,ctx),0,"a complete lower window fits; no blank wall is necessary")
	assert_gt(int(ctx.get("substituted",0)),0)
	var windows := 0
	for p: Dictionary in assembler.assemble(mass):
		if p.role != &"wall.timber.window": continue
		windows += 1
		assert_eq(p.asset_id,&"pure_village.wall.plaster.window")
	assert_eq(windows,8,"every facade bay retains its opening")

func test_off_center_source_window_is_not_cropped_through_its_frame() -> void:
	var ctx := CONTACTS.prepare([],SuntailBuildingKit.create(),{})
	var opening: AABB = ctx.openings[&"pure_village.wall.plaster.window_open"]
	# Native Window_12_3's Window_1 material spans x=0.409836..1.2314.
	# The original symmetric crop silently shortened it to 0.590164 m.
	assert_almost_eq(opening.size.x,0.8216,0.002)
	assert_lt(opening.end.x,1.0)

func test_cached_native_roof_geometry_survives_payload_mapping() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := BuildingMass.new()
	var wing := mass.add_roof(Rect2i(0,0,4,4),0,0,&"red")
	wing.union_index = 0
	var wall := UNION.box_volume(AABB(Vector3(0,-1,-2),Vector3(3,10,12)))
	wall.open = true
	var ctx := UNION.prepare([wing],[wall],kit)
	ctx.realized_cache = {}
	var placements := BuildingKitAssembler.new(kit).assemble(mass)
	var chosen := {}
	var before: Array = []
	for p: Dictionary in placements:
		var result := UNION.realize(p,ctx)
		if result.is_empty(): continue
		chosen = p
		before = result.meshes.duplicate(true)
		break
	assert_false(chosen.is_empty(),"a real clipped roof exercises the cache")
	if chosen.is_empty(): return
	var payload := EnvironmentInstancePayload.new()
	UNION.append_prepared(placements,ctx,Transform3D(Basis.from_scale(Vector3.ONE*2),Vector3(10,0,20)),payload)
	var after: Dictionary = UNION.realize(chosen,ctx)
	for i in before.size():
		assert_eq(after.meshes[i].vertices,before[i].vertices,"cached vertices stay in native coordinates")
		assert_eq(after.meshes[i].normals,before[i].normals)
	assert_true(payload.validate())

func test_native_curved_cornice_uses_finished_skin_not_only_attic_volume() -> void:
	var kit := PURE.roof_study()
	var mass := BuildingMass.new()
	var wing := mass.add_roof(Rect2i(0,0,4,2),0,4,&"red")
	var pose := Transform3D(Basis.IDENTITY,Vector3(3,4,4.7))
	var asset := &"pure_village.wall.plaster.window"
	var ctx := CONTACTS.prepare([wing],kit,{})
	var logical_only := ctx.duplicate()
	logical_only.skins = []
	assert_false(CONTACTS.obstructed(asset,pose,logical_only),"the flared cornice lies beyond the ordinary attic volume")
	assert_true(CONTACTS.obstructed(asset,pose,ctx),"the authored cornice crosses the actual opening")
	var public_air := UNION.box_volume(AABB(Vector3(-1,4,4.5),Vector3(10,3,2)))
	public_air.open = true
	var clear := CONTACTS.prepare([wing],kit,{},[public_air])
	assert_false(CONTACTS.obstructed(asset,pose,clear),"removed roof triangles cannot blank a now-clear window")

func test_raised_floor_crossing_a_window_fits_a_complete_higher_opening() -> void:
	var kit := PURE.create(0)
	var mass := BuildingMass.new()
	mass.stable_id = &"raised_floor"
	var storey := mass.add_storey(0,BuildingMass.rect_cells(Rect2i(0,0,2,2)),&"timber")
	var ctx := CONTACTS.prepare([],kit,{})
	var floor_mesh := _floor(0.45) # Below native sill timber, which starts at 0.518 m.
	CONTACTS.add_floor(ctx,floor_mesh,Transform3D.IDENTITY)
	assert_true(CONTACTS.obstructed(&"pure_village.wall.plaster.window_arch",Transform3D.IDENTITY,ctx))
	assert_false(CONTACTS.obstructed(&"pure_village.wall.plaster.window",Transform3D.IDENTITY,ctx),"a floor below the sill is legal")
	# Force the low arch to exercise the fitter independently of the style roll.
	kit.roles[&"wall.timber.window"] = [&"pure_village.wall.plaster.window_arch",&"pure_village.wall.plaster.window"]
	var assembler := BuildingKitAssembler.new(kit)
	assert_eq(CONTACTS.fit(mass,assembler,ctx),0,"a higher complete opening fits above the raised floor")
	assert_gt(int(ctx.get("substituted",0)),0)
	for p: Dictionary in assembler.assemble(mass):
		if p.role == &"wall.timber.window":
			assert_false(CONTACTS.obstructed(p.asset_id,p.transform,ctx))
	assert_eq(storey.floor_band,0,"fitting the window does not move its building")

func test_floor_mapping_and_guards_do_not_confuse_opening_contacts() -> void:
	var floor_mesh := _floor(0.45) # Below native sill timber, which starts at 0.518 m.
	for yaw in [0.0,PI*0.5,PI,PI*1.5]:
		var pose := Transform3D(Basis(Vector3.UP,yaw),Vector3(20,6,30))
		var ctx := CONTACTS.prepare([],PURE.create(),{})
		CONTACTS.add_floor(ctx,floor_mesh,pose)
		assert_true(CONTACTS.obstructed(&"pure_village.wall.plaster.window_arch",pose,ctx))
		assert_false(CONTACTS.obstructed(&"pure_village.wall.plaster.window_arch",Transform3D.IDENTITY,ctx))
	floor_mesh.guard_index_ranges = [Vector2i(0,6)]
	var guarded := CONTACTS.prepare([],PURE.create(),{})
	CONTACTS.add_floor(guarded,floor_mesh,Transform3D.IDENTITY)
	assert_false(CONTACTS.obstructed(&"pure_village.wall.plaster.window_arch",Transform3D.IDENTITY,guarded),"a guard top is not a walking floor")

func _floor(y: float) -> Dictionary:
	return {"vertices":PackedVector3Array([Vector3(-2,y,-2),Vector3(6,y,-2),Vector3(6,y,6),Vector3(-2,y,6)]),
		"indices":PackedInt32Array([0,2,1,0,3,2]),"normals":PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP])}

func test_neighboring_inhabited_half_storey_floor_cannot_cut_a_window() -> void:
	var kit := SuntailBuildingKit.create()
	var assembler := BuildingKitAssembler.new(kit)
	var catalog := EnvironmentCatalog.load_default()
	var neighbour := BuildingMass.new()
	neighbour.add_storey(1,BuildingMass.rect_cells(Rect2i(0,0,1,1)),&"timber")
	var ctx := CONTACTS.prepare([],kit,{})
	var pose := Transform3D(Basis.IDENTITY,Vector3(1,0,0))
	var window := &"suntail.frame.frame_wall_1_w"
	assert_false(CONTACTS.obstructed(window,pose,ctx))
	CONTACTS.add_inhabited_floors(ctx,neighbour,assembler,catalog)
	assert_true(CONTACTS.obstructed(window,pose,ctx),"the real private floor interrupts the neighbour's glazing")
	var ground := BuildingMass.new()
	ground.add_storey(0,BuildingMass.rect_cells(Rect2i(0,0,1,1)),&"timber")
	var clear := CONTACTS.prepare([],kit,{})
	CONTACTS.add_inhabited_floors(clear,ground,assembler,catalog)
	assert_false(CONTACTS.obstructed(window,pose,clear),"a normal floor below the sill keeps its window")

func test_finished_mixed_town_windows_clear_all_inhabited_floors() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var kit := SuntailBuildingKit.create()
	var seed_value := 1260018864828801968
	var source := WarrenMazeSitePlanner.plan(seed_value,{},WarrenVillageScaleProfile.select(seed_value),&"",false)
	var spatial := preload("res://tests/fixtures/frozen_maze_source.gd").spatial(source,program)
	var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),kit)
	var ctx := CONTACTS.prepare([],kit,{})
	for mass: BuildingMass in built.masses:
		var own := StringName(String(mass.stable_id).trim_prefix("kit."))
		CONTACTS.add_inhabited_floors(ctx,mass,BuildingKitAssembler.new(built.house_kits.get(own,kit)),catalog)
	var checked := 0
	var glazed_gables := 0
	for part: Dictionary in built.placements:
		if not (String(part.role).begins_with("wall.") or String(part.role).begins_with("bay.") or part.role == &"gable.wall"): continue
		if not ctx.openings.has(part.asset_id): continue
		checked += 1
		if part.role == &"gable.wall": glazed_gables += 1
		assert_false(CONTACTS.obstructed(part.asset_id,part.transform,ctx),str(part))
	assert_gt(checked,20,"the entire reported town exercises native glazing")
	assert_gt(glazed_gables,5,"unobstructed gable windows remain glazed")

func test_attachment_cut_is_not_hidden_by_an_earlier_cached_roof() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := BuildingMass.new()
	var wing := mass.add_roof(Rect2i(0,0,4,4),0,0,&"red")
	wing.union_index = 0
	var ctx := UNION.prepare([wing],[],kit)
	ctx.realized_cache = {}
	var checked := false
	for part: Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
		if not String(part.role).contains(".eave"): continue
		assert_true(UNION.realize(part,ctx).is_empty(),"The original roof is an intact cached instance.")
		var changed := part.duplicate(true)
		var box: AABB = part.transform * EnvironmentCatalog.load_default().descriptor(part.asset_id).measured_aabb
		changed.clip_volumes = [UNION.box_volume(box.grow(0.1))]
		var cut := UNION.realize(changed,ctx)
		assert_false(cut.is_empty(),"An attachment must replace the cached uncut skin.")
		for mesh: Dictionary in cut.meshes:
			assert_true(mesh.vertices.is_empty(),"The complete native piece lies inside this test cutter.")
		assert_true(UNION.realize(part,ctx).is_empty(),"The attachment must not contaminate the shared cache.")
		checked = true
		break
	assert_true(checked)

func test_half_backed_facade_uses_a_native_high_window_without_looking_into_stone() -> void:
	var kit := PURE.create(0)
	var mass := BuildingMass.new()
	var storey := mass.add_storey(0,BuildingMass.rect_cells(Rect2i(0,0,2,2)),&"timber")
	var designer := BuildingDesigner.new(kit)
	designer.covered = func(_cell: Vector2i, band: int) -> bool: return band == 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	designer._assign_facades(mass,rng,&"red")
	var ctx := CONTACTS.prepare([],kit,{})
	var assembler := BuildingKitAssembler.new(kit)
	assembler.external_blocked = designer.covered
	CONTACTS.fit(mass,assembler,ctx)
	var windows := 0
	for part: Dictionary in assembler.assemble(mass):
		if part.role != &"wall.timber.window": continue
		windows += 1
		var opening: AABB = part.transform * (ctx.openings[part.asset_id] as AABB)
		assert_gt(opening.position.y,1.5,"the complete glazing clears retained backing")
		assert_eq(part.asset_id,&"pure_village.wall.plaster.window_open")
	assert_gt(windows,0,"a raised walkway must not turn the whole facade blank")
	# The same facade backed through its upper band cannot acquire a window.
	designer.covered = func(_cell: Vector2i, _band: int) -> bool: return true
	designer._assign_facades(mass,rng,&"red")
	for opening in storey.openings.values():
		assert_eq(opening,BuildingMass.OPENING_PLAIN)

func test_raised_streets_keep_high_native_windows_on_suntail_facades() -> void:
	var kit := SuntailBuildingKit.create()
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(2,{},program,WarrenVillageScaleProfile.for_id(&"grand"))
	var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),kit)
	var windows := 0
	for mass: BuildingMass in built.masses:
		# Follow the built facade type rather than a parcel id removed by
		# later merging/native-building admission.
		var own := StringName(String(mass.stable_id).trim_prefix("kit."))
		if built.house_kits.get(own,kit).kit_id != &"suntail": continue
		for storey: Dictionary in mass.storeys:
			for edge: Vector3i in storey.get("opening_min_y",{}):
				if storey.openings.get(edge,storey.default_opening) != BuildingMass.OPENING_WINDOW: continue
				assert_eq(storey.get("opening_assets",{}).get(edge,&""),&"pure_village.wall.plaster.window_open")
				windows += 1
	assert_gte(windows,2,"raised Suntail facades retain multiple real high openings")

func test_roof_through_bay_hood_is_rejected_even_when_glass_is_clear() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for kit: BuildingKit in [SuntailBuildingKit.create(),PURE.roof_study()]:
		for dir in 4:
			var mass := BuildingMass.new()
			var storey := mass.add_storey(0,BuildingMass.rect_cells(Rect2i(0,0,2,2)),&"timber")
			var cell := Vector2i(1,1) if dir<2 else Vector2i.ZERO
			var edge := BuildingMass.edge_key(cell,dir)
			storey.openings[edge]=BuildingMass.OPENING_BAY
			var assembler := BuildingKitAssembler.new(kit)
			var bay: Dictionary={}
			for part: Dictionary in assembler.assemble(mass):
				if String(part.role).begins_with("bay."):bay=part
			assert_false(bay.is_empty())
			if bay.is_empty():continue
			var box: AABB=bay.transform*catalog.descriptor(bay.asset_id).measured_aabb
			var ctx := CONTACTS.prepare([],kit,{})
			var y := box.end.y-0.04
			var vertices := PackedVector3Array([
				Vector3(box.position.x-1,y,box.position.z-1),
				Vector3(box.end.x+1,y,box.position.z-1),
				Vector3(box.end.x+1,y,box.end.z+1),
				Vector3(box.position.x-1,y,box.end.z+1)])
			ctx.skins=[{"bounds":AABB(vertices[0],Vector3(box.size.x+2,0,box.size.z+2)),
				"vertices":vertices,"indices":PackedInt32Array([0,1,2,0,2,3])}]
			assert_false(CONTACTS.obstructed(bay.asset_id,bay.transform,ctx),"Glass alone misses the hood collision")
			CONTACTS.fit(mass,assembler,ctx,catalog)
			assert_eq(storey.openings[edge],BuildingMass.OPENING_WINDOW,"Use a complete fitting window instead of a pierced bay")
			storey.openings[edge]=BuildingMass.OPENING_BAY
			ctx.skins=[]
			CONTACTS.fit(mass,assembler,ctx,catalog)
			assert_eq(storey.openings[edge],BuildingMass.OPENING_BAY,"Clear projecting assemblies remain")

func test_roof_crossing_native_arch_head_preserves_no_intersected_trim() -> void:
	var ctx := CONTACTS.prepare([],PURE.create(),{})
	var vertices := PackedVector3Array([Vector3(-0.2,2.22,-0.1),Vector3(0.2,2.22,-0.1),Vector3(0.2,2.22,0.2),Vector3(-0.2,2.22,0.2)])
	ctx.skins = [{"vertices":vertices,"indices":PackedInt32Array([0,1,2,0,2,3]),"bounds":AABB(Vector3(-0.2,2.219,-0.1),Vector3(0.4,0.002,0.3))}]
	assert_true(CONTACTS.obstructed(&"pure_village.wall.plaster.window_arch",Transform3D.IDENTITY,ctx), "Roof above clear glazing still crosses the authored arch head")
	assert_true(CONTACTS.obstructed(&"pure_village.wall.plaster.window_arch.finish_walnut",Transform3D.IDENTITY,ctx), "Material variants retain the same surround")
	var clear := Transform3D(Basis.IDENTITY,Vector3(2,0,0))
	assert_false(CONTACTS.obstructed(&"pure_village.wall.plaster.window_arch",clear,ctx), "Roof beside the complete frame is allowed")

func test_floor_above_clear_glass_sill_still_cannot_cut_timber_sill() -> void:
	var ctx := CONTACTS.prepare([],PURE.create(),{})
	CONTACTS.add_floor(ctx,_floor(0.6),Transform3D.IDENTITY)
	assert_true(CONTACTS.obstructed(&"pure_village.wall.plaster.window",Transform3D.IDENTITY,ctx), "Floor crosses native sill timber even though glazing is above it")

func test_suntail_surround_contacts_do_not_claim_detached_house_beams() -> void:
	var ctx := CONTACTS.prepare([],SuntailBuildingKit.create(),{})
	var asset := &"suntail.frame.frame_wall_1_w"
	assert_eq(ctx.frames[asset].size(),8,"The native frame has eight connected timber components")
	CONTACTS.add_floor(ctx,_floor(2.3),Transform3D.IDENTITY)
	var glazing_only := ctx.duplicate()
	glazing_only.frames = {}
	for yaw in [0.0,PI*0.5,PI,PI*1.5]:
		var pose := Transform3D(Basis(Vector3.UP,yaw),Vector3.ZERO)
		assert_false(CONTACTS.obstructed(asset,pose,glazing_only),"Header contact misses the glass")
		assert_true(CONTACTS.obstructed(asset,pose,ctx),"Authored header is protected at every orientation")
	var below := CONTACTS.prepare([],SuntailBuildingKit.create(),{})
	CONTACTS.add_floor(below,_floor(0.6),Transform3D.IDENTITY)
	assert_false(CONTACTS.obstructed(asset,Transform3D.IDENTITY,below),"The separate house beam below the window is not its surround")
	for component: AABB in ctx.frames[asset]:
		assert_gt(component.position.y,1.0)
		assert_lt(component.end.y,2.4)
		assert_gt(component.position.x,-0.5,"Exclude the full-height corner post")
		assert_lt(component.end.x,0.5)
