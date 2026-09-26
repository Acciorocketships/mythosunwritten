extends GutTest
const ROCKS=preload("res://scripts/terrain/field/CliffSlopeRocks.gd")
func test_every_active_rock_choice_is_meadow()->void:
 for path in ["ambient_rock","ambient_rock_large","ambient_cliff_rock"]:
  var set_value=load("res://terrain/dressing/sets/%s.tres"%path)
  for choice in set_value.choices:assert_true(String(choice.asset_id).begins_with("meadow.rock."),"Meadow only: "+String(choice.asset_id))
 for pool in [preload("res://scripts/terrain/field/CliffSlopeField.gd").GROUND_ROCKS,preload("res://scripts/terrain/field/CliffSlopeField.gd").CLIFF_ROCKS]:
  for id in pool:assert_true(String(ROCKS.PIECES[id][0]).contains("ANGRY MESH"),"Meadow source: "+id)
func test_original_meshes_and_top_layer_are_preserved()->void:
 ROCKS.prepare()
 for id in ROCKS.PIECES:
  var source=load(ROCKS.PIECES[id][0]).instantiate()
  var native:MeshInstance3D=source.find_children("*","MeshInstance3D",true,false)[0]
  if not id.begins_with("face_"):
   assert_eq(ROCKS._pieces[id][0],native.mesh,"Ground rocks keep the complete source mesh")
  else:
   var ordinary:Array=ROCKS._pieces["angry_"+id.right(2)]
   var a:PackedVector3Array=native.mesh.get_faces();var b:PackedVector3Array=ROCKS._pieces[id][0].get_faces()
   var kept:={}
   for v:Vector3 in b:
    var key:=Vector3i((v/.001).floor())
    if not kept.has(key):kept[key]=[]
    kept[key].append(v)
   var mismatch:=0
   for v:Vector3 in a:
    var original:Vector3=ordinary[1]*v
    if absf(original.y)>=ROCKS.PIECES[id][1].y*.27:continue
    var cell:=Vector3i((original/.001).floor());var found:=false
    for x in range(-1,2):
     for y in range(-1,2):
      for z in range(-1,2):
       for candidate:Vector3 in kept.get(cell+Vector3i(x,y,z),[]):
        if original.distance_to(candidate)<.00015:found=true
    if not found:mismatch+=1
   assert_eq(mismatch,0,"Visible middle retains every source vertex")
  assert_true(String(ROCKS._pieces[id][2].shader.resource_path).ends_with("meadow_rock.gdshader"),"Source top-layer material")
  source.free()

func test_meadow_catalog_visuals_and_collisions_are_ready()->void:
 var catalog:=EnvironmentCatalog.load_default()
 assert_not_null(catalog)
 if catalog==null:return
 var program:=DressingCompiler.compile(load("res://terrain/dressing/index.tres"),catalog)
 assert_not_null(program)
 if program!=null:
  for set_data:Dictionary in program.sets:
   for choice:Dictionary in set_data.choices:
    var descriptor=catalog.descriptor(choice.asset_id)
    if &"rock" in descriptor.tags:assert_true(String(choice.asset_id).begins_with("meadow.rock."),"Every compiled landscape rock is Meadow")
 var cache:=EnvironmentRenderCache.new(catalog)
 for i in range(1,13):
  var id:=StringName("meadow.rock.%02d"%i)
  var visual=cache.visual(id)
  assert_not_null(visual)
  if visual==null:continue
  assert_eq(catalog.descriptor(id).tint_group,&"ground","Grass tops use the ground biome palette")
  assert_eq(visual.collisions.size(),1,"Ground rock retains collision")
  assert_true(visual.collisions[0].shape is ConvexPolygonShape3D)
  assert_eq(visual.collisions[0].local_transform,visual.pieces[0].local_transform,"Physics follows the source placement")
  assert_almost_eq(catalog.descriptor(id).measured_aabb.position.y,0.0,.0001,"Ground pivot")
