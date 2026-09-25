extends GutTest
const REPLAY=preload("res://tests/fixtures/cliff_snapshot_replay.gd")
const WALL=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const CORNER=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
func test_legacy_corner_snapshot_retains_its_curved_geometry_and_native_roots()->void:
 var pose:=Transform3D(Basis.IDENTITY,Vector3(-445.5,32,-253.5))
 var original:=CORNER.make(pose,8,2697992464)
 var replay:=REPLAY.rebuild(pose,original.faces,{},WALL,CORNER)
 assert_eq(replay.faces.to_byte_array().hex_encode().sha256_text(),original.faces.to_byte_array().hex_encode().sha256_text(),"Saved convex rock must rebuild as the same corner, not an inferred straight panel")
 assert_true(replay.has("native_roots"),"Preserve the native corner attachment normals")
 assert_eq(replay.green.size(),original.green.size(),"Keep the wrapped ledge surfaces")
func test_legacy_straight_snapshot_keeps_its_wall_geometry()->void:
 var pose:=Transform3D(Basis.IDENTITY,Vector3(-480,32,-253.5))
 var original:Dictionary=WALL.make(pose,24,8,2697992464,null,false,false)[0]
 var replay:=REPLAY.rebuild(pose,original.faces,{},WALL,CORNER)
 assert_eq(replay.faces.to_byte_array().hex_encode().sha256_text(),original.faces.to_byte_array().hex_encode().sha256_text(),"Ordinary faces retain their canonical width and end flags")

func test_legacy_four_metre_crown_keeps_exact_native_storey_height()->void:
 var pose:=Transform3D(Basis(Vector3.UP,-PI*.5),Vector3(-514.5,36,-259.5))
 var original:Dictionary=WALL.make(pose,9,4,2697992464,null,false,false)[0]
 var replay:=REPLAY.rebuild(pose,original.faces,{},WALL,CORNER)
 assert_eq(replay.faces.to_byte_array().hex_encode().sha256_text(),original.faces.to_byte_array().hex_encode().sha256_text(),"Float32 bounds must not alter native height sampling")
 assert_eq(replay.green,original.green,"Retain the complete same native treads")

func test_recorded_recipe_survives_packed_scene_and_keeps_original_seed()->void:
 var original:=CORNER.make(Transform3D(Basis(Vector3.UP,PI*.5),Vector3(34.5,12,34.5)),8,12345)
 var built:=ROCKS.build({"placements":[original]},12345)
 built.get_child(0).owner=built
 var packed:=PackedScene.new()
 assert_eq(packed.pack(built),OK)
 var restored:Node3D=packed.instantiate()
 var node:Node=restored.get_child(0)
 var recipe:Dictionary=node.get_meta("relief_recipe",{})
 assert_eq(recipe,original.replay_recipe,"Snapshot must carry the exact construction kind and seed")
 var replay:=REPLAY.rebuild(original.transform,node.get_meta("relief_faces"),recipe,WALL,CORNER)
 assert_eq(replay.faces.to_byte_array().hex_encode().sha256_text(),original.faces.to_byte_array().hex_encode().sha256_text(),"Non-default seed and rotated corner rebuild exactly")
 built.free();restored.free()

func test_legacy_snapshot_keeps_the_actual_buried_corner_floor()->void:
 var pose:=Transform3D(Basis.IDENTITY,Vector3(-445.5,32,-253.5))
 var original:=CORNER.make(pose,8,2697992464)
 var seated:PackedVector3Array=original.faces.duplicate()
 for i in seated.size():
  if absf(seated[i].y+.2)<.001:seated[i].y=-4.2
 var replay:=REPLAY.rebuild(pose,seated,{},WALL,CORNER)
 assert_eq(replay.faces.to_byte_array().hex_encode().sha256_text(),seated.to_byte_array().hex_encode().sha256_text(),"Buried corner base must not be lifted to the nominal plane during replay")
 var missing:=0
 for point:Vector3 in replay.faces:
  if not replay.native_roots.has(point):missing+=1
 assert_eq(missing,0,"Moved foot vertices retain native attachment data")
 assert_almost_eq(replay.bounds.position.y,27.8,.0001)
