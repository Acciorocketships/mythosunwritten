extends RefCounted
## Court roots belong to the planting island; crowns may shelter adjacent
## streets only above their actual headroom. Bounds come from baked triangles.
const PROFILES := preload("res://scripts/terrain/features/villages/TownTreeProfiles.gd").BANDS
const ASSEMBLER := preload("res://scripts/terrain/features/villages/fabric/SettlementFabricAssembler.gd")
const ROOT_MARGIN := 0.08

## Keep the seeded orientation when it fits. An asymmetric crown may fit at
## another quarter turn without reducing its height or relaxing any clearance.
static func fit_rotation(feature: Dictionary, footprints: Dictionary,
		skin: Array[AABB]) -> Dictionary:
	for offset in 4:
		var candidate := feature.duplicate()
		candidate.quarter = posmod(int(feature.quarter) + offset, 4)
		if clear(candidate, footprints, skin):
			return candidate
	return {}

static func bands(feature: Dictionary) -> Array[AABB]:
	var out: Array[AABB] = []
	if not PROFILES.has(feature.asset): return out
	var pose := Transform3D(Basis(Vector3.UP,float(feature.quarter)*PI*0.5)
		.scaled(Vector3.ONE*float(feature.scale)),feature.origin)
	for band: AABB in PROFILES[feature.asset]: out.append(pose*band)
	return out

static func native_obstacles(payload: EnvironmentInstancePayload, catalog: EnvironmentCatalog) -> Dictionary:
	var boxes: Array[AABB] = []
	var surfaces: Array[Dictionary] = []
	for asset: StringName in payload.batches:
		var descriptor := catalog.descriptor(asset)
		if descriptor == null: continue
		for pose: Transform3D in payload.batches[asset].transforms:
			boxes.append(pose*descriptor.measured_aabb)
	# Pitched roofs are generated meshes, not catalogue instances. Their
	# exact triangles leave the empty volume beneath a slope available.
	for mesh: Dictionary in payload.surface_meshes:
		var vertices: PackedVector3Array = mesh.get("vertices",PackedVector3Array())
		var indices: PackedInt32Array = mesh.get("indices",PackedInt32Array())
		if indices.is_empty(): continue
		var faces := PackedVector3Array()
		var bounds := AABB(vertices[indices[0]],Vector3.ZERO)
		for index: int in indices:
			faces.append(vertices[index])
			bounds = bounds.expand(vertices[index])
		surfaces.append({"bounds":bounds,"faces":faces})
	return {"boxes":boxes,"native_surfaces":surfaces}

static func clear(feature: Dictionary, footprints: Dictionary, skin: Array[AABB]) -> bool:
	var measured := bands(feature)
	if measured.is_empty(): return false
	var ground := float((feature.cell as Vector3i).y+1)*FabricRecipe.CELL_SIZE+ASSEMBLER.GREEN_CAP_LIFT
	var headroom := TraversalEnvelope.MIN_HEADROOM/VillageWorldScale.VERTICAL_SCALE
	for box: AABB in measured:
		# Low roots, trunk and branches must remain on owned planting ground.
		# Crown sections above head height may extend beyond the island.
		if box.position.y < ground+headroom:
			var root := box.grow(ROOT_MARGIN)
			for x in range(floori((root.position.x+.75)/1.5),ceili((root.end.x+.75)/1.5)):
				for z in range(floori((root.position.z+.75)/1.5),ceili((root.end.z+.75)/1.5)):
					if not feature.cells.has(Vector3i(x,(feature.cell as Vector3i).y,z)): return false
		for obstacle: AABB in footprints.get("boxes",[]):
			if ASSEMBLER._boxes_share_volume(box,obstacle): return false
		for obstacle: AABB in skin:
			if ASSEMBLER._boxes_share_volume(box,obstacle): return false
		if not ASSEMBLER._box_clears_public_surfaces(box,{"public_surfaces":footprints.get("native_surfaces",[])}): return false
		# Sweeping the box downward by body height is equivalent to testing
		# it against the upward headroom extrusion of each floor triangle.
		# Uses finished stairs too, not only nominal grid-level floors.
		var swept := box
		swept.position.y -= headroom
		swept.size.y += headroom
		if not ASSEMBLER._box_clears_public_surfaces(swept,footprints): return false
	return true


## A doorway can notch a planting island without removing every valid root
## position. Search its real cells; the same measured root/crown proof decides.
static func fit_island(cells: Dictionary, footprints: Dictionary,
		skin: Array[AABB], quarter: int) -> Dictionary:
	if cells.is_empty(): return {}
	var ordered: Array = cells.keys()
	var centre := Vector3.ZERO
	for cell: Vector3i in ordered: centre += Vector3(cell)
	centre /= float(ordered.size())
	ordered.sort_custom(func(a: Vector3i,b: Vector3i):
		var da := Vector3(a).distance_squared_to(centre)
		var db := Vector3(b).distance_squared_to(centre)
		if not is_equal_approx(da,db): return da<db
		return a.x<b.x if a.x!=b.x else (a.z<b.z if a.z!=b.z else a.y<b.y))
	var bounds: Dictionary = footprints.get("asset_bounds",{})
	for height: float in [7.5,6.0,4.5]:
		for cell: Vector3i in ordered:
			for asset: StringName in ASSEMBLER.PLAZA_COURT_TREES:
				if not bounds.has(asset): continue
				var box: AABB = bounds[asset]
				var scale_value := height/box.size.y
				var origin := Vector3(cell)*FabricRecipe.CELL_SIZE
				origin.y = float(cell.y+1)*FabricRecipe.CELL_SIZE+ASSEMBLER.GREEN_CAP_LIFT \
					-minf(0.0,box.position.y)*scale_value
				var candidate := {"asset":asset,"cell":cell,"origin":origin,
					"quarter":quarter,"cells":cells,"scale":scale_value,"street_canopy":true}
				var fitted := fit_rotation(candidate,footprints,skin)
				if not fitted.is_empty(): return fitted
	return {}
