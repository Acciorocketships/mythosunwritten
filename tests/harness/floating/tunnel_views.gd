extends SceneTree
## -- CITY PROFILE [12-float frame] : kit_town_review --view args looking
## into every bored passage (street level, from the lane outside its mouth).
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var frame := Transform3D(Basis.from_scale(VillageWorldScale.frame_scale()), Vector3.ZERO)
	if a.size() > 2:
		var f := a[2].split(",")
		frame = Transform3D(Basis(Vector3(float(f[0]), float(f[1]), float(f[2])), Vector3(float(f[3]), float(f[4]), float(f[5])), Vector3(float(f[6]), float(f[7]), float(f[8]))), Vector3(float(f[9]), float(f[10]), float(f[11])))
	var source := WarrenMazeSitePlanner.plan(int(a[0]), {}, WarrenVillageScaleProfile.for_id(StringName(a[1])), &"", false)
	var centre := func(c: Vector3i) -> Vector3:
		return frame * Vector3((c.x * 2 + 1) * FabricRecipe.CELL_SIZE, c.y * WarrenVolumePlan.VERTICAL_BAND_SIZE_M, (c.z * 2 + 1) * FabricRecipe.CELL_SIZE)
	var index := 0
	var keys := source.excavation.tunnel_cells.keys()
	keys.sort()
	for walk: Vector3i in keys:
		for d: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var mouth := walk + Vector3i(d.x, 0, d.y)
			if not source.passage_kinds.has(mouth) or source.excavation.tunnel_cells.has(mouth):
				continue
			var along: Vector3 = (centre.call(walk) - centre.call(mouth)) * Vector3(1, 0, 1)
			var eye: Vector3 = centre.call(mouth) - along * 0.8 + Vector3.UP * 1.7
			var target: Vector3 = centre.call(walk) + Vector3.UP * 3.0
			print("VIEW --view t%d:%.2f,%.2f,%.2f:%.2f,%.2f,%.2f:75" % [index, eye.x, eye.y, eye.z, target.x, target.y, target.z], "  # ", walk)
			index += 1
			break
	quit()
