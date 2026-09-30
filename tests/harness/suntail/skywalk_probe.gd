extends SceneTree
## Lists every bridge-house / skywalk of a town with the fine-cell and
## production-world coordinates of its body, and what stands at each end.
##   Godot --headless --path . -s res://tests/harness/suntail/skywalk_probe.gd -- \
##     CITY:PROFILE [FRAME_ORIGIN_X,Y,Z]
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var job := args[0].split(":")
	var origin := Vector3.ZERO
	if args.size() > 1:
		var o := args[1].split(",")
		origin = Vector3(float(o[0]), float(o[1]), float(o[2]))
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var profile := WarrenVillageScaleProfile.for_id(StringName(job[1]))
	var source := WarrenMazeSitePlanner.plan(int(job[0]), {}, profile, &"", false)
	var spatial := FROZEN.spatial(source, program)
	var fabric := spatial.compiled_fabric_cache()
	var grid := spatial.grid
	var to_world := func(fine: Vector3) -> Vector3:
		# Production frame at yaw 0 (see town_frame.gd): local x -> +Z, local z -> -X.
		var local := Vector3(fine.x * 1.5, fine.y * 1.5, fine.z * 1.5)
		return origin + Vector3(-local.z * 8.0 / 3.0, local.y * 2.0, local.x * 8.0 / 3.0)
	print("SOURCE_BRIDGES ", source.excavation.bridge_spans)
	for building: WarrenBuildingVolume in spatial.buildings:
		var id := String(building.stable_id)
		if not id.contains("bridge"):
			continue
		var lo := Vector3i(1 << 20, 1 << 20, 1 << 20)
		var hi := -lo
		for c: Vector3i in building.private_cells:
			lo = Vector3i(mini(lo.x, c.x), mini(lo.y, c.y), mini(lo.z, c.z))
			hi = Vector3i(maxi(hi.x, c.x), maxi(hi.y, c.y), maxi(hi.z, c.z))
		print("BRIDGE_BUILDING ", id, " cells=", building.private_cells.size(),
			" lo=", lo, " hi=", hi, " world_lo=", to_world.call(Vector3(lo)),
			" world_hi=", to_world.call(Vector3(hi) + Vector3.ONE))
	var k := 0
	for span: Dictionary in SettlementFabricAssembler.maze_skywalk_spans(fabric):
		var c := span.cell as Vector3i
		var step := span.step as Vector3i
		var far := c + step * (int(span.gap) + 1)
		print("SKYWALK ", k, " ", span, " far=", far,
			" world_near=", to_world.call(Vector3(c)), " world_far=", to_world.call(Vector3(far)))
		for end: Vector3i in [c, far]:
			var uses := []
			for dy in range(0, 3):
				var p := end + Vector3i.UP * dy
				uses.append(grid.use_at(p) if grid.contains(p) else -1)
			print("   end ", end, " uses(y..y+2)=", uses)
		k += 1
	for feature: WarrenFeatureReservation in spatial.features:
		print("FEATURE ", feature.stable_id, " kind=", feature.kind)
	quit()
