extends RefCounted
## House_11c's roof-emergent round turret. Unlike a half-tower, this has a
## complete shaft inside the upper room and attic, not an open-backed applique.
## All visible geometry is the original, unscaled Pure Village architecture.
const TOWER := preload("res://scripts/terrain/features/villages/kit/KitTowerAssembly.gd")
const CORE := "res://terrain/environment/geometry/pure_village_roof_turret_core.bin"
const PREFIX := "pure_village.roof_turret."
const CAP_LAP := 0.25 # House_11c: cap 18.5 above the window origin 15.75.

static func parts(plain_courses: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index in plain_courses + 1:
		var suffix := "window" if index == plain_courses else "middle"
		out.append({"asset_id":StringName(PREFIX+suffix),"role":StringName("tower."+suffix),
			"transform":Transform3D(Basis.IDENTITY,Vector3(0,index*TOWER.COURSE,0))})
	out.append({"asset_id":StringName(PREFIX+"roof"),"role":&"tower.roof",
		"transform":Transform3D(Basis.IDENTITY,Vector3(0,(plain_courses+1)*TOWER.COURSE-CAP_LAP,0))})
	return out

static func cutters(candidate: Dictionary) -> Array[Dictionary]:
	var core: Array = FileAccess.open(CORE,FileAccess.READ).get_var()
	var out: Array[Dictionary] = []
	# Reconstruct from present courses. Never exempt a stale clipping request
	# after its enclosing shaft has been removed (also used by roof audits).
	for part: Dictionary in candidate.parts:
		if part.asset_id == StringName(PREFIX+"middle"):
			out.append_array(TOWER.placed_cutters(core,candidate.pose*part.transform))
	return out
