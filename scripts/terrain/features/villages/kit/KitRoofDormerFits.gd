extends RefCounted
## A dormer is a complete opening, never a window cut by public headroom.
## Retain clear bays first, then move obstructed dormers to the nearest clear
## non-edge bay while preserving the designer's two-bay spacing.
const CONTACTS := preload("res://scripts/terrain/features/villages/kit/KitFacadeRoofContacts.gd")
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")

static func fit(roofs: Array[Dictionary], base: BuildingKit, roof_kits: Dictionary,
		walls: Array[Dictionary]) -> Dictionary:
	var result := {"moved":0,"omitted":0,"checked":0}
	var openings: Dictionary = FileAccess.open(CONTACTS.OPENINGS,FileAccess.READ).get_var()
	var geometry := {}
	var loaded := {}
	UNION._load_geometry(base,geometry,loaded)
	var public: Array[Dictionary] = []
	for wall:Dictionary in walls:
		if bool(wall.get("open",false)): public.append(wall)
	var volumes: Array[Dictionary] = []
	for i in roofs.size(): volumes.append(UNION.roof_volume(roofs[i],roof_kits.get(i,base)))
	for i in roofs.size():
		var wing: Dictionary = roofs[i]
		if wing.dormers.is_empty(): continue
		var kit: BuildingKit = roof_kits.get(i,base)
		UNION._load_geometry(kit,geometry,loaded)
		var cutters := walls.duplicate()
		for j in roofs.size():
			if j != i: cutters.append(volumes[j])
		var context := {"volumes":cutters,"openings":openings,"geometry":geometry,"public":public}
		var keys: Array = wing.dormers.keys()
		keys.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return a.x<b.x or (a.x==b.x and a.y<b.y))
		var kept := {}
		var pending: Array[Vector2i] = []
		for key: Vector2i in keys:
			result.checked += 1
			if _clear(wing,key,kit,context): kept[key] = true
			else: pending.append(key)
		var rect: Rect2i = wing.rect
		var axis := int(wing.axis)
		for old: Vector2i in pending:
			var choices: Array[Vector2i] = []
			for side in 2:
				for p in range(rect.position[axis]+1,rect.end[axis]-1): choices.append(Vector2i(side,p))
			choices.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
				var da := absi(a.y-old.y)+int(a.x!=old.x)*rect.size[axis]
				var db := absi(b.y-old.y)+int(b.x!=old.x)*rect.size[axis]
				return da<db or (da==db and (a.x<b.x or (a.x==b.x and a.y<b.y))))
			var found := false
			for candidate in choices:
				var spaced := true
				for other: Vector2i in kept:
					if candidate.x==other.x and absi(candidate.y-other.y)<2: spaced = false
				if not spaced or not _clear(wing,candidate,kit,context): continue
				kept[candidate] = true
				result.moved += 1
				found = true
				break
			if not found: result.omitted += 1
		wing.dormers = kept
	return result

static func _clear(wing: Dictionary, key: Vector2i, kit: BuildingKit, context: Dictionary) -> bool:
	var axis := int(wing.axis)
	var rect: Rect2i = wing.rect
	var dir := (1 if axis==0 else 0) if key.x==0 else (3 if axis==0 else 2)
	var along := float(key.y)+(0.5 if kit.roof_edge_caps else 0.0)
	var across := float(rect.end[1-axis] if key.x==0 else rect.position[1-axis])
	var point := Vector2(along,across) if axis==0 else Vector2(across,along)
	var tight := bool(BuildingKitAssembler.tight_eave_sides(wing) & (1 << key.x))
	var role := StringName("roof.%s.%s" % [wing.colour,"eave_tight_dormer" if tight else "eave_dormer"])
	var asset := kit.asset(role)
	if asset.is_empty(): return false
	var pose := Transform3D(Basis(Vector3.UP,BuildingKitAssembler.yaw_for_dir(dir)),
		Vector3(point.x*kit.module_width,float(wing.eave_band)*kit.band_height(),point.y*kit.module_width))*kit.anchor(role)*kit.asset_anchor(asset)
	if CONTACTS.obstructed(asset,pose,context): return false
	# Clear glass alone is insufficient: the dormer's roof/trim can still be
	# sliced by a nearby flight. Keep or relocate the complete authored module.
	assert(context.has("geometry"), "Dormer fit requires complete module geometry")
	assert(context.geometry.has(asset), "Dormer fitting requires native roof geometry: %s" % asset)
	var surfaces: Array = context.geometry[asset]
	var meshes := []
	for surface:Dictionary in surfaces:
		meshes.append(UNION.trim_surface(surface,pose,context.public))
	return not preload("res://scripts/terrain/features/villages/kit/KitRoofEaveFits.gd").removes_surface(
		{"surfaces":surfaces,"meshes":meshes},pose)
