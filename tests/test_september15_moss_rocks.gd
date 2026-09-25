extends GutTest

## Ledges are off by default for now (owner, September 24); these tests
## cover the ledge generator itself.
const _LEDGE_STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func before_all()->void:_LEDGE_STYLE.ledges=true
func after_all()->void:_LEDGE_STYLE.apply("chosen")

func test_reported_tall_face_uses_rock_formations_instead_of_small_cliff_tile_stacks()->void:
 var plan:=HeightfieldPlan.new(2697992464,128,32,"mean",4)
 plan.set_raw_height_override(func(cx:int,_cz:int)->float:return 16.0 if cx<=3 else 0.0)
 var mesher:=TerrainChunkMesher.new();mesher.prepare_resources();mesher.set_seed(2697992464)
 var region:=plan.compute_region(4,4,12)
 var result:=mesher.compute_chunk(Vector2i.ZERO,region)
 var native_stacks:=0;var rocks:=0
 for placement:Dictionary in result.cliff_terraces.placements:
  if String(placement.asset).begins_with("kaykit.terrace."):native_stacks+=1
  if placement.kind=="rock":rocks+=1
 assert_eq(native_stacks,0,"The owner rejected pyramids of the ordinary cliff tiles")
 assert_gt(rocks,5,"Broad outcrop groups should appear along the face")
 assert_eq(result.cliffs,CliffDressing.compute(region,0,0,8),"The original cliff/lip geometry is retained underneath")

func _walls()->Array:
 var out:=[]
 for x in range(-16,16):
  for y in 8:out.append(Transform3D(Basis.IDENTITY,Vector3(x*3+1.5,y*4,10.5)))
 return out

func test_canonical_face_partition_public_clearance_and_worker_determinism()->void:
 var rocks=preload("res://scripts/terrain/field/CliffRockDressing.gd")
 rocks.prepare()
 var full:=rocks.formations(_walls(),2697992464)
 var halves:=[[],[]]
 for pose:Transform3D in _walls():halves[0 if pose.origin.x<12 else 1].append(pose)
 var split:=rocks.formations(halves[0],2697992464)+rocks.formations(halves[1],2697992464)
 var a:=[];var b:=[]
 for p:Dictionary in full:a.append(str(p.asset)+str(p.transform))
 for p:Dictionary in split:b.append(str(p.asset)+str(p.transform))
 a.sort();b.sort()
 assert_eq(a,b,"Chunk edges cannot change the rock arrangement")
 var ids:Dictionary={}
 for p:Dictionary in full:ids[p.id]=true
 assert_eq(ids.size(),full.size(),"Each rock has one stable unique owner")
 var shape:=FeatureGroundShape.axis_rect(Rect2(Vector2(-1000,-1000),Vector2(2000,2000)))
 var context:=FeatureContext.new(shape.bounds(),FeatureGroundField.new([],[shape],0.0),EnvironmentInstancePayload.new())
 assert_eq(rocks.formations(_walls(),2697992464,null,context).size(),0,"The complete rock volume respects route reservation footprints")
 var worker:=Thread.new()
 assert_eq(worker.start(func()->Array:return rocks.formations(_walls(),2697992464)),OK)
 assert_eq(var_to_bytes(worker.wait_to_finish()),var_to_bytes(full),"A worker reads no live Mesh or Material")

func test_rock_solids_are_closed_outward_and_collision_uses_actual_faces()->void:
 var rocks=preload("res://scripts/terrain/field/CliffRockDressing.gd")
 rocks.prepare()
 for asset:StringName in rocks._definitions:
  if asset in rocks.PLANTS:continue
  var faces:PackedVector3Array=rocks._definitions[asset].faces
  var edges:Dictionary={};var volume:=0.0;var degenerate:=0
  var welded:Array[Vector3]=[];var indices:Array[int]=[]
  # Independent material surfaces quantize shared GLTF vertices separately.
  # Weld by measured import precision, rather than decimal buckets whose
  # boundaries can split nearby points. Measured cross-surface export
  # error is one 0.0001 step per coordinate (at most sqrt(3)*0.0001).
  for vertex:Vector3 in faces:
   var index:=-1
   for k in welded.size():
    if vertex.distance_to(welded[k])<.0002:index=k;break
   if index<0:index=welded.size();welded.append(vertex)
   indices.append(index)
  for i in range(0,faces.size(),3):
   var a:=faces[i];var b:=faces[i+1];var c:=faces[i+2]
   volume+=a.dot(c.cross(b))/6
   if (b-a).cross(c-a).length()<.000001:degenerate+=1
   for j in 3:
    var pair:=[indices[i+j],indices[i+(j+1)%3]]
    if pair[1]<pair[0]:pair.reverse()
    edges[pair]=int(edges.get(pair,0))+1
  var open_edges:=0
  for count:int in edges.values():
   if count!=2:open_edges+=1
  assert_eq(open_edges,0,String(asset)+": no open sheet or floating underside")
  assert_eq(degenerate,0,String(asset)+": no collapsed faces")
  assert_gt(volume,0.0,String(asset)+": outward winding")
  var visual:EnvironmentVisual=rocks._visuals[asset]
  var actual:=PackedVector3Array()
  for shape:EnvironmentCollisionPiece in visual.collisions:
   assert_true(shape.shape is ConcavePolygonShape3D)
   for p:Vector3 in shape.shape.get_faces():actual.append(shape.local_transform*p)
  assert_eq(actual.size(),faces.size(),"The complete source collision retains every triangle")
  var worst:=0.0
  for i in mini(actual.size(),faces.size()):worst=maxf(worst,actual[i].distance_to(faces[i]))
  assert_lt(worst,.0001,"Baked source collision agrees within import precision; runtime uses exact visual faces")

func test_roots_reach_terrain_and_new_rocks_never_raise_the_original_crown()->void:
 var rocks=preload("res://scripts/terrain/field/CliffRockDressing.gd")
 rocks.prepare()
 var plan:=HeightfieldPlan.new(2697992464,128,32,"mean",4)
 plan.set_raw_height_override(func(cx:int,_cz:int)->float:return 32.0 if cx<=3 else 0.0)
 var region:=plan.compute_region(4,4,12)
 var result:=rocks.compute(region,0,0,8,2697992464)
 var grounded:=0
 for p:Dictionary in result.placements:
  if p.kind!="rock":continue
  assert_lte(p.bounds.end.y,32.0,"The flat grass-grid crown is not changed")
  var lower:=INF
  for vertex:Vector3 in rocks._faces(p):
   var q:Vector3=p.transform*vertex
   lower=minf(lower,TerrainSurfaceField.surface_y(region,q.x,q.z))
  assert_lte(p.bounds.position.y,lower-.10,"Roots reach the actual neighboring terrace, including the native intermediate 16 m step")
  grounded+=1
 assert_gt(grounded,5)
 assert_gt(result.collision_faces.size(),0)

func test_foliage_keeps_native_leaf_geometry_and_excludes_round_bushes()->void:
 var rocks=preload("res://scripts/terrain/field/CliffRockDressing.gd")
 rocks.prepare()
 var native:EnvironmentVisual=load("res://terrain/environment/visuals/native_cliff_foliage/quaternius_cliff_fern.tres")
 var adapted:EnvironmentVisual=rocks._visuals[rocks.PLANTS[0]]
 assert_eq(adapted.pieces[0].mesh.get_faces(),native.pieces[0].mesh.get_faces(),"Biome material adaptation keeps native fronds")
 assert_false(&"kaykit.bush.01" in rocks.PLANTS,"Owner rejected spherical bushes on cliff ledges")


func test_real_adjacent_chunks_share_rock_and_plant_ownership()->void:
 var rocks=preload("res://scripts/terrain/field/CliffRockDressing.gd")
 rocks.prepare()
 var plan:=HeightfieldPlan.new(2697992464,128,32,"mean",4)
 plan.set_raw_height_override(func(_cx:int,cz:int)->float:return 24.0 if cz<=3 else 0.0)
 var region:=plan.compute_region(8,4,20)
 var all:=rocks.compute(region,0,0,16,2697992464)
 var a:=rocks.compute(region,0,0,8,2697992464)
 var b:=rocks.compute(region,8,0,8,2697992464)
 var expected:Dictionary={};var actual:Dictionary={}
 for p:Dictionary in all.placements:
  # Compare the same 16x8 footprint; the larger query includes another row.
  if p.kind=="rock" and p.anchor.z>=180:continue
  if p.kind=="foliage":
   var owner_found:bool=p.has("anchor") and p.anchor.z<180
   for rock:Dictionary in all.placements:
    if rock.kind=="rock" and rock.id==p.support_id and rock.anchor.z<180:owner_found=true;break
   if not owner_found:continue
  expected[p.id]=[p.transform,rocks._faces(p)] if p.kind=="rock" else [p.transform,p.support_point,p.support_normal]
 for p:Dictionary in a.placements+b.placements:
  assert_false(actual.has(p.id),"An overlapping halo never emits its neighbor's formation")
  actual[p.id]=[p.transform,rocks._faces(p)] if p.kind=="rock" else [p.transform,p.support_point,p.support_normal]
 assert_eq(actual,expected,"Rock shape and exposed plant sites survive real chunk boundaries")

func test_committed_rock_ledges_hold_actual_physics_probes()->void:
 var rocks=preload("res://scripts/terrain/field/CliffRockDressing.gd")
 var plan:=HeightfieldPlan.new(2697992464,128,32,"mean",4)
 plan.set_raw_height_override(func(cx:int,_cz:int)->float:return 16.0 if cx<=3 else 0.0)
 var region:=plan.compute_region(4,4,12)
 var mesher:=TerrainChunkMesher.new();mesher.prepare_resources();mesher.set_seed(2697992464)
 var data:=mesher.compute_chunk(Vector2i.ZERO,region)
 var node:=mesher.commit_chunk(data);add_child_autofree(node)
 await get_tree().physics_frame
 await get_tree().physics_frame
 var space:=node.get_world_3d().direct_space_state
 var checked:=0
 for p:Dictionary in data.cliff_terraces.placements:
  if p.kind!="rock":continue
  var faces:PackedVector3Array=rocks._green(p)
  for i in range(0,faces.size(),3):
   var a:Vector3=p.transform*faces[i];var b:Vector3=p.transform*faces[i+1];var c:Vector3=p.transform*faces[i+2]
   if (c-a).cross(b-a).normalized().y<.7:continue
   var point:Vector3=(a+b+c)/3
   if TerrainSurfaceField.surface_y(region,point.x,point.z)>=point.y-.1:continue
   var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.03,point-Vector3.UP*.03))
   assert_false(hit.is_empty(),"Every sampled exposed green ledge has matching physics")
   if hit.is_empty():continue
   assert_almost_eq((hit.position as Vector3).y,point.y,.01)
   var body:=hit.collider as StaticBody3D
   assert_eq((body.shape_owner_get_owner(body.shape_find_owner(hit.shape)) as Node).name,&"CliffRocks")
   checked+=1
   break
 assert_gt(checked,5)

func test_outcrops_leave_native_wall_visible_in_four_orientations()->void:
 var rocks=preload("res://scripts/terrain/field/CliffRockDressing.gd")
 rocks.prepare()
 for turn in 4:
  var basis:=Basis(Vector3.UP,turn*PI*.5)
  var walls:=[]
  for x in range(-16,16):
   for y in 4:walls.append(Transform3D(basis,basis*Vector3(x*3+1.5,y*4,10.5)))
  var placements:=rocks.formations(walls,2697992464)
  var covered:=0;var total:=0
  for x in 40:
   for y in 16:
    var origin:=basis*Vector3(-23.4+x*1.2,.2+y*.97,10.5)
    var end:=origin+basis.z*8
    var found:=false
    for p:Dictionary in placements:
     if not (p.bounds as AABB).intersects_segment(origin,end):continue
     var inverse:Transform3D=p.transform.affine_inverse()
     var a:=inverse*origin;var b:=inverse*end
     var faces:PackedVector3Array=rocks._faces(p)
     for i in range(0,faces.size(),3):
      if Geometry3D.segment_intersects_triangle(a,b,faces[i],faces[i+1],faces[i+2])!=null:
       found=true;break
     if found:break
    total+=1
    if found:covered+=1
  print("MOSS_COVERAGE turn=",turn," covered=",covered," total=",total)
  assert_gt(float(covered)/total,.30,"Outcrops remain a substantial part of the cliff")
  assert_lt(float(covered)/total,.90,"September 16: retain visible original wall instead of a continuous facade")
