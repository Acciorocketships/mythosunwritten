extends RefCounted

## Exact flat native turf stock shared by physical ground and grass support.
static func measure(placement: Dictionary, faces: PackedVector3Array) -> Dictionary:
	var triangles:=PackedVector2Array()
	var edges:Dictionary={}
	var top:float=placement.top
	var pose:Transform3D=placement.transform
	for i in range(0,faces.size(),3):
		var a:=pose*faces[i]
		var b:=pose*faces[i+1]
		var c:=pose*faces[i+2]
		if absf(a.y-top)>.001 or absf(b.y-top)>.001 or absf(c.y-top)>.001:continue
		var points:=[Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)]
		for point:Vector2 in points:triangles.append(point)
		for j in 3:
			var start:Vector2=points[j]
			var finish:Vector2=points[(j+1)%3]
			# Source seams duplicate vertices, so identify a shared edge by its
			# world endpoints rather than by mesh indices.
			var key:=[start.snapped(Vector2.ONE*.00001),finish.snapped(Vector2.ONE*.00001)]
			if key[1]<key[0]:key.reverse()
			if edges.has(key):edges.erase(key)
			else:edges[key]=[start,finish]
	var border:=PackedVector2Array()
	for edge:Array in edges.values():border.append_array(edge)
	var box:AABB=placement.bounds
	return {"id":placement.id,"height":top,"triangles":triangles,"border":border,
		"bounds":Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))}

## Ordinary terrain collision is a walkable top and vertical sides. Decorative
## rock recesses and the turf underside must not catch an ascending character.
## Retain the actual cap outline instead of its enclosing rectangular bounds.
static func collision_faces(surface: Dictionary, bottom: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var triangles: PackedVector2Array = surface.triangles
	var top: float = surface.height
	assert(top > bottom and not triangles.is_empty())
	for i in range(0, triangles.size(), 3):
		for j in 3:
			var point := triangles[i + j]
			out.append(Vector3(point.x, top, point.y))
		for j in [2, 1, 0]:
			var point := triangles[i + j]
			out.append(Vector3(point.x, bottom, point.y))
	var border: PackedVector2Array = surface.border
	for i in range(0, border.size(), 2):
		var a := Vector3(border[i].x, top, border[i].y)
		var b := Vector3(border[i + 1].x, top, border[i + 1].y)
		var low_a := Vector3(a.x, bottom, a.z)
		var low_b := Vector3(b.x, bottom, b.z)
		out.append_array(PackedVector3Array([a, low_a, b, b, low_a, low_b]))
	return out
