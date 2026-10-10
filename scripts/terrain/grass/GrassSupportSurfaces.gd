class_name GrassSupportSurfaces
extends RefCounted

const INDEX_CELL_SIZE := 2.0

static func spatial_index(surfaces:Array)->Dictionary:
	var cells:Dictionary={}
	# Preserve source order in each bucket: coincident highest faces must make
	# the same choice as the full scan, including at owner boundaries.
	for surface:Dictionary in surfaces:
		if surface.has("grid"):
			# Rock skirts are grids too. Scanning every skirt in a 192 m chunk
			# at each blade/footprint probe made a tile take several seconds.
			# Bucket their domains, preserving source order and the exact sampler.
			if not cells.has(&"grids"):cells[&"grids"]={}
			var grids:Dictionary=cells[&"grids"]
			var origin:Vector2=surface.origin
			var end:=origin+Vector2(int(surface.w)-1,int(surface.h)-1)*float(surface.step)
			for x in range(floori(origin.x/INDEX_CELL_SIZE),floori(end.x/INDEX_CELL_SIZE)+1):
				for z in range(floori(origin.y/INDEX_CELL_SIZE),floori(end.y/INDEX_CELL_SIZE)+1):
					var key:=Vector2i(x,z)
					if not grids.has(key):grids[key]=[]
					grids[key].append(surface)
			continue
		var bounds:Rect2=surface.bounds
		for x in range(floori(bounds.position.x/INDEX_CELL_SIZE),floori(bounds.end.x/INDEX_CELL_SIZE)+1):
			for z in range(floori(bounds.position.y/INDEX_CELL_SIZE),floori(bounds.end.y/INDEX_CELL_SIZE)+1):
				var key:=Vector2i(x,z)
				if not cells.has(key):cells[key]=[]
				cells[key].append(surface)
	return cells

static func at_index(cells:Dictionary,point:Vector2)->Dictionary:
	var key:=Vector2i(floori(point.x/INDEX_CELL_SIZE),floori(point.y/INDEX_CELL_SIZE))
	var result:=at_point(cells.get(key,[]),point)
	var blocked:=false
	for grid:Dictionary in (cells.get(&"grids",{}) as Dictionary).get(key,[]):
		var sample:=at_grid(grid,point)
		blocked=blocked or bool(sample.get("blocked",false))
		if not sample.is_empty() and (result.is_empty() or float(sample.y)>float(result.y)):result=sample
	# Nestled rocks overlap (September 27 judging): a point under any rock
	# grows no grass, even where a neighbour's skirt is the higher surface.
	if blocked and not result.is_empty():
		result=result.duplicate();result.edge_distance=0.0
	return result

## Heightfield support (the `sheet` style's whole-wall slope): grass grows on
## its gentle ground and thins out as it steepens. `flags` marks the nodes the
## slope covers (off under its rocks); `over_ground` lets it stand in for the
## terrain it lies on, flush or above.
## The moss band (SlopeProfile.grass_scale): full grass on lawn, none on moss.
const GRID_MIN_UP:=1.0-SlopeProfile.MOSS_STEEPNESS
const GRID_FULL_UP:=1.0-SlopeProfile.LAWN_STEEPNESS
static func at_grid(grid:Dictionary,point:Vector2)->Dictionary:
	var step:float=grid.step
	var p:Vector2=(point-(grid.origin as Vector2))/step
	var i:=floori(p.x);var k:=floori(p.y)
	var w:int=grid.w;var h:int=grid.h
	if i<0 or k<0 or i>=w-1 or k>=h-1:return {}
	var flags:PackedByteArray=grid.flags
	if grid.has("mesh_faces") and not (grid.mesh_faces as PackedVector3Array).is_empty():
		return _at_mesh(grid,point,i,k)
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
		"support_id":grid.id,"over_ground":true,"lift":_lift(grid,i,k,fx,fz)}

## A slope's surface-net triangles differ from bilinear envelope heights at
## carved benches. Reuse the rendered faces and bucket their XZ footprints.
static func index_mesh(faces:PackedVector3Array,origin:Vector2,step:float)->Dictionary:
	var cells:={}
	for t in range(0,faces.size(),3):
		var a:=Vector2(faces[t].x,faces[t].z);var b:=Vector2(faces[t+1].x,faces[t+1].z);var c:=Vector2(faces[t+2].x,faces[t+2].z)
		if absf((b-a).cross(c-a))<.000001:continue
		var lo:=Vector2i(((a.min(b).min(c)-origin)/step).floor())
		var hi:=Vector2i(((a.max(b).max(c)-origin)/step).floor())
		for z in range(lo.y,hi.y+1):
			for x in range(lo.x,hi.x+1):
				var key:=Vector2i(x,z)
				if not cells.has(key):cells[key]=[]
				cells[key].append(t)
	return cells

static func _at_mesh(grid:Dictionary,point:Vector2,i:int,k:int)->Dictionary:
	if grid.has("mesh_bounds") and not (grid.mesh_bounds as Rect2).has_point(point):return {}
	var faces:PackedVector3Array=grid.mesh_faces
	var height:=-INF;var normal:=Vector3.UP
	for t:int in grid.mesh_cells.get(Vector2i(i,k),[]):
		var a:=faces[t];var b:=faces[t+1];var c:=faces[t+2]
		var aa:=Vector2(a.x,a.z);var bb:=Vector2(b.x,b.z);var cc:=Vector2(c.x,c.z)
		var area:float=(bb-aa).cross(cc-aa)
		var u:float=(bb-point).cross(cc-point)/area
		var v:float=(cc-point).cross(aa-point)/area
		if u<-.000001 or v<-.000001 or u+v>1.000001:continue
		var y:=a.y*u+b.y*v+c.y*(1.0-u-v)
		if y>height:
			height=y;normal=(c-a).cross(b-a).normalized()
			if normal.y<0.0:normal=-normal
	var w:int=grid.w;var flags:PackedByteArray=grid.flags
	var ids:=[k*w+i,k*w+i+1,(k+1)*w+i,(k+1)*w+i+1]
	var blocked:=false;var claimed:=false
	for idx:int in ids:
		blocked=blocked or flags[idx]==2
		claimed=claimed or flags[idx]!=0
	if not is_finite(height):
		if not claimed:return {}
		# Missing replacement cannot grow grass via the buried native ground.
		height=grid.heights[k*w+i];blocked=true
	var p:Vector2=(point-(grid.origin as Vector2))/float(grid.step)
	return {"y":height,"normal":normal,"edge_distance":0.0 if blocked else 4.0*smoothstep(GRID_MIN_UP,GRID_FULL_UP,normal.y),
		"support_id":grid.id,"over_ground":true,"mesh_support":true,"blocked":blocked,"lift":_lift(grid,i,k,p.x-i,p.y-k)}

## Height the slope stands over the terrain ground (INF when unknown).
static func _lift(grid:Dictionary,i:int,k:int,fx:float,fz:float)->float:
	if not grid.has("lifts"):return INF
	var lifts:PackedFloat32Array=grid.lifts;var w:int=grid.w
	return lerpf(lerpf(lifts[k*w+i],lifts[k*w+i+1],fx),lerpf(lifts[(k+1)*w+i],lifts[(k+1)*w+i+1],fx),fz)

## How far a clump's root plane may stand over or sink into the slope under
## it. Terrain grass takes the terrain's normal at its root and floats over
## the kernel's convex bends by up to 0.2-0.4 m; a stricter test on the slope
## sheet (6 cm) shrank every clump on a rounded crest to a quarter size, so
## dense terrain grass ended in a line where the sheet took over (September
## 29 seams). Benches and folds still fail and shrink the clump.
const FOOTPRINT_FLOAT := .2
const FOOTPRINT_SINK := .25

## A broad clump needs support beneath its whole root plane, not just its centre.
static func footprint_scale(cells:Dictionary,point:Vector2,support:Dictionary,radius:float,ground_at:=Callable())->float:
	if not support.get("mesh_support",false):return 1.0
	var normal:Vector3=support.normal
	for scale:float in [1.0,.75,.5,.25]:
		var clear:=true
		for ring:float in [.5,1.0]:
			for i in 8:
				var offset:=Vector2.from_angle(i*PI*.25)*radius*scale*ring
				var receiver:=at_index(cells,point+offset)
				if receiver.is_empty() and ground_at.is_valid():receiver={"y":float(ground_at.call(point+offset)),"edge_distance":1.0}
				if receiver.is_empty() or float(receiver.edge_distance)<=0.0:
					clear=false;break
				var plane_y:float=support.y-Vector2(normal.x,normal.z).dot(offset)/normal.y
				var gap:float=plane_y-float(receiver.y)
				if gap>FOOTPRINT_FLOAT or gap<-FOOTPRINT_SINK:
					clear=false;break
			if not clear:break
		if clear:return scale
	return 0.0

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
		if surface.get("feature_garden",false): result["feature_garden"] = true
	return result
