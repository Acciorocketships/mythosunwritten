extends GutTest

## September 29 owner review (seed 2697992464), "materials" stream.
##  * photos 3/5: stairs, ramps, their rails and landings were drawn with the
##    legacy generated plank shader (pale yellow) beside the kit's brown decks.
##  * photo 5: a legacy timber truss arch sat embedded in the walls over a lane.
##  * photo 7: a house's deep stone storey stood on the flush retained course,
##    two stone walls 0.2 m apart with offset corner posts.
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
const REVIEW := preload("res://tests/harness/suntail/kit_town_review.gd")
## Town A (photos 1-5, 7, 9), Town B (photos 6, 8, 10) and a small corpus.
const TOWNS := [[1260018864828801968, &"compact"], [1998423929946073270, &"compact"],
	[3, &"standard"], [7, &"standard"], [4, &"large"]]

static var _towns: Array = []


func _built_towns() -> Array:
	if not _towns.is_empty():
		return _towns
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	KitSubstitution.prepare(catalog, SuntailBuildingKit.create())
	for job: Array in TOWNS:
		var source := WarrenMazeSitePlanner.plan(int(job[0]), {},
			WarrenVillageScaleProfile.for_id(job[1]), &"", false)
		if source == null:
			continue
		var spatial := FROZEN.spatial(source, program)
		var fabric := spatial.compiled_fabric_cache()
		_towns.append({"id": "%d/%s" % [job[0], job[1]], "fabric": fabric,
			"payload": REVIEW.town_payload(spatial, fabric, false)})
	return _towns


# --- photos 3/5: one timber family for every public walking surface ----------

func test_public_walking_surfaces_are_drawn_in_kit_timber() -> void:
	var towns := _built_towns()
	assert_eq(towns.size(), TOWNS.size(), "every corpus town builds")
	var deck := SuntailBuildingKit.create().asset(&"deck.board")
	for town: Dictionary in towns:
		var payload := town.payload as EnvironmentInstancePayload
		var flights := 0
		for mesh: Dictionary in payload.surface_meshes:
			if not (bool(mesh.get("is_transition", false))
					or bool(mesh.get("structural_plank", false))):
				continue
			flights += int(bool(mesh.get("is_transition", false)))
			# Without a kit material the renderer falls back to the legacy
			# generated plank shader / flat plank colour.
			assert_eq(StringName(mesh.get("material_asset_id", &"")), deck,
				"%s: %s is drawn with the kit deck timber" % [town.id, mesh.stable_id])
			assert_eq((mesh.get("tangents", PackedFloat32Array()) as PackedFloat32Array).size(),
				(mesh.vertices as PackedVector3Array).size() * 4,
				"%s: %s carries tangents for the deck's normal map" % [town.id, mesh.stable_id])
		assert_gt(flights, 0, "%s has public flights to check" % town.id)
		for asset_id: StringName in payload.asset_ids():
			var id := String(asset_id)
			# Legacy Fantasy-Village decks, rails, stairs, arches and gates (free
			# props such as planters keep their own art); the KayKit terrain skin
			# (rim lips) belongs to the terrain family.
			assert_false(id.begins_with("sfv.") and not KitSubstitution.is_rigid_prop(asset_id),
				"%s: legacy pack piece %s survives in a kit town" % [town.id, id])
			if id.begins_with("kaykit."):
				assert_true(CliffDressing.is_terrain_skin_asset(asset_id),
					"%s: KayKit %s is only terrain skin" % [town.id, id])


func test_flight_guards_keep_collision_and_draw_kit_railings() -> void:
	var rail := SuntailBuildingKit.create().asset(&"rail.low")
	for town: Dictionary in _built_towns():
		var payload := town.payload as EnvironmentInstancePayload
		var fabric := town.fabric as SettlementFabricPlan
		var generated: Dictionary = {}
		for mesh: Dictionary in fabric.surface_plan.mesh_payloads:
			if bool(mesh.get("is_transition", false)):
				generated[StringName("public-transition/%s" % mesh.stable_id)] = mesh
		var railings: Dictionary = {}
		var batch: Dictionary = payload.batches.get(rail, {})
		for id: StringName in batch.get("ids", []):
			railings[String(id).get_slice("/rail", 0)] = true
		for mesh: Dictionary in payload.surface_meshes:
			if not generated.has(StringName(mesh.stable_id)):
				continue
			var source: Dictionary = generated[StringName(mesh.stable_id)]
			assert_eq(mesh.collision_faces, source.collision_faces,
				"%s: %s keeps its guard collision" % [town.id, mesh.stable_id])
			var guard_triangles := 0
			for span: Vector2i in source.get("guard_index_ranges", []):
				guard_triangles += (span.y - span.x) / 3
			assert_eq((mesh.indices as PackedInt32Array).size() / 3,
				(source.indices as PackedInt32Array).size() / 3 - guard_triangles,
				"%s: %s renders its treads, not its generated guard beams" % [town.id, mesh.stable_id])
			if not (source.get("guard_spans", []) as Array).is_empty():
				assert_true(railings.has(String(mesh.stable_id)),
					"%s: %s is railed with the kit railing" % [town.id, mesh.stable_id])


# --- photo 5: no legacy arch or gate frame in a town ---------------------------

func test_no_arch_frame_is_embedded_in_a_town() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for town: Dictionary in _built_towns():
		var fabric := town.fabric as SettlementFabricPlan
		for placement: Dictionary in fabric.expanded_placements():
			assert_false(String(placement.stable_id).begins_with("tunnel-mouth/"),
				"%s: tunnel mouth frame %s" % [town.id, placement.stable_id])
		var payload := town.payload as EnvironmentInstancePayload
		for asset_id: StringName in payload.asset_ids():
			var id := String(asset_id)
			assert_false(id.contains("arch") or id.contains("gate"),
				"%s: arch/gate asset %s in the town" % [town.id, id])
			if catalog.has(asset_id):
				var tags := catalog.descriptor(asset_id).tags
				assert_false(tags.has(&"arch") or tags.has(&"gate"),
					"%s: %s is tagged as an arch/gate" % [town.id, id])


# --- photo 7: one masonry plane per wall line ----------------------------------

func test_no_stone_storey_stands_on_a_flush_course() -> void:
	# A flush course (retaining panel) directly below or beside a deep storey
	# panel on the same wall line is a 0.2 m masonry jog with offset corner
	# posts: two stone walls where the owner expects one plinth.
	var frame := Transform3D(Basis.from_scale(VillageWorldScale.frame_scale()), Vector3.ZERO)
	for town: Dictionary in _built_towns():
		var payload := town.payload as EnvironmentInstancePayload
		var walls: Array[Dictionary] = []
		for asset_id: StringName in payload.asset_ids():
			var id := String(asset_id)
			if not id.begins_with("suntail.stone.stone_wall"):
				continue
			var batch: Dictionary = payload.batches[asset_id]
			for index in batch.transforms.size():
				var t := frame * (batch.transforms[index] as Transform3D)
				var out := Vector3(t.basis.z.x, 0.0, t.basis.z.z).normalized()
				walls.append({"deep": id.ends_with("_deep"), "at": t.origin,
					"out": out, "id": batch.ids[index]})
		var module := 2.0 * VillageWorldScale.scale_of(frame) \
			* FabricRecipe.CELL_SIZE / 2.0
		var storey := 2.0 * WarrenVolumePlan.VERTICAL_BAND_SIZE_M \
			* VillageWorldScale.vertical_scale_of(frame)
		var jogs: Array[String] = []
		for flush: Dictionary in walls:
			if flush.deep:
				continue
			for deep: Dictionary in walls:
				if not deep.deep or (flush.out as Vector3).dot(deep.out) < 0.99:
					continue
				var delta := (deep.at as Vector3) - (flush.at as Vector3)
				if absf(delta.dot(flush.out)) > 0.05:
					continue
				var along := Vector3(delta.x, 0.0, delta.z)
				var stacked := along.length() < 0.1 and absf(delta.y) <= storey + 0.1
				var beside := along.length() <= module + 0.1 and absf(delta.y) < 0.1
				if stacked or beside:
					jogs.append("%s | %s" % [flush.id, deep.id])
		assert_eq(jogs.size(), 0, "%s: masonry jogs %s" % [town.id, jogs.slice(0, 4)])


func test_gate_approach_flight_is_drawn_in_kit_timber() -> void:
	KitSubstitution.prepare(EnvironmentCatalog.load_default(), SuntailBuildingKit.create())
	var kit := SuntailBuildingKit.create()
	for turn in 4:
		var basis := Basis(Vector3.UP, turn * PI * 0.5)
		var source := WarrenTransitionSurfaceBuilder.build_gate_approach(&"gate",
			{"inner_centre": basis * Vector3(0.0, 1.5, 0.0),
			"stair_end": basis * Vector3(0.0, 0.0, 3.0),
			"outer_centre": basis * Vector3(0.0, 0.0, 6.0)})
		var drawn := KitSubstitution.redraw_public_surface(source)
		assert_eq(StringName(drawn.mesh.material_asset_id), kit.asset(&"deck.board"))
		assert_eq(drawn.mesh.collision_faces, source.collision_faces,
			"the gate's guard collision is kept")
		var rails := 0
		var posts := 0
		for rail: Dictionary in drawn.rails:
			rails += int(rail.asset_id == kit.asset(&"rail.low"))
			posts += int(rail.asset_id == kit.asset(&"rail.post"))
			# Posts stay plumb on the sheared rail.
			var up := (rail.transform as Transform3D).basis.y
			assert_almost_eq(Vector2(up.x, up.z).length(), 0.0, 0.0001)
		# Two sides x (flight span + landing span), each closed by one post.
		assert_eq(posts, 4, "turn %d: every rail span ends in a post" % turn)
		assert_gt(rails, 4, "turn %d: rails follow the flight and landing" % turn)
