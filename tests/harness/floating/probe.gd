extends SceneTree
## -- CITY PROFILE [12-float frame]: lists kit masses and retained components.
const USE := ["OUT", "ALLOC", "PUB_AIR", "DAY_AIR", "PRIV", "STRUCT", "SERVICE"]
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(int(a[0]), {}, program, WarrenVillageScaleProfile.for_id(StringName(a[1])))
	var fabric := spatial.compiled_fabric_cache()
	var frame := Transform3D()
	if a.size() > 2:
		var f := a[2].split(",")
		frame = Transform3D(Basis(Vector3(float(f[0]), float(f[1]), float(f[2])), Vector3(float(f[3]), float(f[4]), float(f[5])), Vector3(float(f[6]), float(f[7]), float(f[8]))), Vector3(float(f[9]), float(f[10]), float(f[11])))
	var grid := spatial.grid
	var env := spatial.source_volume.envelope
	var built := KitVillageBuildings.build(spatial, fabric, SuntailBuildingKit.create())
	for mass: BuildingMass in built.masses:
		var id := String(mass.stable_id)
		if id.begins_with("kit.retained") or id.begins_with("kit.tunnel") or id.contains("skywalk") or id.contains("support") or id.contains("balcony"):
			print("MASS ", id, " storeys=", mass.storeys.size(), " roofs=", mass.roofs.size(), " decks=", mass.decks.size(), " decor=", mass.decor.size())
			for s: Dictionary in mass.storeys:
				var c := Vector2.ZERO
				for cell: Vector2i in s.cells: c += Vector2(cell)
				c /= maxf(1, s.cells.size())
				var w := frame * (Vector3(c.x, s.floor_band, c.y) * 1.5)
				for cell: Vector2i in s.cells:
					print("      cell ", cell, " world ", (frame * (Vector3(cell.x, s.floor_band, cell.y) * 1.5)).snapped(Vector3.ONE * 0.1), " ", describe(grid, Vector3i(cell.x, s.floor_band, cell.y))) if id.begins_with("kit.tunnel") or (id.begins_with("kit.retained") and int(s.floor_band) >= 3) else null
				print("   storey band=", s.floor_band, " bands=", s.get("bands", 2), " n=", s.cells.size(), " mat=", s.material, " soffit=", s.get("soffit", false), " world~", w.snapped(Vector3.ONE * 0.1))
	# Retained components.
	var retained: Dictionary = fabric.retained_terrace_cells
	var seen := {}
	for start: Vector3i in retained:
		if seen.has(start): continue
		var comp: Array[Vector3i] = [start]
		seen[start] = true
		var i := 0
		while i < comp.size():
			var c := comp[i]; i += 1
			for d: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
				if retained.has(c + d) and not seen.has(c + d):
					seen[c + d] = true
					comp.append(c + d)
		var below := {}
		var above := {}
		var grounded := 0
		var lo := 1 << 20
		var hi := -(1 << 20)
		var centre := Vector3.ZERO
		for c: Vector3i in comp:
			centre += Vector3(c)
			lo = mini(lo, c.y); hi = maxi(hi, c.y)
			if not retained.has(c + Vector3i.DOWN):
				var macro := Vector2i(floori(c.x / 2.0), floori(c.z / 2.0))
				if env.contains_column(macro) and c.y <= env.bearing_at(macro):
					grounded += 1
				else:
					var u: String = USE[grid.use_at(c + Vector3i.DOWN)] if grid.contains(c + Vector3i.DOWN) else "NOGRID"
					below[u] = int(below.get(u, 0)) + 1
			if not retained.has(c + Vector3i.UP):
				var u2: String = USE[grid.use_at(c + Vector3i.UP)] if grid.contains(c + Vector3i.UP) else "NOGRID"
				var claim := grid.face_claim(c + Vector3i.UP, Vector3i.DOWN) if grid.contains(c + Vector3i.UP) else {}
				if not claim.is_empty(): u2 += "+floor"
				above[u2] = int(above.get(u2, 0)) + 1
		centre /= comp.size()
		var w := frame * (centre * 1.5)
		print("RET comp n=", comp.size(), " bands=", lo, "..", hi, " grounded_bottoms=", grounded, " below=", below, " above=", above, " world~", w.snapped(Vector3.ONE * 0.1))
	quit()

static func describe(grid: WarrenSpatialGrid, cell: Vector3i) -> String:
	var parts := []
	for d: Vector3i in [Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
		var n := cell + d
		parts.append("%s:%s/%s" % [d, USE[grid.use_at(n)] if grid.contains(n) else "NOGRID", grid.owner_name_at(n) if grid.contains(n) else ""])
	return "own=%s | %s" % [grid.owner_name_at(cell), " ".join(parts)]
