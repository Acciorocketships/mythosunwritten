extends GutTest
## Requires a real rendering server: dummy MultiMesh colour readback returns black.
func test_moss_instances_follow_meadow_heath_and_highland_ground_tints()->void:
 if DisplayServer.get_name()=="headless":
  pending("Requires native GPU instance-color readback; run this test without --headless")
  return
 var rocks=preload("res://scripts/terrain/field/CliffRockDressing.gd");rocks.prepare()
 var seed_value:=2697992464
 var positions:=[Vector3(299.3,18.7,517.3),Vector3(-521.8,28,-728.5),Vector3(471.5,30.2,875.1)]
 var placements:=[]
 for position:Vector3 in positions:
  placements.append({"asset":&"cliff.outcrop.0","transform":Transform3D(Basis.IDENTITY,position)})
 var root:=rocks.build({"placements":placements},seed_value)
 for node:MultiMeshInstance3D in root.get_children():
  assert_true(node.multimesh.use_colors)
  for i in positions.size():
   var actual:=node.multimesh.get_instance_color(i)
   var expected:=BiomeRegistry.ground_tint_at(positions[i],seed_value)
   assert_true(actual.is_equal_approx(expected),"The moss instance must carry the local terrain tint: %s vs %s"%[actual,expected])
 root.free()

func test_fern_and_ivy_instances_share_the_local_grass_palette()->void:
 if DisplayServer.get_name()=="headless":
  pending("Requires native GPU instance-color readback")
  return
 var rocks=preload("res://scripts/terrain/field/CliffRockDressing.gd");rocks.prepare()
 var ivy=preload("res://scripts/terrain/field/CliffVegetation.gd");ivy.prepare()
 var seed_value:=2697992464
 for position:Vector3 in [Vector3(-443,32,-266),Vector3(-1175,16,-731),Vector3(-2808,52,2266)]:
  var root:=rocks.build({"placements":[{"asset":rocks.PLANTS[0],"transform":Transform3D(Basis.IDENTITY,position)}]},seed_value)
  var walls:=[]
  for x in 12:walls.append(Transform3D(Basis.IDENTITY,position+Vector3(x*3,0,0)))
  var vines:=ivy.vines(walls,seed_value)
  assert_gt(vines.size(),0)
  var vine_root:=ivy.build(vines)
  for node:MultiMeshInstance3D in root.get_children():
   assert_true(node.multimesh.get_instance_color(0).is_equal_approx(BiomeRegistry.ground_tint_at(position,seed_value)),"Fern carries grass tint")
   var material:=node.multimesh.mesh.surface_get_material(0) as ShaderMaterial
   assert_eq(material.get_shader_parameter("grass_palette"),CliffDressing.ground_texture())
   assert_eq(material.get_shader_parameter("grass_uv"),CliffDressing.ground_uv())
  for node:MultiMeshInstance3D in vine_root.get_children():
   for i in node.multimesh.instance_count:
    var origin:=node.multimesh.get_instance_transform(i).origin
    # Native pieces retain local transforms; find the actual matching placement.
    var found:=false
    for vine:Dictionary in vines:
     if (vine.transform.origin-origin).length()<.001:
      assert_true(node.multimesh.get_instance_color(i).is_equal_approx(BiomeRegistry.ground_tint_at(vine.transform.origin,seed_value)),"Ivy carries grass tint")
      found=true;break
    assert_true(found)
  root.free();vine_root.free()
