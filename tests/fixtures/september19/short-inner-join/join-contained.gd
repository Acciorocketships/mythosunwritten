extends RefCounted
## Continue actual adjoining formations through a concave native junction.
## Taller ends may continue only where an existing upper wall backs the extension.
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const LEDGE_JOIN=preload("res://scripts/terrain/field/CliffLedgeJoin.gd")
const EXTENSION:=3.0
static func apply(forms:Array,region:HeightfieldRegion=null,features:FeatureContext=null,reject:Callable=Callable())->Dictionary:
 var corners:Array=[]
 for form:Dictionary in forms:
  if form.get("replay_recipe",{}).get("kind","")=="inner_corner":corners.append(form)
 corners.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.anchor<b.anchor)
 var changed:=0;var connections:=0
 for corner:Dictionary in corners:
  var parents:Array=[];var directions:Dictionary={}
  for index in forms.size():
   var other:Dictionary=forms[index]
   if other.get("replay_recipe",{}).get("kind","")!="wall":continue
   var local:Transform3D=(corner.transform as Transform3D).affine_inverse()*other.transform
   if absf(local.origin.y)>.001 or float(other.replay_recipe.height)<float(corner.replay_recipe.height)-.001:continue
   var normal:Vector3=local.basis.z
   if not ((normal.dot(Vector3.BACK)>.99 and absf(local.origin.z)<.01) or (normal.dot(Vector3.RIGHT)>.99 and absf(local.origin.x)<.01)):continue
   var relative:Vector3=(other.transform as Transform3D).affine_inverse()*corner.transform.origin
   var width:float=other.replay_recipe.width
   var left:bool=relative.x<0
   var gap:=absf(relative.x)-width*.5
   if gap>2.0:continue
   var extension:float=0.0 if gap<=0.0 else EXTENSION
   if extension>0.0 and float(other.replay_recipe.height)>float(corner.replay_recipe.height)+.001 and not _upper_wall_backs_extension(other,left,float(corner.replay_recipe.height),forms):continue
   # A native panel may already cross the corner coordinate. Use that bearing
   # before extending a more distant panel through the same space.
   var direction:=normal.round()
   var score:=maxf(0.0,gap)
   if not directions.has(direction) or score<float(directions[direction][3]):
    directions[direction]=[index,left,extension,score]
  for direction:Vector3 in directions:parents.append(directions[direction])
  if parents.size()!=2:continue
  var stepped:=false;var all_terminal:=true
  for parent:Array in parents:
   var recipe:Dictionary=forms[parent[0]].replay_recipe
   stepped=stepped or float(recipe.height)>float(corner.replay_recipe.height)+.001
   all_terminal=all_terminal and (float(parent[2])==0.0 or bool(recipe.left_end if parent[1] else recipe.right_end))
  if not stepped and not all_terminal:continue
  var candidates:Array=[];var admitted:=true
  for parent:Array in parents:
   var original:Dictionary=forms[parent[0]];var recipe:Dictionary=original.replay_recipe
   var left:bool=parent[1];var extension:float=parent[2];var pose:Transform3D=original.transform
   pose.origin+=pose.basis.x*(-1.0 if left else 1.0)*extension*.5
   var fresh:Dictionary=CRAGS.make(pose,recipe.width+extension,recipe.height,recipe.seed,region,recipe.left_end and (extension==0.0 or not left),recipe.right_end and (extension==0.0 or left),recipe.get("ledge_joins",[]))[0]
   # Keep the canonical source owner. Shifting a mesh centre across a cell
   # boundary must not transfer its publication to a different chunk.
   fresh.anchor=original.anchor;fresh.id=original.id
   fresh.replay_recipe["inner_connections"]=recipe.get("inner_connections",[]).duplicate()
   fresh.replay_recipe.inner_connections.append(corner.anchor)
   if region==null:_restore_floor(fresh,original)
   candidates.append(fresh)
  var ledges:=LEDGE_JOIN.controls(candidates,corner.anchor)
  for i in candidates.size():
   var fresh:Dictionary=candidates[i]
   if not ledges.is_empty():
    LEDGE_JOIN.apply(fresh,[ledges[i]])
    fresh.replay_recipe["ledge_joins"]=fresh.replay_recipe.get("ledge_joins",[]).duplicate(true)
    fresh.replay_recipe.ledge_joins.append(ledges[i])
   var box:AABB=fresh.bounds
   var footprint:=Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
   if region!=null and region.has_grade_effect_in(footprint.grow(.1)):admitted=false
   if features!=null and features.overlaps_clearance(FeatureGroundShape.axis_rect(footprint),.3):admitted=false
   if reject.is_valid() and reject.call(fresh):admitted=false
  if not admitted:continue
  for i in parents.size():forms[parents[i][0]]=candidates[i]
  forms.erase(corner);changed+=2;connections+=1
 return {"connections":connections,"changed_walls":changed}
static func _upper_wall_backs_extension(original:Dictionary,left:bool,corner_height:float,forms:Array)->bool:
 # A taller end can cross a lower terrace only when the same native wall
 # continues above that terrace. Otherwise its upper rock would cross a turf lip.
 var recipe:Dictionary=original.replay_recipe
 var edge:float=(-1.0 if left else 1.0)*float(recipe.width)*.5
 var far_edge:float=edge+(-EXTENSION if left else EXTENSION)
 for other:Dictionary in forms:
  if other.id==original.id or other.get("replay_recipe",{}).get("kind","")!="wall":continue
  var local:Transform3D=(original.transform as Transform3D).affine_inverse()*other.transform
  if local.basis.z.dot(Vector3.BACK)<.99 or local.basis.x.dot(Vector3.RIGHT)<.99 or absf(local.origin.z)>.01:continue
  if local.origin.y>corner_height+.001 or local.origin.y+float(other.replay_recipe.height)<float(recipe.height)-.001:continue
  var half_width:float=float(other.replay_recipe.width)*.5
  if local.origin.x-half_width<=minf(edge,far_edge)+.01 and local.origin.x+half_width>=maxf(edge,far_edge)-.01:return true
 return false

static func _restore_floor(fresh:Dictionary,original:Dictionary)->void:
 var floor_y:=0.0;var min_y:=0.0
 for p:Vector3 in original.faces:floor_y=minf(floor_y,p.y)
 for p:Vector3 in fresh.faces:min_y=minf(min_y,p.y)
 for key:String in ["faces","green"]:
  var faces:PackedVector3Array=fresh[key]
  for i in faces.size():
   if faces[i].y<=min_y+.001:faces[i].y=floor_y
  fresh[key]=faces
 var bounds:=AABB(fresh.faces[0],Vector3.ZERO)
 for p:Vector3 in fresh.faces:bounds=bounds.expand(p)
 fresh.bounds=fresh.transform*bounds;fresh.base=fresh.bounds.position.y
