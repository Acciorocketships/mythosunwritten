extends RefCounted
const RELIEF=preload("res://scripts/terrain/field/CliffRockRelief.gd")
const CRAGS=preload("res://tests/fixtures/september19/height-transition/crags.gd")
static func apply(forms:Array)->void:
 CRAGS.prepare()
 var walls:Array=FileAccess.open("res://tests/fixtures/september19/short-inner-join/native-walls.bin",FileAccess.READ).get_var()
 var records:Array=[]
 for form:Dictionary in forms:
  var recipe:Dictionary=form.replay_recipe
  if recipe.kind=="wall":
   records.append({"pose":form.transform,"width":recipe.width,"height":recipe.height,"left_end":recipe.left_end,"right_end":recipe.right_end})
 for record:Dictionary in RELIEF.panels(walls):
  if record.width<6:records.append(record)
 var replacements:=0
 for record:Dictionary in records:
  if record.pose.origin.distance_to(Vector3(-421.5,28,-346.5))>13:continue
  if record.pose.origin.y!=28:continue
  if record.pose.basis.z.dot(Vector3.RIGHT)<.99 and record.width>=6:continue
  var heights:=Vector2.ZERO
  for other:Dictionary in records:
   if other==record:continue
   var local:Transform3D=record.pose.affine_inverse()*other.pose
   if local.basis.z.dot(Vector3.BACK)<.99 or absf(local.origin.z)>.01 or absf(local.origin.y)>.01:continue
   if absf(absf(local.origin.x)-(record.width+other.width)*.5)>.01:continue
   if local.origin.x<0:heights.x=maxf(heights.x,minf(record.height,other.height))
   else:heights.y=maxf(heights.y,minf(record.height,other.height))
  var fresh:Dictionary=CRAGS.make(record.pose,record.width,record.height,2697992464,null,record.left_end,record.right_end,[],heights)[0]
  var found:=-1
  for i in forms.size():
   if forms[i].id==fresh.id:found=i;break
  if found<0:forms.append(fresh)
  else:forms[found]=fresh
  replacements+=1
  print("HEIGHT_TRANSITION ",record.pose.origin," height=",record.height," edges=",heights)
 print("HEIGHT_TRANSITION changed=",replacements)
