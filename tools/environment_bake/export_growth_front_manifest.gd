extends SceneTree
## Adds the growing-floor depth family to town_room_fronts.json: one floor strip,
## return and return beam per cumulative lean (KitGrowingFronts.LEAN_DEPTHS).
## Each source is measured; a depth is cut from the narrowest source at least that
## wide (never scaled). Existing entries are kept; regenerated entries replaced.
## godot --headless --editor --path . -s res://tools/environment_bake/export_growth_front_manifest.gd
const MANIFEST := "res://tools/environment_bake/manifests/town_room_fronts.json"
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")
const FLOOR := "res://assets/Raygeas/Models/Building_Modules/Indoor_Modules/Floor_2.glb"
const BEAM := "res://assets/Raygeas/Models/Building_Modules/Decor/Crossbar_2.glb"
## Pure Village wall starts, finished at x = 0 and extending toward -x.
const RETURNS: Array[String] = ["res://assets/PureVillage/Models/Architecture/Wall_Start_10x30_0.glb",
	"res://assets/PureVillage/Models/Architecture/Wall_Start_20x30_0.glb"]


func _init() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var template := {}
	var kept: Array = []
	var family := RegEx.create_from_string("\\.d\\d{3}$")
	for entry: Dictionary in manifest.assets:
		template[String(entry.id)] = entry
		if family.search(String(entry.id)) == null:
			kept.append(entry)
	for depth: float in GROWTH.LEAN_DEPTHS:
		var suffix := BuildingKitAssembler.lean_suffix(depth)
		var half := depth * 0.5
		kept.append(_entry(template["town.frontage.floor"], "town.frontage.floor." + suffix,
			FLOOR, "z", half, false))
		kept.append(_entry(template["town.frontage.return_beam"], "town.frontage.return_beam." + suffix,
			BEAM, "x", half, false))
		var source := ""
		for candidate: String in RETURNS:
			if source.is_empty() and _extent(candidate).size.x >= depth - 0.0001:
				source = candidate
		assert(not source.is_empty(), "no Pure Village wall start is %.2f m wide" % depth)
		kept.append(_entry(template["town.frontage.return"], "town.frontage.return." + suffix,
			source, "x", half, true))
	manifest.assets = _ints(kept)
	var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  ", false) + "\n")
	file.close()
	print("GROWTH_FRONTS ", GROWTH.LEAN_DEPTHS.size() * 3)
	quit()


## Copy budgets, tags and collision from the 0.65 m entry; clip only when the
## depth is narrower than the source (a full-width clip would remove nothing).
func _entry(template: Dictionary, id: String, source: String, axis: String, half: float,
		pivoted: bool) -> Dictionary:
	var entry := template.duplicate(true)
	entry.id = id
	entry.source = source
	var extent := _extent(source)
	var index := 0 if axis == "x" else 2
	var width := extent.size[index]
	entry.erase("clip_ranges")
	entry.erase("pivot")
	if pivoted:
		entry.pivot = [-half, 0.0, 0.0]
	if half * 2.0 < width - 0.0001:
		entry.clip_ranges = {axis: [-half, half]}
	return entry


func _extent(path: String) -> AABB:
	var root: Node3D = (load(path) as PackedScene).instantiate()
	var boxes: Array[AABB] = []
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var xf: Transform3D = item[1]
		if node is Node3D:
			xf = xf * (node as Node3D).transform
		if node is MeshInstance3D:
			boxes.append(xf * (node as MeshInstance3D).get_aabb())
		for child in node.get_children():
			stack.append([child, xf])
	var box: AABB = boxes[0]
	for other: AABB in boxes:
		box = box.merge(other)
	root.free()
	return box


## JSON parsing yields floats; keep whole numbers as integers so existing
## entries stay textually unchanged.
func _ints(value: Variant) -> Variant:
	if value is float and is_equal_approx(value, roundf(value)) and absf(value) >= 1.0 or value is float and value == 0.0:
		return int(value)
	if value is Array:
		return (value as Array).map(_ints)
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[key] = _ints(value[key])
		return out
	return value
