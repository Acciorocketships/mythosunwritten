extends RefCounted

## Resolve sealed construction constraints into per-POINT controls on the 12 m
## terrain lattice (dual-grid tiles). TerrainTileField reconstructs the final
## surface from these controls; no rendered tile or collision triangle is
## subsequently bent by a fine collar.
const POINT := HeightfieldPlan.POINT
## Road and free-ground regrading stay within one 24 m route cell of the
## grade's bounds, inside its published NATIVE_CONTROL_MARGIN.
const REACH := HeightfieldPlan.CELL

static func controls(grade: TerrainGradePatch, source: HeightfieldRegion) -> Dictionary:
	var plan = source.plan
	if plan != null and grade.native_control_cache.has(plan):
		return grade.native_control_cache[plan]
	var area := grade.bounds.grow(TerrainGradePatch.NATIVE_CONTROL_MARGIN)
	var lo := Vector2i(floori(area.position.x/POINT),floori(area.position.y/POINT))
	var hi := Vector2i(ceili(area.end.x/POINT),ceili(area.end.y/POINT))
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
			var graded := grade.surface_y(Vector2(x,z)*POINT,height)
			if absf(height-graded) > .00001:
				result.native_control_heights[Vector2i(x,z)] = roundf(graded)
	# Pad owners hold every corner of every tile a fixed claim touches, so the
	# claim is flat at its datum: a tile stays within its corners, and a tile
	# whose corners are equal is flat (TerrainTileField). No separate support
	# pass is needed; nothing inside a claim can sag below its datum.
	var owners := pad_owners(grade)
	for key: Vector2i in owners.keys():
		if not natural.has_surface_point(key.x,key.y): owners.erase(key)
	result.native_control_heights.merge(owners,true)
	var construction: Dictionary = owners.duplicate()
	_relax_free(grade,natural,result,construction)
	_grade_roads(grade,natural,result,owners)
	# A regraded road is construction too; the ground beside it relaxes again.
	for point: Vector2i in road_points(grade): construction[point] = true
	_relax_free(grade,natural,result,construction)
	var values := result.native_control_heights
	grade.native_construction_cache[plan if plan != null else source]=construction
	if plan != null: grade.native_control_cache[plan]=values
	return values

## The collar blends the ground toward a town's pads; rounded to whole
## metres, a blended point can land a storey or more off its natural height
## beside an untouched neighbour and turn a natural slope into a cliff, which
## the cliff sheet rounded into a stray mound (September 29). Grading never
## makes a cliff between two free points that were a slope: a free point is
## pulled back toward its own natural height, never past it, until each
## such edge is a slope again. Natural neighbours are a slope, so this always
## succeeds. `fixed` points (pad owners and regraded roads) are construction
## and never move; a cliff against them is its retaining edge. Points are
## visited in sorted order and only move toward natural: a finite,
## deterministic fixpoint over the grade's complete control domain.
static func _relax_free(grade: TerrainGradePatch, natural: HeightfieldRegion,
		result: HeightfieldRegion, fixed: Dictionary) -> void:
	var reach := grade.bounds.grow(REACH)
	var lo := Vector2i(ceili(reach.position.x/POINT),ceili(reach.position.y/POINT))
	var hi := Vector2i(floori(reach.end.x/POINT),floori(reach.end.y/POINT))
	var edges: Array = []
	var free: Dictionary = {}
	for z in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			var point := Vector2i(x,z)
			if not natural.has_surface_point(x,z) or fixed.has(point) or not is_free(grade,fixed,point): continue
			free[point] = true
			for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var other := point+d
				if not natural.has_surface_point(other.x,other.y) or fixed.has(other) \
						or not is_free(grade,fixed,other): continue
				if TerrainTileField.is_cliff_edge(natural,point,d): continue
				edges.append([other,point])
	var budget := maxi(1,free.size())*64
	var changed := true
	while changed:
		changed = false
		for edge: Array in edges:
			var point: Vector2i = edge[1]
			var anchor: Vector2i = edge[0]
			var here := result.surface_height(point.x,point.y)
			var home := natural.surface_height(point.x,point.y)
			var rise: int = result.storey_at(point.x,point.y)-result.storey_at(anchor.x,anchor.y)
			var height := here
			if rise >= 2 and here > home:
				height = maxf(home,result.surface_height(anchor.x,anchor.y)+HeightfieldRegion.STOREY_HEIGHT)
			elif rise <= -2 and here < home:
				height = minf(home,HeightfieldRegion.STOREY_HEIGHT*(result.storey_at(anchor.x,anchor.y)-1))
			if height == here: continue
			result.native_control_heights[point] = height
			changed = true
			budget -= 1
			assert(budget>=0,"Free-point grading exceeded its finite monotone bound")
	for point: Vector2i in free:
		if result.native_control_heights.has(point) \
				and absf(float(result.native_control_heights[point])-natural.surface_height(point.x,point.y)) < .00001:
			result.native_control_heights.erase(point)

## An accepted country road was routed over natural ground, so every road
## edge was walkable there: both 12 m point edges of each 24 m route edge were
## at most one storey apart (PathProgram.is_route_edge_walkable). The grade
## moves points near the road: pads and the collar's rounded blend. Relax the
## free road points along the road itself until every such point edge is
## walkable again: first lower a point standing two storeys over its road
## neighbour to one storey above it, then raise a point standing two storeys
## under its neighbour to one storey below it. The road is graded into the
## town one storey per 12 m point; ground beside the road keeps its grade.
## A route edge's middle point (2c + d) is a road point like its two ends.
## Town-claimed points and road points beyond the reach stay fixed, so a ramp
## stays within one route cell of the grade's bounds, inside its published
## control margin. Both passes move points monotonically by whole storeys:
## finite, and over the complete control domain independent of the chunk.
static func _grade_roads(grade: TerrainGradePatch, natural: HeightfieldRegion,
		result: HeightfieldRegion, owners: Dictionary) -> void:
	var reach := grade.bounds.grow(REACH)
	var free: Dictionary = {}
	var edges: Array = []
	for route: Array in _route_edges(grade):
		var cell: Vector2i = route[0]
		var d: Vector2i = route[1]
		var halves := PathProgram.route_point_edges(cell,d)
		var present := true
		for half: Array in halves:
			var a: Vector2i = half[0]
			present = present and natural.has_surface_point(a.x,a.y) \
				and natural.has_surface_point(a.x+d.x,a.y+d.y)
		# A route edge that was not walkable on natural ground is a bridge.
		if not present or not PathProgram.is_route_edge_walkable(natural,cell,d): continue
		for half: Array in halves:
			var a: Vector2i = half[0]
			var b: Vector2i = a+d
			edges.append([a,b])
			edges.append([b,a])
			for end: Vector2i in [a,b]:
				if reach.has_point(Vector2(end)*POINT) and is_free(grade,owners,end):
					free[end] = true
	var budget := maxi(1,free.size())*64
	for lowering: bool in [true,false]:
		var changed := true
		while changed:
			changed = false
			for edge: Array in edges:
				var point: Vector2i = edge[1]
				if not free.has(point): continue
				var anchor: float = result.surface_height(edge[0].x,edge[0].y)
				var rise: int = result.storey_at(point.x,point.y)-result.storey_at(edge[0].x,edge[0].y)
				if lowering and rise >= 2:
					result.native_control_heights[point] = anchor+HeightfieldRegion.STOREY_HEIGHT
				elif not lowering and rise <= -2:
					result.native_control_heights[point] = anchor-HeightfieldRegion.STOREY_HEIGHT
				else: continue
				changed = true
				budget -= 1
				assert(budget>=0,"Road grading exceeded its finite monotone bound")
	# A road point relaxed back onto its natural ground is not graded.
	for point: Vector2i in free:
		if result.native_control_heights.has(point) \
				and absf(float(result.native_control_heights[point])-natural.surface_height(point.x,point.y)) < .00001:
			result.native_control_heights.erase(point)

## The sealed road lattice as sorted [route cell, +x or +z direction] edges.
static func _route_edges(grade: TerrainGradePatch) -> Array:
	var edges: Array = []
	var cells: Array = grade.road_masks.keys()
	cells.sort()
	for cell: Vector2i in cells:
		for arm: Array in [[1,Vector2i(1,0)],[4,Vector2i(0,1)]]:
			if (int(grade.road_masks[cell]) & int(arm[0])) != 0:
				edges.append([cell,arm[1]])
	return edges

## Every 12 m lattice point a sealed road occupies: each road cell's own point
## and all points of its route edges' two point edges.
static func road_points(grade: TerrainGradePatch) -> Dictionary:
	var points: Dictionary = {}
	for cell: Vector2i in grade.road_masks:
		points[cell*PathProgram.POINTS_PER_ROUTE_CELL] = true
	for route: Array in _route_edges(grade):
		for half: Array in PathProgram.route_point_edges(route[0],route[1]):
			points[half[0]] = true
			points[half[0]+route[1]] = true
	return points

static func _height(value:float)->float:
	# Remove only numerical residue from inherited flat street samples. A real
	# fractional foundation datum keeps its exact elevation.
	return roundf(value) if absf(value-roundf(value))<.00001 else value

## Points the grade treats as construction (pad owners and regraded roads)
## for this natural region, after `controls` has run.
static func construction_cells(grade: TerrainGradePatch, source: HeightfieldRegion) -> Dictionary:
	var key = source.plan if source.plan != null else source
	return grade.native_construction_cache.get(key,{})

## Lattice points a fixed construction datum owns (point -> lowest datum over
## it): every corner of every 12 m tile the claim touches. Owners never move;
## every other control near the grade is free. Where claims at different
## datums share a tile corner, the lower datum owns it: the lower pad controls
## the transition, and the higher claim may stand over it.
static func pad_owners(grade: TerrainGradePatch) -> Dictionary:
	var owners: Dictionary = {}
	var fixed := fixed_claims(grade)
	for fine: Vector2i in fixed:
		var point := grade._origin+Vector2(fine)*grade._targets.pitch
		var radius := grade._targets.pitch*.5
		var height := _height(float(fixed[fine]))
		var own_lo := Vector2i(floori((point.x-radius)/POINT),floori((point.y-radius)/POINT))
		var own_hi := Vector2i(ceili((point.x+radius)/POINT),ceili((point.y+radius)/POINT))
		for z in range(own_lo.y,own_hi.y+1):
			for x in range(own_lo.x,own_hi.x+1):
				var key := Vector2i(x,z)
				owners[key]=minf(owners.get(key,INF),height)
	return owners

## A point the construction does not own: no fixed datum over it and no claim
## at it (streets included). Grading may move free points.
static func is_free(grade: TerrainGradePatch, owners: Dictionary, point: Vector2i) -> bool:
	var fine := Vector2i(((Vector2(point)*POINT-grade._origin)/grade._targets.pitch).round())
	return not owners.has(point) and not grade._claims.has(fine)

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
