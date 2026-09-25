extends RefCounted
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
static func apply(forms:Array)->Dictionary:
 var changes:Dictionary={};var remove:Array=[];var details:Array=[]
 for corner:Dictionary in forms:
  if corner.get("replay_recipe",{}).get("kind","")!="inner_corner":continue
  var parents:Array=[];var directions:Dictionary={}
  for index in forms.size():
   var other:Dictionary=forms[index]
   if other.get("replay_recipe",{}).get("kind","")!="wall":continue
   var local:Transform3D=(corner.transform as Transform3D).affine_inverse()*other.transform
   if absf(local.origin.y)>.001 or absf(float(other.replay_recipe.height)-float(corner.replay_recipe.height))>.001:continue
   var normal:Vector3=local.basis.z
   if not ((normal.dot(Vector3.BACK)>.99 and absf(local.origin.z)<.01) or (normal.dot(Vector3.RIGHT)>.99 and absf(local.origin.x)<.01)):continue
   var relative:Vector3=(other.transform as Transform3D).affine_inverse()*corner.transform.origin
   var width:float=other.replay_recipe.width
   var left:bool=relative.x<0
   if absf(absf(relative.x)-width*.5)>2.0:continue
   parents.append([index,left]);directions[normal.round()]=true
  if directions.size()!=2:continue
  for parent:Array in parents:
   var index:int=parent[0]
   if not changes.has(index):changes[index]=[false,false]
   changes[index][0 if parent[1] else 1]=true
  remove.append(corner)
  details.append({"corner":str(corner.anchor),"parents":str(parents)})
 for index:int in changes:
  var original:Dictionary=forms[index];var recipe:Dictionary=original.replay_recipe
  var pose:Transform3D=original.transform;var width:float=recipe.width
  var left:bool=changes[index][0];var right:bool=changes[index][1]
  # Bury each added end behind the adjoining wall instead of tapering its
  # thickness to native backing before the corner is reached.
  var extension:=3.0
  pose.origin+=pose.basis.x*(float(right)-float(left))*extension*.5
  width+=extension*(int(left)+int(right))
  var fresh:Dictionary=CRAGS.make(pose,width,recipe.height,recipe.seed,null,recipe.left_end and not left,recipe.right_end and not right)[0]
  var floor_y:=0.0
  for p:Vector3 in original.faces:floor_y=minf(floor_y,p.y)
  var min_y:=0.0
  for p:Vector3 in fresh.faces:min_y=minf(min_y,p.y)
  for key:String in ["faces","green"]:
   var faces:PackedVector3Array=fresh[key]
   for i in faces.size():
    if faces[i].y<=min_y+.001:faces[i].y=floor_y
   fresh[key]=faces
  forms[index]=fresh
 for form:Dictionary in remove:forms.erase(form)
 return {"walls_extended":changes.size(),"corners_replaced":remove.size(),"details":details}
