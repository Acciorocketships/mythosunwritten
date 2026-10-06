extends RefCounted
## Choose a complete tight eave when a native cornice meets public headroom.
## Uses the authored triangles; no seed, location or nominal-band exceptions.
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")

static func fit(roofs: Array[Dictionary], base: BuildingKit, roof_kits: Dictionary,
		walls: Array[Dictionary]) -> int:
	var candidates: Array[int] = []
	for i in roofs.size():
		var own: BuildingKit = roof_kits.get(i,base)
		if own.has_role(StringName("roof.%s.eave_tight" % roofs[i].colour)):
			candidates.append(i)
	if candidates.is_empty(): return 0
	var public: Array[Dictionary] = []
	for wall: Dictionary in walls:
		if bool(wall.get("open",false)): public.append(wall)
	if public.is_empty(): return 0
	var ctx := UNION.prepare(roofs,public,base,roof_kits)
	# Only walking air selects this profile, not a legitimate roof junction.
	for i in roofs.size():
		ctx.volumes[i] = {"bounds":AABB(),"planes":[]}
		ctx.clips[i] = []
	var count := 0
	for i in candidates:
		var own: BuildingKit = roof_kits.get(i,base)
		var wing: Dictionary = roofs[i]
		var blocked_sides := _blocked_sides(wing,i,own,ctx)
		if blocked_sides == 0: continue
		var changed := false
		var before := BuildingKitAssembler.tight_eave_sides(wing)
		if (before | blocked_sides) != before:
			wing.tight_eave_sides = before | blocked_sides
			wing.tight_eave = true
			changed = true
		# Straight slopes can still carry a projecting gable-end cap around a
		# perpendicular landing. Use the existing native flush-verge assembly,
		# moving complete caps and their ridge/barge finish together. Try each
		# end independently before retracting both; never accept a partial cap.
		if own.roof_edge_caps and not _eaves_clear(wing,i,own,ctx):
			for ends in [1,2,3]:
				var trial := wing.duplicate(true)
				if ends & 1: trial.verge_min = 0.0
				if ends & 2: trial.verge_max = 0.0
				if not _eaves_clear(trial,i,own,ctx): continue
				if ends & 1: wing.verge_min = 0.0
				if ends & 2: wing.verge_max = 0.0
				changed = true
				break
		count += int(changed)
	return count


static func _eaves_clear(wing: Dictionary, index: int, kit: BuildingKit,
		ctx: Dictionary) -> bool:
	return _blocked_sides(wing,index,kit,ctx,true)==0


static func _blocked_sides(wing: Dictionary, index: int, kit: BuildingKit,
		ctx: Dictionary, first_only := false) -> int:
	var mass := BuildingMass.new()
	var trial := wing.duplicate()
	# Structural fit precedes optional dormer placement. Dormer skins receive
	# their own whole-asset public-air proof after the eave profile is chosen.
	trial.dormers = {}
	trial.union_index = index
	mass.roofs.append(trial)
	var blocked := 0
	for part: Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
		if not String(part.role).contains(".eave"): continue
		var bit := 1 << int(part.roof_side)
		if blocked & bit: continue
		if removes_surface(UNION.realize(part,ctx),part.transform):
			blocked |= bit
			if first_only or blocked==3: return blocked
	return blocked


## Clipping may split a triangle without removing material. Float32 vertices
## also leave sub-tolerance strips at a shared boundary. Neither justifies
## replacing an intact authored cornice with the retracted eave assembly.
## Compare each material surface separately so a numerical gain on one cannot
## conceal real loss on another. The allowance is one EPS-high triangle along
## the longest source edge, matching the clipper's spatial precision.
static func removes_surface(realized: Dictionary, pose: Transform3D) -> bool:
	if realized.is_empty(): return false
	for i in realized.surfaces.size():
		var source: Dictionary = realized.surfaces[i]
		var vertices: PackedVector3Array = pose * (source.vertices as PackedVector3Array)
		var longest := 0.0
		var original_area := 0.0
		for t in range(0,source.indices.size(),3):
			var a := vertices[source.indices[t]]
			var b := vertices[source.indices[t+1]]
			var c := vertices[source.indices[t+2]]
			original_area += (b-a).cross(c-a).length()*0.5
			longest = maxf(longest,maxf((b-a).length(),maxf((c-a).length(),(c-b).length())))
		var retained: Dictionary = realized.meshes[i]
		var retained_area := 0.0
		for t in range(0,retained.indices.size(),3):
			var a: Vector3 = retained.vertices[retained.indices[t]]
			var b: Vector3 = retained.vertices[retained.indices[t+1]]
			var c: Vector3 = retained.vertices[retained.indices[t+2]]
			retained_area += (b-a).cross(c-a).length()*0.5
		if original_area-retained_area > UNION.EPS*longest*0.5: return true
	return false
