extends SceneTree
## ASCII massif layer map with crown (C) and primary portal (P):
##   godot --headless --path . -s res://tests/harness/layout_judging/massif_map.gd -- SEED PROFILE
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var profile := WarrenVillageScaleProfile.for_id(StringName(args[1]))
	var massif := WarrenMassifBuilder.build(int(args[0]), {}, profile)
	var crown := WarrenMazeCarver.crown_of(massif)
	var market_cells := clampi(profile.radius_cells - 2, 4, 7)
	var portals := WarrenMazeCarver._portal_cells(massif, market_cells, int(args[0]))
	print("CROWN ", crown, " portals=", portals.slice(0, 3), " core=", massif.core_top_bands)
	var lo := Vector2i(999, 999)
	var hi := Vector2i(-999, -999)
	for c: Vector2i in massif.columns:
		lo = lo.min(c)
		hi = hi.max(c)
	for z in range(lo.y, hi.y + 1):
		var line := ""
		for x in range(lo.x, hi.x + 1):
			var c := Vector2i(x, z)
			if Vector2(c) == crown: line += " C"
			elif not portals.is_empty() and Vector2i(portals[0].x, portals[0].z) == c: line += " P"
			elif massif.has_column(c): line += "%2d" % massif.layer_at(c)
			else: line += " ."
		print("MAP ", line)
	quit()
