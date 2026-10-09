extends RefCounted
## Growing-floor corpus audit under step-in (spec Amendment 2 "Testing"): every count
## except `faces` must be 0.
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")
const CLEARANCE := preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")
const VIOLATIONS: Array[String] = ["outside_lot", "air_hits", "open_ends", "broken_joints",
	"braces_over_openings", "unbraced", "ledges", "roof_moved", "top_moved", "thin_bearing",
	"floating", "roof_intrusions"]
const ROOF_ROLES: Array[String] = ["roof.", "gable.", "trim.ridge", "trim.barge", "chimney."]


static func audit(spatial: WarrenSpatialPlan, fabric: SettlementFabricPlan, built: Dictionary,
		kit: BuildingKit, _character: TownCharacter) -> Dictionary:
	var catalog := EnvironmentCatalog.load_default()
	var air: Array[Dictionary] = []
	for wall: Dictionary in built.walls:
		if bool(wall.get("open", false)):
			air.append(wall)
	var houses: Array = built.houses
	var out := {"faces": 0}
	for key: String in VIOLATIONS:
		out[key] = 0
	var chains := {}
	for lean: Dictionary in built.growth:
		chains[String(lean.chain)] = true
	out.faces = chains.size()
	for mass: BuildingMass in houses:
		var records := (built.growth as Array).filter(func(l: Dictionary) -> bool: return l.host == mass.stable_id)
		if records.is_empty():
			continue
		var own_kit: BuildingKit = (built.house_kits as Dictionary).get(
			StringName(String(mass.stable_id).trim_prefix("kit.")), kit)
		var w := own_kit.module_width
		var grown := _architecture(mass, own_kit, houses)
		var plain := _without_growth(mass, own_kit, houses)
		var before := {}
		for part: Dictionary in plain:
			before["%s|%s" % [part.asset_id, part.transform]] = true
		var added := grown.filter(func(p: Dictionary) -> bool:
			return not before.has("%s|%s" % [p.asset_id, p.transform]))
		var box := func(p: Dictionary) -> AABB: return p.transform * catalog.descriptor(p.asset_id).measured_aabb
		for part: Dictionary in added:
			var b: AABB = box.call(part)
			if not _in_lot(mass, b.get_center(), own_kit):
				out.outside_lot += 1
			if CLEARANCE.intersects_air(catalog.descriptor(part.asset_id).measured_aabb, part.transform, air):
				out.air_hits += 1
		if _roof_parts(grown) != _roof_parts(plain) \
				or mass.roofs.any(func(r: Dictionary) -> bool: return r.has("lean_min") or r.has("lean_max")):
			out.roof_moved += 1
		for record: Dictionary in records:
			var storey: Dictionary = GROWTH._storey_at(mass, int(record.band))
			var y0 := float(record.band) * own_kit.band_height()
			var depth := float(record.lean)
			if depth > float(record.base) + 0.0001:
				# A brace of this face reaches out along its normal (the other face's brace at
				# an inside corner also falls in the grown bounds: Task 10 audit fix).
				var normal_x := int(record.dir) % 2 == 0
				var under := added.filter(func(p: Dictionary) -> bool:
					var b: AABB = box.call(p)
					return String(p.role).begins_with("bracket.") and b.end.y >= y0 - 0.3 and b.end.y <= y0 + 0.01 \
						and (b.size.x > b.size.z) == normal_x \
						and (record.bounds as AABB).grow(0.3).has_point(b.get_center()))
				if under.size() < maxi(1, (record.edges as Array).size() - 1):
					out.unbraced += 1
				# Each brace stands on a wall-module joint (a multiple of the module along
				# the face), never over a window or door head.
				for brace: Dictionary in under:
					var c: Vector3 = (box.call(brace) as AABB).get_center()
					var along := c.z if int(record.dir) % 2 == 0 else c.x
					if absf(along / w - roundf(along / w)) * w > 0.2:
						out.braces_over_openings += 1
			if depth < 0.0:
				out.open_ends += _open_ends(record, storey, added, box, own_kit)
				out.thin_bearing += 0 if _bears(storey, record, own_kit) else 1
		out.top_moved += _tops_moved(mass, records)
		out.ledges += _ledges(mass, grown, box, own_kit)
	out.broken_joints = _broken_joints(built.growth)
	out.floating = KitFloatingMassAudit.audit(spatial, fabric, built.masses).count
	out.roof_intrusions = preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built, kit).intrusions
	return out


## The house's architecture (dressing set aside) as the town assembles it.
static func _architecture(mass: BuildingMass, kit: BuildingKit, houses: Array) -> Array[Dictionary]:
	var assembler := BuildingKitAssembler.new(kit)
	assembler.external_blocked = func(cell: Vector2i, band: int) -> bool:
		for other: BuildingMass in houses:
			if other != mass and other.cells_at_band(band).has(cell):
				return true
		return false
	var decor := mass.decor.duplicate()
	mass.decor.clear()
	var parts := assembler.assemble(mass)
	mass.decor.assign(decor)
	return parts


## The same with its growth taken out again (negative offsets and growth records).
static func _without_growth(mass: BuildingMass, kit: BuildingKit, houses: Array) -> Array[Dictionary]:
	var saved := []
	for storey: Dictionary in mass.storeys:
		saved.append([storey.get("wall_offsets"), storey.get("projections")])
		var offsets: Dictionary = (storey.get("wall_offsets", {}) as Dictionary).duplicate()
		for edge: Vector3i in offsets.keys():
			if float(offsets[edge]) < 0.0:
				offsets.erase(edge)
		storey["wall_offsets"] = offsets
		storey["projections"] = (storey.get("projections", []) as Array).filter(
			func(p: Dictionary) -> bool: return not bool(p.get("growth", false)))
	var parts := _architecture(mass, kit, houses)
	for index in mass.storeys.size():
		var storey: Dictionary = mass.storeys[index]
		for slot in 2:
			var key := "wall_offsets" if slot == 0 else "projections"
			if saved[index][slot] == null:
				storey.erase(key)
			else:
				storey[key] = saved[index][slot]
	return parts


static func _roof_parts(parts: Array) -> Array:
	var out := parts.filter(func(p: Dictionary) -> bool:
		return ROOF_ROLES.any(func(prefix: String) -> bool: return String(p.role).begins_with(prefix))).map(
		func(p: Dictionary) -> String: return "%s %s" % [p.asset_id, p.transform])
	out.sort()
	return out


## Inside the house's own cells (any storey), within the wall face plus touching contact.
static func _in_lot(mass: BuildingMass, point: Vector3, kit: BuildingKit) -> bool:
	var w := kit.module_width
	for storey: Dictionary in mass.storeys:
		for cell: Vector2i in storey.cells:
			if Rect2(Vector2(cell) * w, Vector2(w, w)).grow(kit.wall_face + GROWTH.TOUCH).has_point(Vector2(point.x, point.z)):
				return true
	return false


## Ends of one stepped-in storey record left open: a `return` or `wrap` end whose
## perpendicular corner panel still stands whole, or a `bury` / `abut` end without its strip.
static func _open_ends(record: Dictionary, storey: Dictionary, added: Array, box: Callable, kit: BuildingKit) -> int:
	var dir := int(record.dir)
	var right := BuildingKitAssembler.right_of(dir)
	var edges: Array = record.edges
	var sorted := edges.duplicate()
	sorted.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return Vector2(a.x, a.y).dot(Vector2(right)) < Vector2(b.x, b.y).dot(Vector2(right)))
	var bad := 0
	var slots := BuildingKitAssembler.storey_slots(storey)
	for side in 2:
		var kind := StringName((record.closures as Array)[side])
		var end: Vector3i = sorted.front() if side == 0 else sorted.back()
		var cell := Vector2i(end.x, end.y)
		var outward := right * (-1 if side == 0 else 1)
		if kind in [&"return", &"wrap"]:
			var corner := BuildingMass.edge_key(cell, BuildingMass.DIRS.find(outward))
			for slot: Dictionary in slots:
				if slot.edge == corner and float(slot.get("short", 0.0)) <= 0.0 and not bool(slot.get("dropped", false)):
					bad += 1
		elif kind in [&"bury", &"abut"]: # an abut end closes with the same strip, on the party plane
			# The strip stands on the vertex line, half the inset inside the lot line.
			var corner := (Vector2(cell) + Vector2.ONE * 0.5 + Vector2(BuildingMass.DIRS[dir]) * 0.5 \
				+ Vector2(outward) * 0.5) * kit.module_width
			var expected := corner - Vector2(BuildingMass.DIRS[dir]) * (-float(record.lean)) * 0.5
			var suffix := BuildingKitAssembler.lean_suffix(-float(record.lean))
			var strip := added.any(func(p: Dictionary) -> bool:
				var c: Vector3 = (box.call(p) as AABB).get_center()
				return String(p.role) == "frontage.return." + suffix and Vector2(c.x, c.z).distance_to(expected) < 0.6)
			if not strip:
				bad += 1
	return bad


## Bearing: behind every stepped-in edge at least one module of floor remains, two
## across an axis stepped in from both sides.
static func _bears(storey: Dictionary, record: Dictionary, kit: BuildingKit) -> bool:
	var dir := int(record.dir)
	var inward: Vector2i = -BuildingMass.DIRS[dir]
	var back := (dir + 2) % 4
	var offsets: Dictionary = storey.get("wall_offsets", {})
	for edge: Vector3i in record.edges:
		var far := Vector2i(edge.x, edge.y)
		var modules := 1
		while (storey.cells as Dictionary).has(far + inward):
			far += inward
			modules += 1
		var opposite := minf(0.0, float(offsets.get(BuildingMass.edge_key(far, back), 0.0))) * kit.module_width
		var keep := float(modules) * kit.module_width + float(record.lean) + opposite
		if keep < (2.0 if opposite < 0.0 else 1.0) * kit.module_width - 0.0001:
			return false
	return true


## A stepping face whose highest storey is not on its lot line.
static func _tops_moved(mass: BuildingMass, records: Array) -> int:
	var bad := 0
	var dirs := {}
	for record: Dictionary in records:
		dirs[int(record.dir)] = true
	for dir: int in dirs:
		var top := {}
		for storey: Dictionary in mass.storeys:
			if (storey.get("growth", {}) as Dictionary).has(dir) \
					and (top.is_empty() or int(storey.floor_band) > int(top.floor_band)):
				top = storey
		if not top.is_empty() and float(top.growth[dir]) != 0.0:
			bad += 1
	return bad


## A whole board on an upper storey's cell whose edge stands in (a floor ledge
## outside its wall).
static func _ledges(mass: BuildingMass, parts: Array, box: Callable, kit: BuildingKit) -> int:
	var bad := 0
	for part: Dictionary in parts:
		if part.role != &"deck.board":
			continue
		var c: Vector3 = (box.call(part) as AABB).get_center()
		var storey: Dictionary = GROWTH._storey_at(mass, roundi(c.y / kit.band_height()))
		if storey.is_empty() or int(storey.floor_band) <= mass.ground_band:
			continue
		var cell := Vector2i(floori(c.x / kit.module_width), floori(c.z / kit.module_width))
		var offsets: Dictionary = storey.get("wall_offsets", {})
		for dir in 4:
			if float(offsets.get(BuildingMass.edge_key(cell, dir), 0.0)) < 0.0:
				bad += 1
				break
	return bad


## A joint whose partner (another house, same dir, band and offset, joint closure) is missing.
static func _broken_joints(growth: Array) -> int:
	var bad := 0
	for lean: Dictionary in growth:
		if not (lean.closures as Array).has(&"joint"):
			continue
		var partner := growth.any(func(other: Dictionary) -> bool:
			return other.host != lean.host and int(other.dir) == int(lean.dir) \
				and int(other.band) == int(lean.band) and (other.closures as Array).has(&"joint") \
				and absf(float(other.lean) - float(lean.lean)) < 1e-6)
		if not partner:
			bad += 1
	return bad
