extends RefCounted
## Coalesce already-owned straight wall slots into bounded authored panels.
## This has no terrain, water or feature classifier: the canonical wall owner
## supplies every occupied 3 m / 4 m slot, including irregular end staircases.
const WIDTHS := [8,4,2,1]
const HEIGHTS := [4,3,2,1]

static func panels(transforms: Array) -> Dictionary:
	var planes := {}
	for pose: Transform3D in transforms:
		var tangent := pose.basis.x.round()
		var outward := pose.basis.z.round()
		var depth := snappedf(pose.origin.dot(outward),.001)
		var phase := snappedf(fposmod(pose.origin.y,4.0),.001)
		var key := str(tangent)+str(outward)+str(depth)+"/"+str(phase)
		if not planes.has(key):
			planes[key] = {"basis":pose.basis,"depth":depth,"phase":phase,"slots":{}}
		var slot := Vector2i(roundi(pose.origin.dot(tangent)/3.0-.5),roundi((pose.origin.y-phase)/4.0))
		planes[key].slots[slot] = true
	var out := {}
	var keys: Array = planes.keys()
	keys.sort()
	for key: String in keys:
		var plane: Dictionary = planes[key]
		var slots: Dictionary = plane.slots
		var ordered: Array = slots.keys()
		ordered.sort_custom(func(a: Vector2i,b: Vector2i)->bool: return a.y<b.y or (a.y==b.y and a.x<b.x))
		for start: Vector2i in ordered:
			if not slots.has(start): continue
			var best := Vector2i.ONE
			for width: int in WIDTHS:
				# Native cells are centered at multiples of 24 m; block edges
				# are at -12 + 24n, the same phase as streamed ownership.
				# A neighboring query cannot join across a different block edge.
				if floori(float(start.x+4)/8)!=floori(float(start.x+width+3)/8): continue
				for height: int in HEIGHTS:
					if width*height<=best.x*best.y: continue
					var complete := true
					for y in height:
						for x in width:
							if not slots.has(start+Vector2i(x,y)): complete=false; break
						if not complete: break
					if complete: best=Vector2i(width,height)
			for y in best.y:
				for x in best.x: slots.erase(start+Vector2i(x,y))
			var asset := "wall_%dx%d" % [best.x*3,best.y*4]
			if not out.has(asset): out[asset]=[]
			var basis: Basis = plane.basis
			var origin := basis.x*(float(start.x)*3.0+float(best.x)*1.5)+basis.z*float(plane.depth)
			origin.y=float(plane.phase)+float(start.y)*4.0
			out[asset].append(Transform3D(basis,origin))
	return out
