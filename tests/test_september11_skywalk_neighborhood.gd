extends GutTest

func test_photo_skywalks_join_existing_upper_neighborhood_mass() -> void:
	var source := WarrenMazeSitePlanner.plan(8922681140531148375,{},
		WarrenVillageScaleProfile.for_id(&"compact"))
	assert_not_null(source)
	if source == null: return
	assert_gt(source.excavation.bridge_spans.size(),0,"Connected skywalk opportunities must survive")
	_assert_neighborhood(source, "endpoint_groups")

func test_all_tiers_keep_connected_skywalks_after_public_columns_open() -> void:
	var spans := 0
	for scale_id: StringName in [&"compact",&"standard",&"large",&"grand"]:
		for seed_value in range(1,13):
			var source := WarrenMazeSitePlanner.plan(seed_value,{},
				WarrenVillageScaleProfile.for_id(scale_id))
			assert_not_null(source)
			if source == null: continue
			assert_true(source.validate_construction(),source.last_rejection)
			spans += source.excavation.bridge_spans.size()
			_assert_neighborhood(source,"endpoint_foundation_groups")
	assert_gt(spans,0,"The policy preserves legal neighborhood links across the corpus")
	print("NEIGHBORHOOD_SPANS ",spans)

func _assert_neighborhood(source: WarrenMazeSourcePlan, group_key: String) -> void:
	for proof: Dictionary in source.excavation.bridge_span_audit.seeded:
		var own_columns: Dictionary = {}
		for cell: Vector3i in proof.cells: own_columns[Vector2i(cell.x,cell.z)] = true
		for group: Array in proof.endpoint_foundation_groups:
			for col: Vector2i in group: own_columns[col] = true
		for group: Array in proof[group_key]:
			var neighboring_wall := false
			for col: Vector2i in group:
				for direction: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var near := col+direction
					if own_columns.has(near): continue
					var complete := true
					for band in range(int(proof.floor)-WarrenBuildingParcel.STOREY_BANDS,int(proof.floor)):
						complete = complete and source.massif.has_column(near) and source.massif.top_at(near)>band and not source.excavation.carved.has(Vector3i(near.x,band,near.y))
					neighboring_wall = neighboring_wall or complete
			assert_true(neighboring_wall,"Endpoint %s at %d cannot invent an isolated tower above its neighborhood" % [group,proof.floor])
