extends RefCounted
## Fit facade openings against completed roofs and raised public floors.
## Opening bounds come from the baked catalog; door reservations never change.
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
const OPENINGS := "res://terrain/environment/geometry/window_openings.bin"
const FRAMES := "res://terrain/environment/geometry/window_frames.bin"

static func prepare(roofs: Array[Dictionary], base: BuildingKit, roof_kits: Dictionary,
		walls: Array[Dictionary] = []) -> Dictionary:
	var volumes: Array[Dictionary] = []
	for i in roofs.size():
		volumes.append(UNION.roof_volume(roofs[i],roof_kits.get(i,base)))
	var skins: Array[Dictionary] = []
	var union_context := UNION.prepare(roofs,walls,base,roof_kits)
	union_context["realized_cache"] = {}
	if not roofs.is_empty():
		for i in roofs.size():
			var mass := BuildingMass.new()
			var wing: Dictionary = roofs[i].duplicate()
			wing.union_index = i
			mass.roofs.append(wing)
			for part: Dictionary in BuildingKitAssembler.new(roof_kits.get(i,base)).assemble(mass):
				var role := String(part.role)
				if not (role.begins_with("roof.") or role.begins_with("trim.")): continue
				if not union_context.data.has(part.asset_id): continue
				var realized := UNION.realize(part,union_context)
				var surfaces: Array = union_context.data[part.asset_id] if realized.is_empty() else realized.meshes
				for surface: Dictionary in surfaces:
					if surface.vertices.is_empty(): continue
					var vertices: PackedVector3Array = part.transform * surface.vertices if realized.is_empty() else surface.vertices
					var bounds := AABB(vertices[0],Vector3.ZERO)
					for p in vertices: bounds = bounds.expand(p)
					skins.append({"bounds":bounds,"vertices":vertices,"indices":surface.indices})
	return {"volumes":volumes,"skins":skins,"roof_context":union_context,
		"openings":FileAccess.open(OPENINGS,FileAccess.READ).get_var(),
		"frames":FileAccess.open(FRAMES,FileAccess.READ).get_var()}

static func add_inhabited_floors(context: Dictionary, mass: BuildingMass,
		assembler: BuildingKitAssembler, catalog: EnvironmentCatalog) -> void:
	# The native board is a rectangular slab. Its complete measured thickness
	# matters when a neighbouring house starts on an odd half-storey datum.
	for part: Dictionary in assembler.inhabited_floors(mass):
		var bounds: AABB = part.transform*catalog.descriptor(part.asset_id).measured_aabb
		context.volumes.append(UNION.box_volume(bounds))

static func add_floor(context: Dictionary, mesh: Dictionary, map: Transform3D) -> void:
	# Only the finished walking skin can interrupt an opening. Its headroom
	# reservation is air, and must never hide windows looking onto a street.
	var vertices: PackedVector3Array = map * mesh.vertices
	var indices := PackedInt32Array()
	var bounds := AABB()
	for i in range(0,mesh.indices.size(),3):
		var guard := false
		for span: Vector2i in mesh.get("guard_index_ranges",[]):
			guard = guard or (i >= span.x and i < span.y)
		if guard or mesh.normals[mesh.indices[i]].y <= 0.01: continue
		for j in 3:
			var index: int = mesh.indices[i+j]
			bounds = AABB(vertices[index],Vector3.ZERO) if indices.is_empty() else bounds.expand(vertices[index])
			indices.append(index)
	if not indices.is_empty():
		context.skins.append({"bounds":bounds.grow(0.001),"vertices":vertices,"indices":indices})

static func opening_asset(asset: StringName) -> StringName:
	var canonical := String(asset).get_slice(".finish_", 0)
	if canonical.begins_with("pure_village.roof."):
		for suffix: String in [".wood_red", ".wood_blue", ".sage"]:
			canonical = canonical.trim_suffix(suffix)
	return StringName(canonical)

static func obstructed(asset: StringName, pose: Transform3D, context: Dictionary) -> bool:
	asset = opening_asset(asset)
	if not context.openings.has(asset): return false
	# Each authored timber surround must also clear the finished skin.
	# Measuring separate pieces avoids an arbitrary margin around the pane.
	for component: AABB in context.get("frames",{}).get(asset,[]):
		if intersects_skins(pose * component, context.get("skins",[])): return true
	var opening: AABB = context.openings[asset]
	# Probe just outside the glass, where a meeting roof interrupts the view.
	# The pane's actual width/height keep roof contacts below its sill legal.
	var z := opening.end.z + 0.15
	var corners: Array[Vector3] = [Vector3(opening.position.x,opening.position.y,z),
		Vector3(opening.end.x,opening.position.y,z),Vector3(opening.end.x,opening.end.y,z),
		Vector3(opening.position.x,opening.end.y,z)]
	var polygon: Array = []
	var bounds := AABB(pose*corners[0],Vector3.ZERO)
	for p in corners:
		var world := pose*p
		polygon.append({"p":world,"n":pose.basis.z.normalized(),"uv":Vector2.ZERO})
		bounds = bounds.expand(world)
	for volume: Dictionary in context.volumes:
		if not bounds.grow(0.001).intersects(volume.bounds): continue
		var clipped := polygon
		for plane: Plane in volume.planes:
			clipped = UNION.split(clipped,plane,true)
			if clipped.size()<3: break
		if clipped.size()<3: continue
		var area := 0.0
		for i in range(1,clipped.size()-1):
			area += ((clipped[i].p-clipped[0].p) as Vector3).cross(clipped[i+1].p-clipped[0].p).length()*0.5
		if area > 0.002: return true
	# Native curved cornices can extend below/outside the simple attic volume.
	# Test the finished authored triangles as well, after public/roof trimming.
	var prism := opening
	prism.position.z -= 0.02
	prism.size.z += 0.32
	var world_prism := pose * prism
	return intersects_skins(world_prism, context.get("skins",[]))


## Whole projecting assemblies must clear the finished roof skin, including
## their hood above the glass. A glazing-only check misses that collision.
static func intersects_skins(bounds: AABB, skins: Array) -> bool:
	var cutter := UNION.box_volume(bounds)
	for skin: Dictionary in skins:
		if not bounds.intersects(skin.bounds): continue
		for i in range(0,skin.indices.size(),3):
			var triangle: Array = []
			for j in 3:
				triangle.append({"p":skin.vertices[skin.indices[i+j]],"n":Vector3.UP,"uv":Vector2.ZERO})
			for plane: Plane in cutter.planes:
				triangle = UNION.split(triangle,plane,true)
				if triangle.size()<3: break
			if triangle.size()<3: continue
			for j in range(1,triangle.size()-1):
				if ((triangle[j].p-triangle[0].p) as Vector3).cross(triangle[j+1].p-triangle[0].p).length()>0.004:
					return true
	return false

## The glazing must sit wholly above retained backing, not merely avoid its
## top surface. The source panel and its authored frame remain unchanged.
static func _clears_backing(asset: StringName, pose: Transform3D, min_y: float,
		context: Dictionary) -> bool:
	asset = opening_asset(asset)
	if min_y == -INF: return true
	if not context.openings.has(asset): return false
	var opening: AABB = pose * (context.openings[asset] as AABB)
	return opening.position.y >= min_y


static func fit(mass: BuildingMass, assembler: BuildingKitAssembler, context: Dictionary,
		catalog: EnvironmentCatalog = null) -> int:
	var kit := assembler.kit
	var blanked := {}
	var count := 0
	for index in mass.storeys.size():
		var storey: Dictionary = mass.storeys[index]
		var floor_band := int(storey.floor_band)
		var bands := int(storey.get("bands",2))
		if bands != 2 or bool(storey.get("retaining",false)): continue
		var y := float(floor_band)*kit.band_height()
		for slot: Dictionary in BuildingKitAssembler.storey_slots(storey,
				BuildingKitAssembler.exposure_for(mass,floor_band,bands,assembler.external_blocked)):
			if not assembler._slot_exposed(mass,slot,floor_band,bands): continue
			var kind := StringName(storey.openings.get(slot.edge,storey.default_opening))
			if kind not in [BuildingMass.OPENING_WINDOW,BuildingMass.OPENING_BAY]: continue
			var centre: Vector2 = slot.centre
			var pick := assembler._hash(mass,index,int(centre.x*2),int(centre.y*2))
			if kind == BuildingMass.OPENING_WINDOW and int(storey.get("plain_every",0))>0 and pick%int(storey.get("plain_every",0))==0: continue
			var role := StringName("wall.%s.window" % storey.material)
			var slot_y := y - (0.14 if float(slot.get("wall_offset",0.0))>0.0 else 0.0)
			var opening_y := slot_y
			if kind == BuildingMass.OPENING_BAY and kit.has_role(StringName("bay.%s" % storey.get("bay_colour",&"red"))):
				role = StringName((storey.get("bay_roles",{}) as Dictionary).get(slot.edge,StringName("bay.%s" % storey.get("bay_colour",&"red"))))
				opening_y += kit.band_height()*2.0/3.0
				centre += (storey.get("bay_offsets",{}) as Dictionary).get(slot.edge,Vector2.ZERO)
			var asset := StringName((storey.get("opening_assets",{}) as Dictionary).get(slot.edge,kit.asset(role,pick)))
			var min_y := float((storey.get("opening_min_y",{}) as Dictionary).get(slot.edge,-INF))
			var pose := Transform3D(Basis(Vector3.UP,BuildingKitAssembler.yaw_for_dir(int(slot.dir))),
				Vector3(centre.x*kit.module_width,opening_y,centre.y*kit.module_width))*kit.anchor(role)*kit.asset_anchor(asset)
			var hood_obstructed := false
			if kind == BuildingMass.OPENING_BAY and catalog != null:
				var bounds: AABB = pose * catalog.descriptor(asset).measured_aabb
				hood_obstructed = intersects_skins(bounds.grow(-0.01),context.get("skins",[]))
			if not hood_obstructed and _clears_backing(asset,pose,min_y,context) \
					and not obstructed(asset,pose,context): continue
			# Prefer another complete opening in the same family before using
			# a plain panel. A shorter window often fits below a curved cornice.
			var window_role := StringName("wall.%s.window" % storey.material)
			var alternative: StringName = &""
			var tried := {asset:true}
			var candidates: Array = kit.roles.get(window_role,[]).duplicate()
			if min_y != -INF:
				candidates.append_array(kit.roles.get(StringName(String(window_role)+".high"),[]))
			for candidate: StringName in candidates:
				if tried.has(candidate): continue
				tried[candidate] = true
				var candidate_pose := Transform3D(Basis(Vector3.UP,BuildingKitAssembler.yaw_for_dir(int(slot.dir))),
					Vector3(centre.x*kit.module_width,slot_y,centre.y*kit.module_width))*kit.anchor(window_role)*kit.asset_anchor(candidate)
				if _clears_backing(candidate,candidate_pose,min_y,context) and not obstructed(candidate,candidate_pose,context):
					alternative = candidate
					break
			if alternative != &"":
				storey.openings[slot.edge] = BuildingMass.OPENING_WINDOW
				if not storey.has("opening_assets"): storey.opening_assets = {}
				storey.opening_assets[slot.edge] = alternative
				context["substituted"] = int(context.get("substituted",0))+1
				continue
			storey.openings[slot.edge] = BuildingMass.OPENING_PLAIN
			blanked[Vector4(centre.x,centre.y,slot_y,float(slot.dir))] = true
			count += 1
	# Window boxes belong to their openings; keep no box on a newly blank panel.
	mass.decor = mass.decor.filter(func(item: Dictionary) -> bool:
		if item.kind != &"window_box": return true
		var c: Vector2 = item.centre
		var y := float(item.get("y",float(item.get("y_band",0))*kit.band_height()))
		return not blanked.has(Vector4(c.x,c.y,y,float(item.dir))))
	return count


static func fit_gables(placements: Array[Dictionary], kit: BuildingKit, context: Dictionary) -> int:
	var count := 0
	if not kit.has_role(&"gable.plain"): return count
	for part: Dictionary in placements:
		if part.role != &"gable.wall" or not obstructed(part.asset_id,part.transform,context): continue
		# Keep the complete closing panel, its roof ownership and union cuts.
		# Only its opening changes; triangular end pieces are untouched.
		var base: Transform3D = part.transform*(kit.anchor(&"gable.wall")*kit.asset_anchor(part.asset_id)).affine_inverse()
		part.asset_id = kit.asset(&"gable.plain",absi(hash(part.stable_id)))
		part.transform = base*kit.anchor(&"gable.plain")*kit.asset_anchor(part.asset_id)
		count += 1
	return count
