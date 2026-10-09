extends RefCounted
func run(review:Node)->void:
	for spec:Array in [["production_refiner",3.0,1.5,2.0]]:
		await _trial(review,spec)
func _trial(review:Node,spec:Array)->void:
	var contour:=GDScript.new()
	contour.source_code=FileAccess.get_file_as_string("res://scripts/terrain/water/WaterContour.gd").replace("class_name WaterContour", "").replace("const STEP := 3.0", "const STEP := %.3f" % spec[1]).replace("const SPACING := 1.5", "const SPACING := %.3f" % spec[2])
	if contour.reload()!=OK:return
	var skin:=GDScript.new()
	skin.source_code=FileAccess.get_file_as_string("res://scripts/terrain/water/WaterSkin.gd").replace("class_name WaterSkin", "").replace("const STEP := 2.0", "const STEP := %.3f" % spec[3])

	if skin.reload()!=OK:return
	var water:WaterFieldContext=review._inputs[Vector2i(-1,5)].water
	var ctx:=water.raw_context()
	var rect:=Rect2(-42,1134,24,24)
	var started:=Time.get_ticks_msec()
	var curves:Array=contour.curves(ctx,rect)
	var st:Dictionary={"ctx":ctx,"region":water._region,"rect":rect,"curves":curves,"buckets":skin._build_buckets(curves),
		"verts":PackedVector3Array(),"idx":PackedInt32Array(),"weld":{},"normal_accum":PackedVector3Array(),"arclen":{},"profiles":{}}
	var lattice:Dictionary=skin._interior_lattice(st)
	skin._interior_mesh(st,lattice)
	lattice["ring_owner"]=skin._assign_ring_owners(lattice,curves)
	for ci in curves.size():
		skin._boundary_strip(st,lattice,curves[ci],ci)
		skin._rim(st,curves[ci])
	skin._seal_local_surface_holes(st)
	var refine:=GDScript.new()
	refine.source_code=FileAccess.get_file_as_string("res://scripts/terrain/water/WaterSurfaceRefinement.gd")
	if refine.reload()!=OK:return
	var before_edges:=_free_edges(st)
	var refine_started:=Time.get_ticks_usec()
	print("ADAPTIVE_STATS ",refine.refine(st,func(p:Vector2)->float:return WaterField.level_at(ctx,p))," ms=",(Time.get_ticks_usec()-refine_started)/1000.0)
	var after_edges:=_free_edges(st)
	var new_open:=0
	for edge:Array in after_edges:
		var inherited:=false
		for prior:Array in before_edges:
			if _on_segment(edge[0],prior[0],prior[1]) and _on_segment(edge[1],prior[0],prior[1]):inherited=true;break
		if not inherited:
			new_open+=1
			print("ADAPTIVE_NEW_EDGE ",edge)
	print("ADAPTIVE_EDGE_AUDIT before=",before_edges.size()," after=",after_edges.size()," new_open=",new_open)
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=st.verts;arrays[Mesh.ARRAY_INDEX]=st.idx;arrays[Mesh.ARRAY_NORMAL]=skin._bake_normals(st)
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var originals:Array[Node3D]=[]
	for node:Node in review.get_tree().get_nodes_in_group("water_surface"):
		originals.append(node);node.remove_from_group("water_surface")
	var root:=Node3D.new();root.name="ResolutionTrial"
	var instance:=MeshInstance3D.new();instance.name="WaterSheet";instance.mesh=mesh
	root.add_child(instance);review.add_child(root);root.add_to_group("water_surface")
	var checker:=GDScript.new();checker.source_code=FileAccess.get_file_as_string("res://tests/harness/october9_water_mesh_clearance.gd")
	if checker.reload()==OK:await checker.new().run(review)
	DirAccess.rename_absolute(review._output_dir+"/water-mesh-clearance.json",review._output_dir+"/water-mesh-clearance-"+str(spec[0])+".json")
	root.free()
	for node:Node3D in originals:node.add_to_group("water_surface")
	print("WATER_RESOLUTION_TRIAL variant=",spec[0]," verts=",st.verts.size()," tris=",st.idx.size()/3," ms=",Time.get_ticks_msec()-started)

func _free_edges(st:Dictionary)->Array:
	var counts:= {}
	for ti in range(0,st.idx.size(),3):
		for k in 3:
			var a:int=st.idx[ti+k];var b:int=st.idx[ti+(k+1)%3]
			var edge:=Vector2i(mini(a,b),maxi(a,b))
			counts[edge]=int(counts.get(edge,0))+1
	var result:=[]
	for edge:Vector2i in counts:
		if counts[edge]==1:result.append([st.verts[edge.x],st.verts[edge.y]])
	return result
func _on_segment(p:Vector3,a:Vector3,b:Vector3)->bool:
	return Geometry3D.get_closest_point_to_segment(p,a,b).distance_to(p)<.002
