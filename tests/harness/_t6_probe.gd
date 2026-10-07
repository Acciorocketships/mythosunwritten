extends SceneTree
func _init() -> void:
	var p := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	p.town_odds = p.town_odds.with_overrides({&"satellite_reach_scale":0.6,&"suburb_house_count":4.0,&"lone_house_path_chance":0.0})
	var s := WarrenVolumetricSolver.generate(53, {}, p, WarrenVillageScaleProfile.for_id(&"grand"))
	var src: WarrenMazeSourcePlan = s.source_volume.mass_context.get(&"maze_source_plan")
	var public := {}
	for c in src.excavation.public_cells(): public[c] = true
	var owners := {}
	for l in src.excavation.lanes:
		for c in l.cells: owners[c] = l.get("feature_kind")
	for c in src.excavation.route: owners[c] = &"route"
	for l in src.excavation.lanes:
		if not String(l.get("feature_kind")).begins_with("house_site"): continue
		var a: Vector3i = l.anchor
		var nb := []
		for d in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			if public.has(a+d): nb.append([a+d, owners.get(a+d, &"?")])
		print("LANE ", l.feature_kind, " cells=", l.cells, " anchor=", a, " anchor_owner=", owners.get(a, &"?"), " nbrs=", nb)
	var surf := s.compiled_fabric_cache().surface_plan
	print("FOOT ", surf.footway_columns.size(), " streets=", surf.cells_for_kind(PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET).size(), " painted=", surf.painted_street_cells().size())
	quit()
