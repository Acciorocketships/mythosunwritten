class_name GrassSupportSurfaces
extends RefCounted

const INDEX_CELL_SIZE := 2.0

static func spatial_index(surfaces:Array)->Dictionary:
	var cells:Dictionary={}
	# Preserve source order in each bucket: coincident highest faces must make
	# the same choice as the full scan, including at owner boundaries.
	for surface:Dictionary in surfaces:
		var bounds:Rect2=surface.bounds
		for x in range(floori(bounds.position.x/INDEX_CELL_SIZE),floori(bounds.end.x/INDEX_CELL_SIZE)+1):
			for z in range(floori(bounds.position.y/INDEX_CELL_SIZE),floori(bounds.end.y/INDEX_CELL_SIZE)+1):
				var key:=Vector2i(x,z)
				if not cells.has(key):cells[key]=[]
				cells[key].append(surface)
	return cells

static func at_index(cells:Dictionary,point:Vector2)->Dictionary:
	return at_point(cells.get(Vector2i(floori(point.x/INDEX_CELL_SIZE),floori(point.y/INDEX_CELL_SIZE)),[]),point)

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
