class_name GrassSupportSurfaces
extends RefCounted

const INDEX_CELL_SIZE := 2.0

static func spatial_index(surfaces:Array)->Dictionary:
	var cells:Dictionary={}
	# Preserve source order in each bucket: coincident highest faces must make
	# the same choice as the full scan, including at owner boundaries.
	for surface:Dictionary in surfaces:
		if surface.has("grid"):
			# A heightfield support is looked up directly, not bucketed.
			if not cells.has(&"grids"):cells[&"grids"]=[]
			cells[&"grids"].append(surface)
			continue
		var bounds:Rect2=surface.bounds
		for x in range(floori(bounds.position.x/INDEX_CELL_SIZE),floori(bounds.end.x/INDEX_CELL_SIZE)+1):
			for z in range(floori(bounds.position.y/INDEX_CELL_SIZE),floori(bounds.end.y/INDEX_CELL_SIZE)+1):
				var key:=Vector2i(x,z)
				if not cells.has(key):cells[key]=[]
				cells[key].append(surface)
	return cells

static func at_index(cells:Dictionary,point:Vector2)->Dictionary:
	var result:=at_point(cells.get(Vector2i(floori(point.x/INDEX_CELL_SIZE),floori(point.y/INDEX_CELL_SIZE)),[]),point)
	for grid:Dictionary in cells.get(&"grids",[]):
		var sample:=at_grid(grid,point)
		if not sample.is_empty() and (result.is_empty() or float(sample.y)>float(result.y)):result=sample
	return result

## Heightfield support (the `sheet` style's whole-wall slope): grass grows on
## its gentle ground and thins out as it steepens. `flags` marks the nodes the
## slope covers (off under its rocks); `over_ground` lets it stand in for the
## terrain it lies on, flush or above.
const GRID_MIN_UP:=.62
const GRID_FULL_UP:=.9
static func at_grid(grid:Dictionary,point:Vector2)->Dictionary:
	var step:float=grid.step
	var p:Vector2=(point-(grid.origin as Vector2))/step
	var i:=floori(p.x);var k:=floori(p.y)
	var w:int=grid.w;var h:int=grid.h
	if i<0 or k<0 or i>=w-1 or k>=h-1:return {}
	var flags:PackedByteArray=grid.flags
	if not (flags[k*w+i] and flags[k*w+i+1] and flags[(k+1)*w+i] and flags[(k+1)*w+i+1]):return {}
	var heights:PackedFloat32Array=grid.heights
	var a:=heights[k*w+i];var b:=heights[k*w+i+1];var c:=heights[(k+1)*w+i];var d:=heights[(k+1)*w+i+1]
	var fx:=p.x-i;var fz:=p.y-k
	var y:=lerpf(lerpf(a,b,fx),lerpf(c,d,fx),fz)
	var gx:=(lerpf(b-a,d-c,fz))/step;var gz:=(lerpf(c-a,d-b,fx))/step
	var normal:=Vector3(-gx,1.0,-gz).normalized()
	# Too steep for grass still claims the point (edge distance 0 grows
	# nothing): falling back to the terrain below let blades rooted under the
	# slope poke their tips through it.
	return {"y":y,"normal":normal,"edge_distance":4.0*smoothstep(GRID_MIN_UP,GRID_FULL_UP,normal.y),
		"support_id":grid.id,"over_ground":true}

# Detached native top triangles extend the ordinary grass sampler. Only flat
# authored turf tops are eligible; bounding boxes never stand in for a cap.
static func from_native(placement: Dictionary, faces: PackedVector3Array) -> Dictionary:
	var surface := preload("res://scripts/terrain/field/NativeTerrainCap.gd").measure(placement, faces)
	surface["obstacles"] = []
	return surface

static func at_point(surfaces:Array, point:Vector2)->Dictionary:
	var result:Dictionary={}
	for surface:Dictionary in surfaces:
		if not (surface.bounds as Rect2).has_point(point):continue
		if not surface.has("face") and not result.is_empty() and surface.height<=result.y:continue
		var triangles:PackedVector2Array=surface.triangles
		var inside:=false
		var height:float=surface.height
		var normal:=Vector3.UP
		for i in range(0,triangles.size(),3):
			var a:=triangles[i];var b:=triangles[i+1];var c:=triangles[i+2]
			var area:float=(b-a).cross(c-a)
			if absf(area)<.000001:continue
			var u:float=(b-point).cross(c-point)/area
			var v:float=(c-point).cross(a-point)/area
			if u>=-.000001 and v>=-.000001 and u+v<=1.000001:
				inside=true
				if surface.has("face"):
					var face:PackedVector3Array=surface.face
					height=u*face[0].y+v*face[1].y+(1-u-v)*face[2].y
					normal=surface.normal
				break
		if not inside or (not result.is_empty() and height<=result.y):continue
		var buried:=false
		for polygon:PackedVector2Array in surface.get("polygon_obstacles",[]):
			if Geometry2D.is_point_in_polygon(point,polygon):buried=true;break
		if buried:continue
		var distance:=INF
		var border:PackedVector2Array=surface.border
		for i in range(0,border.size(),2):
			var a:=border[i];var delta:=border[i+1]-a
			var t:=clampf((point-a).dot(delta)/maxf(delta.length_squared(),.000001),0,1)
			distance=minf(distance,point.distance_to(a+delta*t))
		for polygon:PackedVector2Array in surface.get("polygon_obstacles",[]):
			for i in polygon.size():
				var a:=polygon[i];var delta:=polygon[(i+1)%polygon.size()]-a
				var t:=clampf((point-a).dot(delta)/maxf(delta.length_squared(),.000001),0,1)
				distance=minf(distance,point.distance_to(a+delta*t))
		for obstacle:Rect2 in surface.obstacles:
			var delta:=Vector2(maxf(maxf(obstacle.position.x-point.x,0),point.x-obstacle.end.x),
				maxf(maxf(obstacle.position.y-point.y,0),point.y-obstacle.end.y))
			distance=minf(distance,delta.length())
		result={"y":height,"normal":normal,"edge_distance":distance,"support_id":surface.id}
	return result
