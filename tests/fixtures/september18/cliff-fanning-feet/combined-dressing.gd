extends RefCounted
## External closed rock formations on canonical native cliff faces. Baked
## resources are prepared on the main thread; workers consume detached arrays.
const CRAGS=preload("res://tests/fixtures/september18/cliff-fanning-feet/combined.gd")
const CORNERS=preload("res://tests/fixtures/september18/cliff-fanning-feet/combined-corner.gd")
const RELIEF=preload("res://scripts/terrain/field/CliffRockRelief.gd")
const PANELS=preload("res://scripts/terrain/field/CliffSiding.gd")
const PLANTS:=[&"quaternius.cliff.fern", &"native.cliff.groundplant_1", &"native.cliff.groundplant_3"]
const FORMS:=[0,1,2,3,4,5]
static var _definitions:Dictionary={}
static var _visuals:Dictionary={}
static var _wall_crags:Array[Dictionary]=[]

static func prepare()->void:
 CRAGS.prepare();CORNERS.prepare()
 if not _definitions.is_empty():return
 assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
 var catalog:=EnvironmentCatalog.load_default();var cache:=EnvironmentRenderCache.new(catalog)
 var ids:Array[StringName]=[]
 ids.assign(PLANTS)
 for form:int in FORMS:ids.append(StringName("cliff.outcrop.%d"%form))
 assert(cache.prepare(ids))
 var wall:=cache.visual(&"kaykit.cliff.wall")
 var native_wall:=PackedVector3Array()
 for piece:EnvironmentVisualPiece in wall.pieces:
  for point:Vector3 in piece.mesh.get_faces():native_wall.append(piece.local_transform*point)
 _wall_crags=RELIEF.crags(native_wall)
 for id:StringName in ids:
  var visual:=cache.visual(id);var faces:=PackedVector3Array();var green:=PackedVector3Array()
  for piece:EnvironmentVisualPiece in visual.pieces:
   var source:=piece.mesh.get_faces()
   for p:Vector3 in source:faces.append(piece.local_transform*p)
   for surface in piece.mesh.get_surface_count():
    var material:Material=piece.material_override if piece.material_override!=null else piece.mesh.surface_get_material(surface)
    if not material is StandardMaterial3D:continue
    var color:Color=material.albedo_color
    if color.g<=color.r*1.15:continue
    var part:=ArrayMesh.new();part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,piece.mesh.surface_get_arrays(surface))
    for p:Vector3 in part.get_faces():green.append(piece.local_transform*p)
  var feet:Dictionary={}
  for p:Vector3 in faces:feet[Vector3(p.x,0,p.z).snapped(Vector3.ONE*.00001)]=true
  _definitions[id]={"feet":feet.keys(),"bounds":catalog.descriptor(id).measured_aabb,"faces":faces,"green":green}
  if id not in PLANTS:
   visual=visual.duplicate(true)
   for piece:EnvironmentVisualPiece in visual.pieces:
    piece.mesh=piece.mesh.duplicate()
    for surface in piece.mesh.get_surface_count():
     var material:=piece.mesh.surface_get_material(surface) as StandardMaterial3D
     if material!=null and material.albedo_color.g>material.albedo_color.r*1.15:
      var arrays:=piece.mesh.surface_get_arrays(surface)
      var uv:=PackedVector2Array();uv.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size());uv.fill(CliffDressing.ground_uv())
      arrays[Mesh.ARRAY_TEX_UV]=uv
      var rebuilt:=ArrayMesh.new()
      for section in piece.mesh.get_surface_count():
       rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays if section==surface else piece.mesh.surface_get_arrays(section))
       rebuilt.surface_set_material(section,CliffDressing.shared_material() if section==surface else piece.mesh.surface_get_material(section))
      piece.mesh=rebuilt
     elif material!=null:
      var stone:=ShaderMaterial.new();stone.shader=load("res://terrain/materials/field_rock.gdshader")
      stone.set_shader_parameter("use_texture",false)
      stone.set_shader_parameter("instance_variation",false)
      piece.mesh.surface_set_material(surface,stone)
  else:
   visual=visual.duplicate(true)
   for piece:EnvironmentVisualPiece in visual.pieces:
    # The native fern carries a grayscale vertex channel that its original
    # material ignores. Clear that unused channel before COLOR carries the
    # biome instance tint; otherwise the leaves become nearly black.
    var native_mesh:=piece.mesh
    piece.mesh=ArrayMesh.new()
    for section in native_mesh.get_surface_count():
     var arrays:=native_mesh.surface_get_arrays(section)
     arrays[Mesh.ARRAY_COLOR]=null
     piece.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
     piece.mesh.surface_set_material(section,native_mesh.surface_get_material(section))
    for section in piece.mesh.get_surface_count():
     var source:=piece.mesh.surface_get_material(section) as StandardMaterial3D
     if source==null:continue
     var leaves:=ShaderMaterial.new();leaves.shader=load("res://terrain/materials/cliff_vine.gdshader")
     leaves.set_shader_parameter("albedo_texture",source.albedo_texture)
     leaves.set_shader_parameter("base_color",source.albedo_color)
     leaves.set_shader_parameter("grass_palette",CliffDressing.ground_texture())
     leaves.set_shader_parameter("grass_uv",CliffDressing.ground_uv())
     piece.mesh.surface_set_material(section,leaves)
  _visuals[id]=visual

static func compute(region:HeightfieldRegion,lo_x:int,lo_z:int,cells:int,seed_value:int,
  features:FeatureContext=null,water:WaterFieldContext=null)->Dictionary:
 var cliffs:=CliffDressing.compute(region,lo_x-1,lo_z-1,cells+2)
 # Halo geometry is also a conservative plant/grass reservation. Water
 # admission applies only after ownership, inside the prepared query margin.
 var neighbors:=formations(cliffs.wall,seed_value,region,features)
 neighbors.append_array(CORNERS.formations(cliffs.outer_wall,seed_value,region,features))
 var placements:Array[Dictionary]=[]
 for p:Dictionary in neighbors:
  var owner:=Vector2i(floori((p.anchor.x+12)/24),floori((p.anchor.z+12)/24))
  if owner.x>=lo_x and owner.x<lo_x+cells and owner.y>=lo_z and owner.y<lo_z+cells:
   if not _wet_formation(p,water):placements.append(p)
 var collision:=PackedVector3Array();var reservations:Array[Rect2]=[]
 for p:Dictionary in placements:
  for vertex:Vector3 in _faces(p):collision.append(p.transform*vertex)
 for p:Dictionary in neighbors:reservations.append(_footprint(p.bounds))
 var foliage:=plants(placements,region,seed_value,features,water,neighbors)
 for wall:Transform3D in cliffs.wall:
  var owner:=Vector2i(floori((wall.origin.x+12)/24),floori((wall.origin.z+12)/24))
  if owner.x<lo_x or owner.x>=lo_x+cells or owner.y<lo_z or owner.y>=lo_z+cells:continue
  if Helper.position_hash01(wall.origin,seed_value+9401)>.24:continue
  var anchors:Array[Dictionary]=[]
  for crag:Dictionary in _wall_crags:
   if crag.point.y<.3 or crag.point.y>3.7:continue
   anchors.append({"point":wall*crag.point,"normal":wall.basis*crag.normal,"kind":"wall_crag"})
  var wall_plants:=_plant_anchors(anchors,"wall/%s"%wall.origin,region,seed_value,features,water,neighbors,1)
  for plant:Dictionary in wall_plants:plant["anchor"]=wall.origin
  foliage.append_array(wall_plants)
 var supports:Array[Dictionary]=[]
 var grass_core:=Rect2(Vector2(lo_x,lo_z)*24.0,Vector2.ONE*cells*24.0)
 for rock:Dictionary in neighbors:
  if not _footprint(rock.bounds).intersects(grass_core):continue
  if _wet_formation(rock,water):continue
  supports.append_array(ledge_grass_supports(rock,neighbors))
 placements.append_array(foliage)
 return {"placements":placements,"collision_faces":collision,"ground_reservations":reservations,"grass_supports":supports}

static func ledge_grass_supports(rock:Dictionary,neighbors:Array)->Array[Dictionary]:
 # Each actual turf elevation owns its native triangles. A horizontal section
 # of higher stone excludes buried roots and keeps complete patches off risers.
 if rock.has("faces"):return RELIEF.grass_supports(rock,neighbors)
 var green:PackedVector3Array=_green(rock)
 var levels:Dictionary={}
 for i in range(0,green.size(),3):
  if maxf(green[i].y,maxf(green[i+1].y,green[i+2].y))-minf(green[i].y,minf(green[i+1].y,green[i+2].y))>.0001:continue
  levels[snappedf(green[i].y,.0001)]=true
 var result:Array[Dictionary]=[]
 for level:float in levels:
  var placement:Dictionary=rock.duplicate()
  placement.top=(rock.transform*Vector3(0,level,0)).y
  var support:=GrassSupportSurfaces.from_native(placement,green)
  if support.triangles.is_empty():continue
  support["foliage_managed"]=true # The outcrop plant pass owns these ledges.
  support["polygon_obstacles"]=[]
  for other:Dictionary in neighbors:
   if not (other.bounds as AABB).intersects(rock.bounds):continue
   var section:=_horizontal_section(other,placement.top+.08)
   if section.size()>=3:support.polygon_obstacles.append(section)
  result.append(support)
 return result

static func _horizontal_section(rock:Dictionary,height:float)->PackedVector2Array:
 var bounds:AABB=rock.bounds
 if height<=bounds.position.y or height>=bounds.end.y:return PackedVector2Array()
 var intersections:=PackedVector2Array()
 var faces:PackedVector3Array=_faces(rock)
 for i in range(0,faces.size(),3):
  for edge in 3:
   var a:Vector3=rock.transform*faces[i+edge]
   var b:Vector3=rock.transform*faces[i+(edge+1)%3]
   if (a.y<height)==(b.y<height) or absf(a.y-b.y)<.00001:continue
   var p:=a.lerp(b,(height-a.y)/(b.y-a.y))
   intersections.append(Vector2(p.x,p.z))
 # Convex containment is deliberately conservative at narrow rock creases;
 # it cannot admit grass inside a concave stone section.
 return Geometry2D.convex_hull(intersections) if intersections.size()>=3 else PackedVector2Array()

static func formations(walls:Array,seed_value:int,region:HeightfieldRegion=null,features:FeatureContext=null)->Array[Dictionary]:
 assert(not _definitions.is_empty())
 var out:Array[Dictionary]=[]
 var panels:=RELIEF.panels(walls)
 for record:Dictionary in panels:
  if record.width<6:continue
  for rock:Dictionary in CRAGS.make(record.pose,record.width,record.height,seed_value,region,record.left_end,record.right_end):
   var footprint:=_footprint(rock.bounds)
   if region!=null and region.has_grade_effect_in(footprint.grow(.1)):continue
   if features!=null and features.overlaps_clearance(FeatureGroundShape.axis_rect(footprint),.3):continue
   out.append(rock)
 return out

static func _offer(out:Array[Dictionary],form:int,pose:Transform3D,anchor:Vector3,
  region:HeightfieldRegion,features:FeatureContext)->void:
 var asset:=StringName("cliff.outcrop.%d"%form)
 var local:AABB=_definitions[asset].bounds
 var box:AABB=pose*local
 if region!=null:
  # Extend each entire solid to its real exposed foot. Upper face bands may
  # never turn into hanging slabs when the visible cliff is taller than 16 m.
  var floor_y:=box.position.y
  for vertex:Vector3 in _definitions[asset].feet:
   var point:=pose*vertex
   floor_y=minf(floor_y,TerrainSurfaceField.surface_y(region,point.x,point.z)-.15)
  if floor_y<box.position.y-.01:
   var top:=box.end.y;var old_height:=box.size.y
   pose.origin.y-=box.position.y-floor_y
   pose.basis.y*= (top-floor_y)/old_height
   box=pose*local
  if region.has_grade_effect_in(_footprint(box).grow(.1)):return
 if features!=null and features.overlaps_clearance(FeatureGroundShape.axis_rect(_footprint(box)),.3):return
 out.append({"id":"rock/%s/%d/%s"%[anchor,form,pose.origin],"asset":asset,"transform":pose,"bounds":box,
  "kind":"rock","top":box.end.y,"base":box.position.y,"anchor":anchor})

static func _faces(rock:Dictionary)->PackedVector3Array:
 return rock.faces if rock.has("faces") else _definitions[rock.asset].faces

static func _green(rock:Dictionary)->PackedVector3Array:
 return rock.green if rock.has("green") else _definitions[rock.asset].green

static func _wet_formation(rock:Dictionary,water:WaterFieldContext)->bool:
 if water==null or not water.has_sources():return false
 var box:AABB=rock.bounds;var pose:Transform3D=rock.transform
 assert(water.coverage().encloses(_footprint(box)),"Owned rock exceeds the prepared water margin")
 var faces:=_faces(rock);var inverse:=pose.affine_inverse()
 for vertex:Vector3 in faces:
  var point:=pose*vertex
  if water.is_wet(Vector2(point.x,point.z)):return true
 var footprint:=_footprint(box);var nx:=maxi(1,ceili(footprint.size.x/1.5));var nz:=maxi(1,ceili(footprint.size.y/1.5))
 for z in nz+1:
  for x in nx+1:
   var p:=footprint.position+footprint.size*Vector2(float(x)/nx,float(z)/nz)
   if not water.is_wet(p):continue
   var start:=inverse*Vector3(p.x,box.end.y+1,p.y);var direction:=inverse.basis*Vector3.DOWN
   for j in range(0,faces.size(),3):
    if Geometry3D.ray_intersects_triangle(start,direction,faces[j],faces[j+1],faces[j+2])!=null:return true
 return false

static func _wet_rock(asset:StringName,pose:Transform3D,box:AABB,water:WaterFieldContext)->bool:
 # Rock dressing cannot displace the authoritative water field. Test the
 # complete projected solid, including its interior, before emitting either
 # visual geometry or collision. Dry bank faces and submerged native walls
 # remain; no replacement water plane is invented around a decorative rock.
 if water!=null and water.has_sources():
  assert(water.coverage().encloses(_footprint(box)),"Owned rock exceeds the prepared water margin")
  for vertex:Vector3 in _definitions[asset].feet:
   var point:=pose*vertex
   if water.is_wet(Vector2(point.x,point.z)):return true
  var footprint:=_footprint(box)
  var nx:=maxi(1,ceili(footprint.size.x/1.5));var nz:=maxi(1,ceili(footprint.size.y/1.5))
  var inverse:=pose.affine_inverse()
  for z in nz+1:
   for x in nx+1:
    var p:Vector2=footprint.position+footprint.size*Vector2(float(x)/nx,float(z)/nz)
    if not water.is_wet(p):continue
    var start:Vector3=inverse*Vector3(p.x,box.end.y+1,p.y)
    var direction:Vector3=inverse.basis*Vector3.DOWN
    var faces:PackedVector3Array=_definitions[asset].faces
    for j in range(0,faces.size(),3):
     if Geometry3D.ray_intersects_triangle(start,direction,faces[j],faces[j+1],faces[j+2])!=null:return true
 return false

static func plants(rocks:Array,region:HeightfieldRegion,seed_value:int,features:FeatureContext=null,
  water:WaterFieldContext=null,neighbors:Array=[])->Array[Dictionary]:
 var out:Array[Dictionary]=[]
 if neighbors.is_empty():neighbors=rocks
 var owned:Dictionary={}
 for rock:Dictionary in rocks:owned[rock.id]=true
 var proposals:Array[Dictionary]=[]
 # Resolve canopy competition against the same canonical halo on either side
 # of an owner boundary. Water admission follows ownership, so no halo query
 # escapes the caller's prepared hydraulic domain.
 for rock:Dictionary in neighbors:
  var candidates:Array[Dictionary]=[]
  for crag:Dictionary in RELIEF.crags(_faces(rock)):
   candidates.append({"point":rock.transform*crag.point,"normal":(rock.transform.basis.inverse().transposed()*crag.normal).normalized(),"kind":"rock_crag"})
  var green:=_green(rock)
  for i in range(0,green.size(),3):
   var a:Vector3=rock.transform*green[i];var b:Vector3=rock.transform*green[i+1];var c:Vector3=rock.transform*green[i+2]
   candidates.append({"point":(a+b+c)/3,"normal":(c-a).cross(b-a).normalized(),"kind":"ledge"})
  proposals.append_array(_plant_anchors(candidates,rock.id,region,seed_value,features,null,neighbors,6))
 for proposal:Dictionary in proposals:
  if not owned.has(proposal.support_id):continue
  var rank:=Helper.position_hash01(proposal.support_point,seed_value+9383)
  var clear:=true
  for other:Dictionary in proposals:
   if other.id==proposal.id:continue
   var other_rank:=Helper.position_hash01(other.support_point,seed_value+9383)
   if other_rank<rank or (other_rank==rank and String(other.id)<String(proposal.id)):
    if _canopies_crowd(proposal.bounds,other.bounds):clear=false;break
  if not clear:continue
  var point:Vector3=proposal.support_point
  if water!=null and water.has_sources() and water.is_wet(Vector2(point.x,point.z)) and water.level_at(Vector2(point.x,point.z))>point.y-.3:continue
  out.append(proposal)
 return out

static func _canopies_crowd(a:AABB,b:AABB)->bool:
 # Permit light leaf interleaving, while keeping the bulk of each native
 # canopy readable. Roots alone cannot measure a rotated fern's spread.
 return a.intersection(b).get_volume()>.15*minf(a.get_volume(),b.get_volume())

static func _plant_anchors(candidates:Array[Dictionary],owner:String,region:HeightfieldRegion,seed_value:int,
 features:FeatureContext,water:WaterFieldContext,neighbors:Array,limit:int)->Array[Dictionary]:
 var out:Array[Dictionary]=[];var anchors:Array[Vector3]=[]
 candidates.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
  # Crevices receive first choice; random stable order avoids always picking
  # the first edge of each source mesh or lining plants up across a ledge.
  if (a.kind=="ledge")!=(b.kind=="ledge"):return a.kind!="ledge"
  return Helper.position_hash01(a.point,seed_value+9323)<Helper.position_hash01(b.point,seed_value+9323))
 for candidate:Dictionary in candidates:
  var point:Vector3=candidate.point;var normal:Vector3=candidate.normal
  if normal.y<-.5:continue
  var roll:=Helper.position_hash01(point,seed_value+9341)
  if roll>.42:continue
  var exposed_probe:Vector3=point if candidate.kind=="ledge" else point+Vector3(normal.x,0,normal.z).normalized()*1.6
  if region!=null and TerrainSurfaceField.surface_y(region,exposed_probe.x,exposed_probe.z)>point.y-.3:continue
  if water!=null and water.has_sources() and water.is_wet(Vector2(point.x,point.z)) and water.level_at(Vector2(point.x,point.z))>point.y-.3:continue
  var clear:=true
  for prior:Vector3 in anchors:
   if prior.distance_to(point)<2.0:clear=false;break
  if not clear:continue
  for other:Dictionary in neighbors:
   if other.id==owner or not (other.bounds as AABB).grow(.01).has_point(point):continue
   if _covered(other,point+normal*.1):clear=false;break
  if not clear:continue
  var asset:StringName=PLANTS[0] if candidate.kind!="ledge" else PLANTS[1 if roll<.21 else 2]
  var scale_value:=lerpf(.52,.95,roll/.42) if asset==PLANTS[0] else lerpf(1.1,1.8,roll/.42)
  var up:Vector3=Vector3.UP.lerp(normal,.55).normalized()
  var x:=Vector3.RIGHT-up*up.x
  if x.length_squared()<.01:x=Vector3.FORWARD-up*up.z
  x=x.normalized()
  var basis:=Basis(x,up,x.cross(up))*Basis(Vector3.UP,roll*TAU/.42)
  var local_bounds:AABB=_definitions[asset].bounds
  var pose:=Transform3D(basis.scaled(Vector3.ONE*scale_value),point-normal*.07-up*local_bounds.position.y*scale_value)
  var box:AABB=pose*local_bounds
  if features!=null and features.overlaps_clearance(FeatureGroundShape.axis_rect(_footprint(box)),.3):continue
  anchors.append(point)
  out.append({"id":owner+"/plant/%s"%point,"asset":asset,"kind":"foliage","attachment":candidate.kind,
   "support_point":point,"support_normal":normal,"transform":pose,"bounds":box,"support_id":owner})
  if out.size()>=limit:break
 return out

static func _covered(rock:Dictionary,point:Vector3)->bool:
 var local:Vector3=(rock.transform as Transform3D).affine_inverse()*point
 var faces:PackedVector3Array=_faces(rock)
 var intersections:=0
 for i in range(0,faces.size(),3):
  var hit=Geometry3D.ray_intersects_triangle(local+Vector3.UP*.0001,Vector3.UP,faces[i],faces[i+1],faces[i+2])
  if hit!=null:intersections+=1
 return intersections%2==1

static func _footprint(box:AABB)->Rect2:
 return Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))

static func build(data:Dictionary,_seed:int)->Node3D:
 assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
 var root:=Node3D.new();root.name="CliffRockFormations"
 var batches:Dictionary={}
 for p:Dictionary in data.get("placements",[]):
  if p.has("faces"):
   var mesh:=CRAGS.mesh(p) if p.get("native_crag",false) else RELIEF.mesh(p)
   var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.use_colors=true;mm.instance_count=1
   mm.set_instance_transform(0,p.transform);mm.set_instance_color(0,BiomeRegistry.ground_tint_at(p.anchor,_seed))
   var node:=MultiMeshInstance3D.new();node.multimesh=mm;node.set_meta("cliff_asset",p.asset)
   node.set_meta("relief_green",p.green);node.set_meta("relief_faces",p.faces)
   node.add_to_group("tactical_solid_earth",true);root.add_child(node)
   continue
  if not batches.has(p.asset):batches[p.asset]=[]
  batches[p.asset].append(p.transform)
 for asset:StringName in batches:
  for piece:EnvironmentVisualPiece in (_visuals[asset] as EnvironmentVisual).pieces:
   var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=piece.mesh;mm.use_colors=true;mm.instance_count=batches[asset].size()
   for i in mm.instance_count:
    var pose:Transform3D=batches[asset][i]
    mm.set_instance_transform(i,pose*piece.local_transform)
    var tint:=BiomeRegistry.ground_tint_at(pose.origin,_seed)
    mm.set_instance_color(i,tint)
   var instance:=MultiMeshInstance3D.new();instance.multimesh=mm;instance.material_override=piece.material_override
   instance.set_meta("cliff_asset",asset)
   if asset in PLANTS:instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   else:instance.add_to_group("tactical_solid_earth",true)
   root.add_child(instance)
 return root
