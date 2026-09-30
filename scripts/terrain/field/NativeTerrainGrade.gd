extends RefCounted

## Resolve sealed construction constraints into the ordinary world lattice.
## The native cliff classifier and native pieces consume the resulting controls;
## no rendered tile or collision triangle is subsequently bent by a fine collar.
const TILE := TerrainSurfaceField.TILE

static func controls(grade: TerrainGradePatch, source: HeightfieldRegion) -> Dictionary:
	var plan = source.plan
	if plan != null and grade.native_control_cache.has(plan):
		return grade.native_control_cache[plan]
	var area := grade.bounds.grow(TerrainGradePatch.NATIVE_CONTROL_MARGIN)
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
			if not natural.has_surface_cell(x,z): continue
			var height := natural.surface_height(x,z)
			var graded := grade.surface_y(Vector2(x,z)*TILE,height)
			if absf(height-graded) > .00001:
				result.native_control_heights[Vector2i(x,z)] = roundf(graded)
	var owners := pad_owners(grade)
	var requests: Array = []
	var fixed := fixed_claims(grade)
	var fine_cells: Array = fixed.keys()
	fine_cells.sort_custom(func(a:Vector2i,b:Vector2i)->bool: return a.y<b.y if a.y!=b.y else a.x<b.x)
	for fine: Vector2i in fine_cells:
		var point := grade._origin+Vector2(fine)*grade._targets.pitch
		var radius := grade._targets.pitch*.5
		var height := _height(float(fixed[fine]))
		var control_lo := Vector2i(floori((point.x-radius)/TILE),floori((point.y-radius)/TILE))
		var control_hi := Vector2i(ceili((point.x+radius)/TILE),ceili((point.y+radius)/TILE))
		requests.append([point,radius,control_lo,control_hi,height])
	result.native_control_heights.merge(owners,true)
	# Raising a free control is monotone and takes one of the finite target
	# values. Fixed owners never move. At most cells * targets changes can occur.
	var budget := (hi.x-lo.x+1)*(hi.y-lo.y+1)*maxi(1,requests.size())
	var construction: Dictionary = owners.duplicate()
	while true:
		var changed := false
		for request: Array in requests:
			var unsupported := false
			for offset: Vector2 in [Vector2.ZERO,Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]:
				var point: Vector2=request[0]+offset*request[1]*.999
				if TerrainSurfaceField.surface_y(result,point.x,point.y)<request[4]-.00001:
					unsupported=true
			if not unsupported: continue
			for z in range(request[2].y,request[3].y+1):
				for x in range(request[2].x,request[3].x+1):
					var key:=Vector2i(x,z)
					if not result.has_surface_cell(x,z) or owners.has(key): continue
					if result.surface_height(x,z)>=request[4]: continue
					result.native_control_heights[key]=request[4]
					construction[key]=true
					changed=true
					budget-=1
					assert(budget>=0,"Native grade exceeded its finite monotone control bound")
		if not changed: break
	_relax_free(grade,natural,result,construction)
	_grade_roads(grade,natural,result,owners)
	# A regraded road is construction too; the ground beside it relaxes again.
	for cell: Vector2i in grade.road_masks: construction[cell] = true
	_relax_free(grade,natural,result,construction)
	var values := result.native_control_heights
	grade.native_construction_cache[plan if plan != null else source]=construction
	if plan != null: grade.native_control_cache[plan]=values
	return values

## The collar blends the ground toward a town's pads; rounded to whole
## metres, a blended cell can land a storey or more off its natural height
## beside an untouched neighbour and turn a natural slope into a cliff, which
## the cliff sheet rounded into a stray mound (September 29). Grading never
## makes a cliff between two free cells that were a slope: a free cell is
## pulled back toward its own natural height, never past it, until each
## such edge is a slope again. Natural neighbours are a slope, so this always
## succeeds. `fixed` cells (pad owners, pad support, regraded roads) are
## construction and never move; a cliff against them is its retaining edge.
## Cells are visited in sorted order and only move toward natural: a finite,
## deterministic fixpoint over the grade's complete control domain.
static func _relax_free(grade: TerrainGradePatch, natural: HeightfieldRegion,
		result: HeightfieldRegion, fixed: Dictionary) -> void:
	var reach := grade.bounds.grow(TILE)
	var lo := Vector2i(ceili(reach.position.x/TILE),ceili(reach.position.y/TILE))
	var hi := Vector2i(floori(reach.end.x/TILE),floori(reach.end.y/TILE))
	var edges: Array = []
	var free: Dictionary = {}
	for z in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			var cell := Vector2i(x,z)
			if not natural.has_surface_cell(x,z) or fixed.has(cell) or not is_free(grade,fixed,cell): continue
			free[cell] = true
			for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var other := cell+d
				if not natural.has_surface_cell(other.x,other.y) or fixed.has(other) \
						or not is_free(grade,fixed,other): continue
				if TerrainSurfaceField.is_cliff_edge(natural,x,z,d): continue
				edges.append([other,cell])
	var budget := maxi(1,free.size())*64
	var changed := true
	while changed:
		changed = false
		for edge: Array in edges:
			var cell: Vector2i = edge[1]
			var anchor: Vector2i = edge[0]
			var here := result.surface_height(cell.x,cell.y)
			var home := natural.surface_height(cell.x,cell.y)
			var rise: int = result.storey_at(cell.x,cell.y)-result.storey_at(anchor.x,anchor.y)
			var height := here
			if rise >= 2 and here > home:
				height = maxf(home,result.surface_height(anchor.x,anchor.y)+HeightfieldRegion.STOREY_HEIGHT)
			elif rise <= -2 and here < home:
				height = minf(home,HeightfieldRegion.STOREY_HEIGHT*(result.storey_at(anchor.x,anchor.y)-1))
			if height == here: continue
			result.native_control_heights[cell] = height
			changed = true
			budget -= 1
			assert(budget>=0,"Free-cell grading exceeded its finite monotone bound")
	for cell: Vector2i in free:
		if result.native_control_heights.has(cell) \
				and absf(float(result.native_control_heights[cell])-natural.surface_height(cell.x,cell.y)) < .00001:
			result.native_control_heights.erase(cell)

## An accepted country road was routed over natural ground, so every road
## edge was walkable there (its two cells at most one storey apart). The
## grade moves cells near the road: pads, the collar's rounded blend, the
## pad-support raise. Relax the free road cells along the road itself until
## every such edge is walkable again: first lower a cell standing two storeys
## over its road neighbour to one storey above it, then raise a cell standing
## two storeys under its neighbour to one storey below it. The road is graded
## into the town one storey per cell; ground beside the road keeps its grade.
## Town-claimed cells and road cells beyond the reach stay fixed, so a ramp
## stays within one tile of the grade's bounds, inside its published control
## margin. Both passes move cells monotonically by whole storeys: finite, and
## over the complete control domain independent of the requesting chunk.
static func _grade_roads(grade: TerrainGradePatch, natural: HeightfieldRegion,
		result: HeightfieldRegion, owners: Dictionary) -> void:
	var reach := grade.bounds.grow(TILE)
	var free: Dictionary = {}
	var edges: Array = []
	var cells: Array = grade.road_masks.keys()
	cells.sort()
	for cell: Vector2i in cells:
		for arm: Array in [[1,Vector2i(1,0)],[4,Vector2i(0,1)]]:
			if (int(grade.road_masks[cell]) & int(arm[0])) == 0: continue
			var other: Vector2i = cell+arm[1]
			if not (natural.has_surface_cell(cell.x,cell.y) and natural.has_surface_cell(other.x,other.y)): continue
			if TerrainSurfaceField.is_cliff_edge(natural,cell.x,cell.y,arm[1]): continue
			edges.append([cell,other])
			edges.append([other,cell])
			for end: Vector2i in [cell,other]:
				if reach.has_point(Vector2(end)*TILE) and is_free(grade,owners,end):
					free[end] = true
	var budget := maxi(1,free.size())*64
	for lowering: bool in [true,false]:
		var changed := true
		while changed:
			changed = false
			for edge: Array in edges:
				var cell: Vector2i = edge[1]
				if not free.has(cell): continue
				var anchor: float = result.surface_height(edge[0].x,edge[0].y)
				var rise: int = result.storey_at(cell.x,cell.y)-result.storey_at(edge[0].x,edge[0].y)
				if lowering and rise >= 2:
					result.native_control_heights[cell] = anchor+HeightfieldRegion.STOREY_HEIGHT
				elif not lowering and rise <= -2:
					result.native_control_heights[cell] = anchor-HeightfieldRegion.STOREY_HEIGHT
				else: continue
				changed = true
				budget -= 1
				assert(budget>=0,"Road grading exceeded its finite monotone bound")
	# A road cell relaxed back onto its natural ground is not graded.
	for cell: Vector2i in free:
		if result.native_control_heights.has(cell) \
				and absf(float(result.native_control_heights[cell])-natural.surface_height(cell.x,cell.y)) < .00001:
			result.native_control_heights.erase(cell)

static func _height(value:float)->float:
	# Remove only numerical residue from inherited flat street samples. A real
	# fractional foundation datum keeps its exact elevation.
	return roundf(value) if absf(value-roundf(value))<.00001 else value

## Cells the grade treats as construction (pad owners, pad support and
## regraded roads) for this natural region, after `controls` has run.
static func construction_cells(grade: TerrainGradePatch, source: HeightfieldRegion) -> Dictionary:
	var key = source.plan if source.plan != null else source
	return grade.native_construction_cache.get(key,{})

## Terrain cells a fixed construction datum owns (cell -> lowest datum over
## it). Owners never move; every other control near the grade is free.
static func pad_owners(grade: TerrainGradePatch) -> Dictionary:
	var owners: Dictionary = {}
	var fixed := fixed_claims(grade)
	for fine: Vector2i in fixed:
		var point := grade._origin+Vector2(fine)*grade._targets.pitch
		var radius := grade._targets.pitch*.5
		var height := _height(float(fixed[fine]))
		var own_lo := Vector2i(floori((point.x-radius)/TILE+.5),floori((point.y-radius)/TILE+.5))
		var own_hi := Vector2i(floori((point.x+radius)/TILE+.5),floori((point.y+radius)/TILE+.5))
		for z in range(own_lo.y,own_hi.y+1):
			for x in range(own_lo.x,own_hi.x+1):
				var key := Vector2i(x,z)
				owners[key]=minf(owners.get(key,INF),height)
	return owners

## A cell the construction does not own: no fixed datum over it and no
## claim at its centre (streets included). Grading may move free cells.
static func is_free(grade: TerrainGradePatch, owners: Dictionary, cell: Vector2i) -> bool:
	var fine := Vector2i(((Vector2(cell)*TILE-grade._origin)/grade._targets.pitch).round())
	return not owners.has(cell) and not grade._claims.has(fine)

## A road extension reserves a continuous approach, not a new flat pad at
## each sampled street point. Follow its lineage to retain only actual fixed
## construction datums before selecting the world-grid tiles.
static func fixed_claims(grade: TerrainGradePatch) -> Dictionary:
	var result: Dictionary = {}
	for cell: Vector2i in grade._claims:
		var source := grade
		while source != null and source._claims.has(cell):
			if source._continuous_source == null or not source._continuous_cells.has(cell):
				result[cell] = source._claims[cell]
				break
			source = source._continuous_source
	return result
