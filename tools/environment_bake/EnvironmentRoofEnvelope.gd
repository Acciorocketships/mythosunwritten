extends RefCounted

## Offline native roof-skin partition. The other roof's upward triangles bound
## vertical prisms; their union removes only buried source stock. Every output
## vertex and attribute remains on an original triangle. This is a bake operation,
## never a terrain worker or runtime mesh repair.
const GEO = preload("res://tools/environment_bake/EnvironmentBakeGeometry.gd")
const BIN = .5
const MAX_INPUT_TRIANGLES = 16384
const MAX_OUTPUT_TRIANGLES = 65536
const MAX_FRAGMENT_COUNT = 4096
const MAX_COORDINATE = 32.0
const MAX_BUCKET_REFERENCES = 262144
static func distance(plane:Array, point:Vector3)->float:
	return float(plane[0])*point.x+float(plane[1])*point.y+float(plane[2])*point.z-float(plane[3])
static func clip(polygon: Array, plane: Array, positive: bool) -> Array:
	var out:Array=[]
	if polygon.is_empty(): return out
	var prev:Dictionary=polygon.back()
	var pd=distance(plane,prev.position)
	var inside=pd>0 if positive else pd<=0
	for cur:Dictionary in polygon:
		var cd=distance(plane,cur.position)
		var ci=cd>0 if positive else cd<=0
		if ci!=inside:
			var t=clampf(pd/(pd-cd),0,1)
			var v=GEO._interpolate_mesh_vertex(prev,cur,t,0,0)
			var a:Vector3=prev.position
			var b:Vector3=cur.position
			v.position=Vector3(float(a.x)+(float(b.x)-a.x)*t,float(a.y)+(float(b.y)-a.y)*t,float(a.z)+(float(b.z)-a.z)*t)
			out.append(v)
		if ci: out.append(cur)
		prev=cur
		pd=cd
		inside=ci
	return out
static func bucket_keys(box: AABB) -> Array[Vector2i]:
	var keys:Array[Vector2i]=[]
	for x in range(floori(box.position.x/BIN),floori(box.end.x/BIN)+1):
		for z in range(floori(box.position.z/BIN),floori(box.end.z/BIN)+1): keys.append(Vector2i(x,z))
	return keys
static func subtract(source: ArrayMesh, other: ArrayMesh, keep_coplanar: bool = false) -> ArrayMesh:
	if not _valid_mesh(source) or not _valid_mesh(other): return null
	var prisms:Array[Dictionary]=[]
	var buckets:Dictionary={}
	var bucket_references=0
	var faces=_faces(other)
	for f in range(0,faces.size(),3):
		var a:Vector3=faces[f]
		var b:Vector3=faces[f+1]
		var c:Vector3=faces[f+2]
		var ux=float(c.x)-a.x
		var uy=float(c.y)-a.y
		var uz=float(c.z)-a.z
		var vx=float(b.x)-a.x
		var vy=float(b.y)-a.y
		var vz=float(b.z)-a.z
		var normal=[uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx]
		var length=sqrt(normal[0]*normal[0]+normal[1]*normal[1]+normal[2]*normal[2])
		if length<1e-14 or normal[1]/length<.01: continue
		var planes:Array=[]
		for edge in [[a,b,c],[b,c,a],[c,a,b]]:
			var nx=float((edge[1] as Vector3).z)-(edge[0] as Vector3).z
			var nz=float((edge[0] as Vector3).x)-(edge[1] as Vector3).x
			var plane=[nx,0.0,nz,nx*(edge[0] as Vector3).x+nz*(edge[0] as Vector3).z]
			if distance(plane,edge[2])>0:
				for k in 4: plane[k]=-plane[k]
			planes.append(plane)
		planes.append([normal[0]/length,normal[1]/length,normal[2]/length,(normal[0]*a.x+normal[1]*a.y+normal[2]*a.z)/length])
		var bounds=AABB(a,Vector3.ZERO).expand(b).expand(c)
		var index=prisms.size()
		prisms.append({"planes":planes,"bounds":bounds})
		var keys=bucket_keys(bounds)
		bucket_references+=keys.size()
		if bucket_references>MAX_BUCKET_REFERENCES: return null
		for key in keys:
			if not buckets.has(key): buckets[key]=[]
			buckets[key].append(index)
	var result=ArrayMesh.new()
	var total=0
	for s in source.get_surface_count():
		var arrays=source.surface_get_arrays(s)
		var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
		if indices.is_empty():
			for i in arrays[Mesh.ARRAY_VERTEX].size(): indices.append(i)
		var st=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(source.surface_get_material(s))
		var count=0
		for offset in range(0,indices.size(),3):
			var polygon:Array=[]
			for i in 3: polygon.append(GEO._mesh_vertex(arrays,indices[offset+i]))
			var box=AABB(polygon[0].position,Vector3.ZERO).expand(polygon[1].position).expand(polygon[2].position)
			var candidates:Dictionary={}
			for key in bucket_keys(box):
				for index in buckets.get(key,[]): candidates[index]=true
			var remaining:Array=[polygon]
			for index in candidates:
				var prism:Dictionary=prisms[index]
				var bounds:AABB=prism.bounds
				if keep_coplanar:
					var top:Array=prism.planes.back()
					var coplanar=true
					for vertex:Dictionary in polygon: coplanar=coplanar and absf(distance(top,vertex.position))<.000001
					if coplanar: continue
				if box.position.y>=bounds.end.y+.000001 or box.position.x>=bounds.end.x or box.end.x<=bounds.position.x or box.position.z>=bounds.end.z or box.end.z<=bounds.position.z: continue
				var next:Array=[]
				for part:Array in remaining:
					var interior=part
					var pieces:Array=[]
					for plane:Array in prism.planes:
						var outside=clip(interior,plane,true)
						interior=clip(interior,plane,false)
						if outside.size()>=3: pieces.append(outside)
						if interior.size()<3: break
					if interior.size()<3: next.append(part)
					else: next.append_array(pieces)
				remaining=next
				if remaining.size()>MAX_FRAGMENT_COUNT: return null
				if remaining.is_empty(): break
			for part:Array in remaining:
				for fan in range(1,part.size()-1):
					var tri=[part[0],part[fan],part[fan+1]]
					if ((tri[1].position-tri[0].position) as Vector3).cross(tri[2].position-tri[0].position).length_squared()<1e-14: continue
					for v:Dictionary in tri:
						if v.has_normal: st.set_normal(v.normal)
						if v.has_uv: st.set_uv(v.uv)
						if v.has_uv2: st.set_uv2(v.uv2)
						if v.has_color: st.set_color(v.color)
						if v.has_tangent: st.set_tangent(Plane(v.tangent.x,v.tangent.y,v.tangent.z,v.tangent.w))
						st.add_vertex(v.position)
						count+=1
					if total+count/3>MAX_OUTPUT_TRIANGLES: return null
		if count>0:
			st.index()
			st.commit(result)
			result.surface_set_name(result.get_surface_count()-1,source.surface_get_name(s))
		total+=count/3
	print("PRISM_CUT ",faces.size()/3," cutter faces; ",total," output triangles")
	return result


static func _valid_mesh(mesh:ArrayMesh)->bool:
	if mesh==null or mesh.get_surface_count()==0: return false
	var triangles=0
	for surface in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: return false
		var arrays=mesh.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
		var count=vertices.size() if indices.is_empty() else indices.size()
		if count%3!=0: return false
		triangles+=count/3
		if triangles>MAX_INPUT_TRIANGLES: return false
		for index in indices:
			if index<0 or index>=vertices.size(): return false
		for vertex in vertices:
			if not vertex.is_finite() or maxf(absf(vertex.x),maxf(absf(vertex.y),absf(vertex.z)))>MAX_COORDINATE: return false
	return triangles>0


static func _faces(mesh:ArrayMesh)->PackedVector3Array:
	var faces=PackedVector3Array()
	for surface in mesh.get_surface_count():
		var arrays=mesh.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array and not arrays[Mesh.ARRAY_INDEX].is_empty():
			for index in arrays[Mesh.ARRAY_INDEX]: faces.append(vertices[index])
		else: faces.append_array(vertices)
	return faces
