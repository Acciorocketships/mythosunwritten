extends SceneTree
const OUT := "res://docs/qa/2026-09-19-manual/133-cliff-root-contact"
const ROCKS = preload("res://scripts/terrain/field/CliffRockDressing.gd")
func _init() -> void: run.call_deferred()
func run() -> void:
	ROCKS.prepare()
	var hydraulic := TerrainWorldTuning.make_water(2697992464)
	var fields := WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,hydraulic),hydraulic,26,0,8)
	var region := fields.region(Vector2i(-3,1))
	var water := fields.water(Vector2i(-3,1))
	var sources: Array = FileAccess.open("res://docs/qa/2026-09-19-manual/122-bank-attachments/sources.bin",FileAccess.READ).get_var()
	var previous: Array = FileAccess.open("res://docs/qa/2026-09-19-manual/122-bank-attachments/source-plants.bin",FileAccess.READ).get_var()
	var proposals := ROCKS.plants(sources,region,2697992464,null,null,sources)
	FileAccess.open(OUT.path_join("source-plants.bin"),FileAccess.WRITE).store_var(proposals)
	var old_by_id: Dictionary = {}
	var new_by_id: Dictionary = {}
	var added: Array = []
	var removed: Array = []
	var changed: Array = []
	for plant: Dictionary in previous: old_by_id[plant.id] = plant
	for plant: Dictionary in proposals:
		new_by_id[plant.id] = plant
		if not old_by_id.has(plant.id): added.append(plant.id)
		elif plant.transform!=old_by_id[plant.id].transform: changed.append(plant.id)
	for id: String in old_by_id:
		if not new_by_id.has(id): removed.append(id)
	var banks: Array = FileAccess.open("res://docs/qa/2026-09-19-manual/132-bank-source-shapes/validated-banks.bin",FileAccess.READ).get_var()
	var owned: Dictionary = {}
	for bank: Dictionary in banks: owned[bank.id] = bank
	var plants: Array = []
	for plant: Dictionary in proposals:
		if not owned.has(plant.support_id): continue
		var point: Vector3 = plant.support_point
		if point.y<float(owned[plant.support_id].replay_recipe.shore_level)+.3: continue
		var level := water.level_at(Vector2(point.x,point.z))
		if is_finite(level) and level>point.y-.3: continue
		plants.append(plant)
	FileAccess.open(OUT.path_join("plants.bin"),FileAccess.WRITE).store_var(plants)
	var report := {"before":previous.size(),"after":proposals.size(),"bank_plants":plants.size(),"added":added,"removed":removed,"changed_poses":changed}
	FileAccess.open(OUT.path_join("selection.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CLIFF_ROOT_SELECTION ",report)
	quit(0 if changed.is_empty() else 1)
