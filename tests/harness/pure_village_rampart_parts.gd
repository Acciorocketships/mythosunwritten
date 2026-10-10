extends "res://tests/harness/pure_village_lineup.gd"
## Native solid masonry candidates; preserve authored surfaces and end faces.
const PARTS := ["Stone_Block_1","Stone_Block_2","Stone_Block_3","Stone_Block_4",
 "Stone_Block_5","Stone_Block_6","Stone_Block_7","Fence_Start_30x10_1",
 "Fence_Start_30x10_2","WallStone_Start_20x30_1"]
func _run() -> void:
 get_root().size = Vector2i(1200,800)
 for file: String in PARTS:
  var stage := Node3D.new()
  get_root().add_child(stage)
  _light(stage)
  var scene := load(R+"Architecture/"+file+".glb") as PackedScene
  if scene == null: push_error("missing native masonry "+file);continue
  var part := scene.instantiate()
  stage.add_child(part)
  var box := _aabb(part)
  print("MASONRY_PART ",file," ",box)
  var target := box.get_center()
  var reach := maxf(box.size.x,maxf(box.size.y,box.size.z))*1.8
  await _shoot(stage,target+Vector3(reach*.6,reach*.4,reach),target,file)
  await _shoot(stage,target+Vector3(-reach*.6,reach*.4,-reach),target,file+"-back")
  stage.queue_free()
  await process_frame
 quit()
