extends SceneTree
## Distinguish route-bearing crown rooms from optional architectural attachments.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var cities := args[args.find("--cities")+1] if args.has("--cities") else "63:grand"
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var output := {}
	for city: String in cities.split(","):
		var key := city.split(":")
		var spatial := WarrenVolumetricSolver.generate(int(key[0]),{},program,WarrenVillageScaleProfile.for_id(StringName(key[1])))
		assert(spatial!=null,WarrenVolumetricSolver.last_failure)
		var houses := KitVillageBuildings._houses(spatial)
		var rows := []
		for id: StringName in KitVillageBuildings.sorted_ids(houses.keys()):
			var house: Dictionary = houses[id]
			if house.storeys.size()<4:continue
			var bands: Array = house.storeys.keys()
			bands.sort()
			var top := int(bands.back())
			var upper := {}
			for cell: Vector3i in house.cells:
				if cell.y>=top:upper[cell]=true
			var public_contacts := []
			var coverage := []
			for cell: Vector3i in upper:
				for step: Vector3i in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK,Vector3i.UP]:
					var at := cell+step
					if spatial.grid.use_at(at)==WarrenSpatialGrid.Use.PUBLIC_AIR:public_contacts.append(at)
				if cell.y!=top:continue
				for band in range(top-1,-1,-1):
					var at:=Vector3i(cell.x,band,cell.z)
					if house.cells.has(at):break
					if spatial.compiled_fabric_cache().surface_plan.has_cell(at):
						coverage.append({"cell":at,"distance":top-band})
						break
			var plinth_columns := {}
			var source: WarrenMazeSourcePlan = spatial.source_volume.mass_context[&"maze_source_plan"]
			for cell: Vector3i in house.cells:
				var column := Vector2i(floori(cell.x/2.0),floori(cell.z/2.0))
				plinth_columns[column] = source.massif.plinth_at(column)
			var doors := []
			for door: Dictionary in house.doors:
				if upper.has(door.cell):doors.append(door)
			var features := []
			for feature: WarrenFeatureReservation in spatial.features:
				var touches := false
				for cell: Vector3i in feature.reserved_cells:
					for step: Vector3i in [Vector3i.ZERO,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK,Vector3i.UP,Vector3i.DOWN]:
						if upper.has(cell+step):touches=true
				if touches:features.append({"id":feature.stable_id,"kind":feature.kind,"endpoints":feature.endpoints,"audit":feature.audit})
			rows.append({"id":id,"plinth_columns":plinth_columns,"bands":bands,"upper_cells":upper.keys(),"public_contacts":public_contacts,"doors":doors,"over_walks":coverage,"features":features})
		output[city]=rows
	FileAccess.open(args[args.find("--output")+1],FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	quit()
