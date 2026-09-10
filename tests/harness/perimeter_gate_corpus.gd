extends SceneTree

# Inspect completed construction across town scales and all road orientations.
# No result here participates in runtime generation.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var terrain := VillageTerrainView.from_region(HeightfieldRegion.new({}, {}))
	var failures := 0
	var count := 0
	var seeds: Array[int] = [1]
	var args := OS.get_cmdline_user_args()
	for index in args.size()-1:
		if args[index]=="--seeds":
			seeds.clear()
			for value: String in args[index+1].split(","): seeds.append(int(value))
	for seed_value: int in seeds:
		for scale_id: StringName in WarrenVillageScaleProfile.IDS:
			var profile := WarrenVillageScaleProfile.for_id(scale_id)
			var spatial := WarrenVolumetricSolver.generate(seed_value, {},
				program.villages.settlement_fabric_program, profile)
			if spatial == null:
				failures += 1
				print("PERIMETER_GATE_FAILURE seed=",seed_value," scale=",scale_id," source=",WarrenVolumetricSolver.last_failure)
				continue
			for quarter in 4:
				var axis := Vector2.DOWN.rotated(quarter*PI*0.5).round()
				var arrival := Vector2(264,288)
				var placement := VillageWarrenFabricSolver._placement(terrain,spatial,arrival,axis)
				placement.local_bounds = VillageWarrenFabricSolver._local_bounds(spatial.compiled_fabric_cache())
				var urban := VillageWarrenFabricSolver._materialize(terrain,&"perimeter-corpus",
					spatial,spatial.compiled_fabric_cache(),placement,program.villages,2697992464)
				var outskirts := VillageOutskirtsConstruction.generate(terrain.with_terrain_grades(
					[urban.terrain_grade]),&"perimeter-corpus",arrival,axis,&"village",&"blue",
					program.villages,urban,null)
				var physical: Array[VillageOccupancyVolume] = []
				for volume: VillageOccupancyVolume in urban.volumes:
					if volume.role != VillageOccupancy.Role.GROUND_EXCLUSIVE: physical.append(volume)
				var errors := PackedStringArray()
				var conflict := VillageOccupancy.first_cross_conflict(outskirts.volumes,physical)
				if not conflict.is_empty(): errors.append("town/lane conflict: "+str(conflict))
				if not outskirts.validate(program.villages.outskirts_program,&"village"):
					errors.append("outskirts validation")
				for street: Dictionary in outskirts.street_paths:
					if not String(street.owner).contains(".gate."): continue
					var points := street.points as Array[Vector2]
					if points.size()!=2: errors.append("gate is not straight")
					for segment in range(1,points.size()):
						var delta := points[segment]-points[segment-1]
						if absf(delta.x)>0.001 and absf(delta.y)>0.001:
							errors.append("diagonal gate")
				count += 1
				failures += int(not errors.is_empty())
				print("PERIMETER_GATE seed=",seed_value," scale=",scale_id," quarter=",quarter,
					" houses=",outskirts.placements.size()," errors=",errors)
	print("PERIMETER_GATE count=",count," failures=",failures)
	quit(int(failures>0))
