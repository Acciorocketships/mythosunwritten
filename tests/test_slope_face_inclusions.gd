extends GutTest
const FIELD=preload("res://scripts/terrain/field/CliffSlopeField.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffSlopeRocks.gd")
const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func before_all()->void:ROCKS.prepare()
func after_each()->void:STYLE.apply("chosen")
func test_large_shallow_faces_use_distinct_assets_per_cluster()->void:
 STYLE.apply("sheet")
 var form:={"replay_recipe":{"kind":"wall","width":80.,"height":12.,"left_end":true,"right_end":true,"abut":Vector2i.ZERO},"transform":Transform3D.IDENTITY}
 var field=FIELD.new([form],2697992464)
 var groups:={};var faces:=0
 for rock:Dictionary in field.rock_list:
  if rock.kind!="face":
   assert_gt(rock.transform.basis.y.normalized().dot(Vector3.UP),.9999,"Foot boulders stay upright")
   continue
  faces+=1
  var used:Array=groups.get(rock.bunch,[])
  assert_false(used.has(rock.piece),"Different silhouettes within each cluster")
  used.append(rock.piece);groups[rock.bunch]=used
  var t:Transform3D=rock.transform
  assert_gt((t.basis.inverse().transposed()*Vector3.UP).normalized().dot(Vector3.UP),.9999,"Grass ledges face up")
  var bounds:Vector3=ROCKS.PIECES[rock.piece][1]
  assert_gt(t.basis.x.length()*bounds.x,3.5,"Large exposed face")
  _check_face(field,rock,true)
 for group:Array in groups.values():assert_gte(group.size(),2,"Multiple visible assets per cluster")
 assert_gt(faces,3,"Keep substantial clustered outcrops")
func test_cap_burial_survives_different_wall_heights_and_corners()->void:
 STYLE.apply("sheet")
 for height:float in [4.,8.,16.]:
  var form:={"replay_recipe":{"kind":"wall","width":80.,"height":height,"left_end":true,"right_end":true,"abut":Vector2i.ZERO},"transform":Transform3D.IDENTITY}
  var corner:={"replay_recipe":{"kind":"corner","height":height},"transform":Transform3D(Basis(),Vector3(-38.5,0,1.5))}
  var field=FIELD.new([form,corner],2697992464)
  for rock:Dictionary in field.rock_list:
   if rock.kind=="face":_check_face(field,rock,false)
func _check_face(field,rock:Dictionary,visibility:bool)->void:
 var t:Transform3D=rock.transform
 var piece:Array=ROCKS._pieces[rock.piece]
 var bounds:Vector3=ROCKS.PIECES[rock.piece][1]
 var vertices:PackedVector3Array=piece[0].get_faces()
 var exposed:=0;var maximum:=0.;var visible_min:=INF;var visible_max:=-INF
 for i in range(0,vertices.size(),3):
  var a:Vector3=piece[1]*vertices[i];var b:Vector3=piece[1]*vertices[i+1];var c:Vector3=piece[1]*vertices[i+2]
  for local:Vector3 in [a,b,c,(a+b+c)/3.]:
   var p:Vector3=t*local
   var above:float=p.y-field.envelope().sample(Vector2(p.x,p.z))
   maximum=maxf(maximum,above*(rock.normal as Vector3).y)
   if above*(rock.normal as Vector3).y>.06:
    visible_min=minf(visible_min,local.x);visible_max=maxf(visible_max,local.x)
   if absf(local.y)>bounds.y*.4 and above>-.05:exposed+=1
 assert_eq(exposed,0,"Outer top and bottom ends remain buried")
 assert_lte(maximum,.88,"Shallow projection")
 if visibility:
  assert_gt(maximum,.08,"Visible source face")
  assert_gte((visible_max-visible_min)*t.basis.x.length(),maxf(1.2,bounds.x*t.basis.x.length()*.3),"Substantial silhouette")
