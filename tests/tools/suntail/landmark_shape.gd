extends SceneTree
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var source := WarrenMazeSitePlanner.plan(12, {}, WarrenVillageScaleProfile.for_id(&"compact"), &"", false)
	var spatial := FROZEN.spatial(source, program)
	for f: WarrenFeatureReservation in spatial.features:
		if f.kind != &"prefab_landmark": continue
		var bands := {}
		for c in f.reserved_cells: bands[c.y] = int(bands.get(c.y, 0)) + 1
		print(f.stable_id, " bands=", bands)
		var base := 999
		for c in f.reserved_cells: base = mini(base, c.y)
		var xs := []; var zs := []
		for c in f.reserved_cells:
			if c.y == base: xs.append(c.x); zs.append(c.z)
		var x0: int = xs.min(); var z0: int = zs.min()
		for z in range(z0, int(zs.max()) + 1):
			var row := ""
			for x in range(x0, int(xs.max()) + 1):
				row += "#" if f.reserved_cells.has(Vector3i(x, base, z)) else "."
			print("  ", row)
	quit()
