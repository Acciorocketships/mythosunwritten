extends GutTest

func test_frozen_covered_passage_receives_one_native_arch_at_its_mouth() -> void:
 var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var frozen:=preload("res://tests/fixtures/frozen_maze_source.gd")
 var fabric:=frozen.spatial(frozen.read("res://tests/fixtures/september9-offset-source.txt"),program).compiled_fabric_cache()
 var arches:Array=[]
 for placement in fabric.expanded_placements():
  if String(placement.stable_id).begins_with("tunnel-mouth/"):arches.append(placement)
 assert_eq(arches.size(),1,"The real covered passage between two masonry walls needs an attached entrance arch")
 if arches.size()!=1:return
 assert_eq(arches[0].asset_id,&"sfv.fabric.tunnel_arch.001")
 assert_true((arches[0].transform.origin as Vector3).is_equal_approx(Vector3(-0.65,0,0.75)))
 assert_true(fabric.asset_ids().has(&"sfv.fabric.tunnel_arch.001"))
 assert_true(SettlementFabricAssembler.payload(fabric).batches.has(&"sfv.fabric.tunnel_arch.001"))

func test_native_collision_matches_the_frame_and_leaves_full_walking_headroom() -> void:
 var descriptor:=EnvironmentCatalog.load_default().descriptor(&"sfv.fabric.tunnel_arch.001")
 var visual:=load(descriptor.visual_path) as EnvironmentVisual
 assert_eq(visual.collisions.size(),1)
 assert_true(visual.collisions[0].shape is ConcavePolygonShape3D)
 var mesh_faces:=PackedVector3Array()
 for piece in visual.pieces:mesh_faces.append_array(piece.local_transform*piece.mesh.get_faces())
 var collision_faces:PackedVector3Array=visual.collisions[0].local_transform*(visual.collisions[0].shape as ConcavePolygonShape3D).get_faces()
 assert_eq(mesh_faces.size(),collision_faces.size(),"Every native triangle has collision")
 var visual_points:Dictionary={}
 var collision_points:Dictionary={}
 for point in mesh_faces:visual_points[point]=true
 for point in collision_faces:collision_points[point]=true
 var deviation:=0.0
 for point:Vector3 in visual_points:
  var nearest:=INF
  for other:Vector3 in collision_points:nearest=minf(nearest,point.distance_to(other))
  deviation=maxf(deviation,nearest)
 assert_lt(deviation,0.0002,"Only native GPU vertex compression may separate visual and collision vertices")
 var header:=INF
 for v in mesh_faces:
  if absf(v.x)<1.25:header=minf(header,v.y)
 print("TUNNEL_NATIVE vertex_deviation=",deviation," header=",header," triangles=",mesh_faces.size()/3)
 assert_gt(header,TraversalEnvelope.MIN_HEADROOM)
 var hit_count:=0
 for turn in 4:
  var pose:=Transform3D(Basis(Vector3.UP,turn*PI/2),Vector3(4,2,-7))
  for x:float in [-1.2,-0.75,0,0.75,1.2]:
   for y:float in [0.05,0.5,1,1.5,2,2.4]:
    for i in range(0,collision_faces.size(),3):
     if Geometry3D.segment_intersects_triangle(pose*Vector3(x,y,-0.5),pose*Vector3(x,y,0.5),pose*collision_faces[i],pose*collision_faces[i+1],pose*collision_faces[i+2])!=null:hit_count+=1
 assert_eq(hit_count,0,"The full two-lane body envelope stays clear in four orientations")

func test_missing_jamb_or_ceiling_does_not_create_a_floating_arch() -> void:
 var helper:=preload("res://scripts/terrain/features/villages/fabric/WarrenTunnelArches.gd")
 var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var frozen:=preload("res://tests/fixtures/frozen_maze_source.gd")
 for label in ["east","thin-turf"]:
  var spatial:=frozen.spatial(frozen.read("res://tests/fixtures/september9-%s-source.txt"%label),program)
  assert_true(helper.placements(spatial).is_empty(),"Open stairs and streets cannot receive unsupported frames")

class MouthGrid extends WarrenSpatialGrid:
 var uses:Dictionary={}
 func use_at(cell:Vector3i)->int:return int(uses.get(cell,Use.OUTSIDE))

func test_four_rotations_require_both_jambs_the_roof_and_real_bearings() -> void:
 var helper:=preload("res://scripts/terrain/features/villages/fabric/WarrenTunnelArches.gd")
 for turn in 4:
  var rotation:=Basis(Vector3.UP,turn*PI/2)
  for omission in ["none","jamb","ceiling","bearing"]:
   var grid:=MouthGrid.new(Vector3i(-10,-2,-10),Vector3i(20,12,20))
   var source:=WarrenSpatialPlan.new(&"mouth",7,grid)
   for p:Vector3i in [Vector3i(0,0,0),Vector3i(0,0,1),Vector3i(-1,0,0),Vector3i(-1,0,1)]:
    var cell:=Vector3i((rotation*Vector3(p)).round())
    source.route_floor_cells.append(cell)
    for band in 3:grid.uses[cell+Vector3i.UP*band]=WarrenSpatialGrid.Use.PUBLIC_AIR
   for p:Vector3i in [Vector3i(0,0,-1),Vector3i(0,0,2)]:
    for band in range(-1,3):
     if (omission=="jamb" and band==1) or (omission=="bearing" and band==-1):continue
     grid.uses[Vector3i((rotation*Vector3(p)).round())+Vector3i.UP*band]=WarrenSpatialGrid.Use.STRUCTURAL_VOLUME
   if omission!="ceiling":
    for p:Vector3i in [Vector3i(0,3,0),Vector3i(0,3,1)]:grid.uses[Vector3i((rotation*Vector3(p)).round())]=WarrenSpatialGrid.Use.STRUCTURAL_VOLUME
   var placements:=helper.placements(source)
   assert_eq(placements.size(),1 if omission=="none" else 0,omission+" rotation "+str(turn))
   if placements.is_empty():continue
   assert_true((placements[0].transform.origin as Vector3).is_equal_approx(rotation*Vector3(-0.65,0,0.75)))
