extends SceneTree
## -- CITY:PROFILE,... : covered bored-passage length per town.
## tunnels = source bored walk cells; covered = those whose four fine columns
## each carry construction (a room, carried stone, a bridge-house or deck)
## within three bands above the headroom slot. under = every walked fine cell
## with construction in the four bands above its two-band headroom.
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var totals := Vector3i.ZERO
	for job in OS.get_cmdline_user_args()[0].split(","):
		var parts := job.split(":")
		var spatial := WarrenVolumetricSolver.generate(int(parts[0]), {}, program, WarrenVillageScaleProfile.for_id(StringName(parts[1])))
		if spatial == null:
			print("COVERED ", job, " FAILED ", WarrenVolumetricSolver.last_failure)
			continue
		var fabric := spatial.compiled_fabric_cache()
		var built := KitVillageBuildings.build(spatial, fabric, SuntailBuildingKit.create())
		var grid := spatial.grid
		var occupied: Dictionary = {}
		for use: int in [WarrenSpatialGrid.Use.PRIVATE_VOLUME, WarrenSpatialGrid.Use.STRUCTURAL_VOLUME]:
			for cell: Vector3i in grid.cells_with_use(use):
				occupied[cell] = true
		for mass: BuildingMass in built.masses:
			for storey: Dictionary in mass.storeys:
				for band in range(int(storey.floor_band), int(storey.floor_band) + int(storey.get("bands", 2))):
					for c: Vector2i in storey.cells:
						occupied[Vector3i(c.x, band, c.y)] = true
			for deck: Dictionary in mass.decks:
				for c: Vector2i in deck.cells:
					occupied[Vector3i(c.x, int(deck.band) - 1, c.y)] = true
		var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
		var tunnels := 0
		var covered := 0
		for walk: Vector3i in source.excavation.tunnel_cells:
			tunnels += 1
			var roof := source.passage_headroom_top(walk)
			var all := true
			for fine: Vector3i in WarrenVolumetricSolver._fine_square(Vector3i(walk.x, roof, walk.z)):
				var hit := false
				for dy in 3:
					hit = hit or occupied.has(fine + Vector3i.UP * dy)
				all = all and hit
			covered += int(all)
		var under := 0
		for floor_cell: Vector3i in spatial.route_floor_cells:
			var hit := false
			for dy in range(2, 6):
				hit = hit or occupied.has(floor_cell + Vector3i.UP * dy)
			under += int(hit)
		totals += Vector3i(tunnels, covered, under)
		print("COVERED ", job, " tunnels=", tunnels, " covered=", covered, " walks_under=", under, "/", spatial.route_floor_cells.size())
	print("COVERED_TOTAL tunnels=", totals.x, " covered=", totals.y, " walks_under=", totals.z)
	quit()
