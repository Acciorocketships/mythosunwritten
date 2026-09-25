extends GutTest
const Terraces=preload("res://scripts/terrain/field/CliffTerraces.gd")

func test_native_faces_share_one_exposed_edge_across_stock_depths() -> void:
 Terraces.prepare()
 var plan:=HeightfieldPlan.new(17,64,12,"mean",4)
 plan.set_raw_height_override(func(cx:int,_cz:int)->float:return 8.0 if cx<=3 else 0.0)
 var region:=plan.compute_region(4,4,12)
 var fronts:Array[float]=[]
 var depths:Dictionary={}
 for seed_value in 4:
  for p:Dictionary in Terraces.compute(region,0,0,8,seed_value).placements:
   if p.kind!="face":continue
   var cap:=preload("res://scripts/terrain/field/NativeTerrainCap.gd").measure(p,Terraces._definitions[p.asset].faces)
   var extent:float=-INF
   for v:Vector2 in cap.border:extent=maxf(extent,(v-Vector2(p.owner)*24).dot(p.outward))
   fronts.append(extent)
   depths[Terraces._definitions[p.asset].bounds.size.z]=true
 assert_gt(depths.size(),1,"Both native depth families are exercised")
 var minimum:float=fronts.min()
 var maximum:float=fronts.max()
 assert_lt(maximum-minimum,.001,"Equal cliff runs must not alternate arbitrary projections")

func test_native_rock_bodies_intersect_their_actual_cliff_at_each_height() -> void:
 Terraces.prepare()
 var checked:Dictionary={}
 var gaps:Array=[]
 for orientation in 4:
  for kind:String in ["face","outer","inner"]:
   var plan:=HeightfieldPlan.new(17,64,12,"mean",4)
   plan.set_raw_height_override(func(cx:int,cz:int)->float:
    var rotated:Vector2=Vector2(cx-3.5,cz-3.5).rotated(orientation*PI*.5)+Vector2.ONE*3.5
    cx=roundi(rotated.x)
    cz=roundi(rotated.y)
    if kind=="face":return 16.0 if cx<=3 else 0.0
    if kind=="outer":return 16.0 if cx<=3 and cz<=3 else 0.0
    return 0.0 if cx>3 and cz>3 else 16.0)
   var region:=plan.compute_region(4,4,12)
   var cliffs:=CliffDressing.compute(region,0,0,8)
   var walls:Array[Dictionary]=[]
   for key:String in ["wall","outer_wall","inner_wall"]:
    var piece:Array=CliffDressing._pieces[key]
    var faces:PackedVector3Array=piece[0].get_faces()
    for pose:Transform3D in cliffs[key]:
     var actual:Transform3D=pose*piece[1]
     var box:=AABB(actual*faces[0],Vector3.ZERO)
     for v:Vector3 in faces:box=box.expand(actual*v)
     walls.append({"pose":actual,"faces":faces,"bounds":box})
   for seed_value in 4:
    for p:Dictionary in Terraces.compute(region,0,0,8,seed_value).placements:
     if p.kind!=kind:continue
     checked[kind]=int(checked.get(kind,0))+1
     var pose:Transform3D=p.transform
     var outward:=Vector3(p.outward.x,0,p.outward.y)
     for f:float in [.11,.21,.49,.79,.91]:
      var point:=Vector3(pose.origin.x,lerpf(p.base,p.top,f),pose.origin.z)+Vector3(-outward.z,0,outward.x)*.017
      var a:=point+outward*8
      var b:=point-outward*8
      var rear:float=INF
      for hit:Vector3 in _hits(a,b,Terraces._definitions[p.asset].faces,pose):rear=minf(rear,hit.dot(outward))
      var front:float=-INF
      for wall:Dictionary in walls:
       if not (wall.bounds as AABB).grow(.001).intersects_segment(a,b):continue
       for hit:Vector3 in _hits(a,b,wall.faces,wall.pose):front=maxf(front,hit.dot(outward))
      if rear>front-.03:gaps.append({"id":p.id,"asset":p.asset,"height":f,"gap":rear-front})
 print("TERRACE_SEATING checked=",checked," gaps=",gaps.size())
 assert_eq(checked.size(),3,"Faces and both corner kinds retain native columns")
 assert_eq(gaps.size(),0,"Native cliff/ledge rock bodies must overlap at every sampled height: %s"%str(gaps))

func _hits(a:Vector3,b:Vector3,faces:PackedVector3Array,pose:Transform3D)->Array[Vector3]:
 var out:Array[Vector3]=[]
 var inverse:=pose.affine_inverse()
 var start:=inverse*a
 var finish:=inverse*b
 for i in range(0,faces.size(),3):
  var hit:Variant=Geometry3D.segment_intersects_triangle(start,finish,faces[i],faces[i+1],faces[i+2])
  if hit!=null:out.append(pose*hit)
 return out
