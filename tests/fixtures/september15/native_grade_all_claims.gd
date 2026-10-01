extends RefCounted

## Resolve sealed construction constraints into the ordinary world lattice.
## The native cliff classifier and native pieces consume the resulting controls;
## no rendered tile or collision triangle is subsequently bent by a fine collar.
const TILE := TerrainTileField.SPACING

static func controls(grade: TerrainGradePatch, source: HeightfieldRegion) -> Dictionary:
	var plan = source.plan
	if plan != null and grade.native_control_cache.has(plan):
		return grade.native_control_cache[plan]
	var area := grade.bounds.grow(TILE*2.0)
	var lo := Vector2i(floori(area.position.x/TILE),floori(area.position.y/TILE))
	var hi := Vector2i(ceili(area.end.x/TILE),ceili(area.end.y/TILE))
	# Every invocation sees the same complete dependency domain, independently
	# of which streaming chunk or foundation survey asks first.
	var natural := source
	if plan != null:
		var middle := Vector2i(floori((lo.x+hi.x)*.5),floori((lo.y+hi.y)*.5))
		natural=plan.compute_region(middle.x,middle.y,maxi(hi.x-middle.x,hi.y-middle.y)+2)
	var result := HeightfieldRegion.new(natural._storeys,natural._levels,natural._carved)
	for z in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			if not natural.has_surface_point(x,z): continue
			var height := natural.surface_height(x,z)
			var graded := grade.surface_y(Vector2(x,z)*TILE,height)
			if absf(height-graded) > .00001:
				result.native_control_heights[Vector2i(x,z)] = roundf(graded)
	var owners: Dictionary = {}
	var requests: Array = []
	var fine_cells: Array = grade._claims.keys()
	fine_cells.sort_custom(func(a:Vector2i,b:Vector2i)->bool: return a.y<b.y if a.y!=b.y else a.x<b.x)
	for fine: Vector2i in fine_cells:
		var point := grade._origin+Vector2(fine)*grade._targets.pitch
		var radius := grade._targets.pitch*.5
		var height := _height(float(grade._claims[fine]))
		var own_lo := Vector2i(floori((point.x-radius)/TILE+.5),floori((point.y-radius)/TILE+.5))
		var own_hi := Vector2i(floori((point.x+radius)/TILE+.5),floori((point.y+radius)/TILE+.5))
		for z in range(own_lo.y,own_hi.y+1):
			for x in range(own_lo.x,own_hi.x+1):
				var key := Vector2i(x,z)
				owners[key]=minf(owners.get(key,INF),height)
		var control_lo := Vector2i(floori((point.x-radius)/TILE),floori((point.y-radius)/TILE))
		var control_hi := Vector2i(ceili((point.x+radius)/TILE),ceili((point.y+radius)/TILE))
		requests.append([point,radius,control_lo,control_hi,height])
	result.native_control_heights.merge(owners,true)
	# Raising a free control is monotone and takes one of the finite target
	# values. Fixed owners never move. At most cells * targets changes can occur.
	var budget := (hi.x-lo.x+1)*(hi.y-lo.y+1)*maxi(1,requests.size())
	while true:
		var changed := false
		for request: Array in requests:
			var unsupported := false
			for offset: Vector2 in [Vector2.ZERO,Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]:
				var point: Vector2=request[0]+offset*request[1]*.999
				if TerrainTileField.surface_y(result,point.x,point.y)<request[4]-.00001:
					unsupported=true
			if not unsupported: continue
			for z in range(request[2].y,request[3].y+1):
				for x in range(request[2].x,request[3].x+1):
					var key:=Vector2i(x,z)
					if not result.has_surface_point(x,z) or owners.has(key): continue
					if result.surface_height(x,z)>=request[4]: continue
					result.native_control_heights[key]=request[4]
					changed=true
					budget-=1
					assert(budget>=0,"Native grade exceeded its finite monotone control bound")
		if not changed: break
	var values := result.native_control_heights
	if plan != null: grade.native_control_cache[plan]=values
	return values

static func _height(value:float)->float:
	# Remove only numerical residue from inherited flat street samples. A real
	# fractional foundation datum keeps its exact elevation.
	return roundf(value) if absf(value-roundf(value))<.00001 else value
