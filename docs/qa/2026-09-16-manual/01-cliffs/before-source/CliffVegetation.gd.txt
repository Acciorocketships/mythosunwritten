extends RefCounted
## Foliage adds to the native cliff vocabulary. It never alters terrain, water,
## wall/cap meshes or collision. Main-thread preparation publishes detached bounds.
const VARIANTS := [1,2,4]
const FERN := &"quaternius.cliff.fern"
static var _bounds:Dictionary={}
static var _visuals:Dictionary={}

static func prepare()->void:
 if not _bounds.is_empty():return
 assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
 var catalog:=EnvironmentCatalog.load_default()
 var cache:=EnvironmentRenderCache.new(catalog)
 var ids:Array[StringName]=[FERN]
 for variant:int in VARIANTS:
  for count:int in [1,2,3]:ids.append(StringName("native.cliff.trailing_%d_%d"%[variant,count]))
 assert(cache.prepare(ids))
 for id:StringName in ids:
  _bounds[id]=catalog.descriptor(id).measured_aabb
  var visual:=cache.visual(id).duplicate(true) as EnvironmentVisual
  for piece:EnvironmentVisualPiece in visual.pieces:
   piece.mesh=piece.mesh.duplicate()
   for surface in piece.mesh.get_surface_count():
    var source:=piece.mesh.surface_get_material(surface) as StandardMaterial3D
    if source==null:continue
    var leaves:=ShaderMaterial.new();leaves.shader=load("res://terrain/materials/cliff_vine.gdshader")
    leaves.set_shader_parameter("albedo_texture",source.albedo_texture)
    leaves.set_shader_parameter("base_color",source.albedo_color)
    piece.mesh.surface_set_material(surface,leaves)
  _visuals[id]=visual

static func vines(walls:Array,seed_value:int,features:FeatureContext=null,water:WaterFieldContext=null)->Array[Dictionary]:
 assert(not _bounds.is_empty())
 var occupied:Dictionary={}
 for pose:Transform3D in walls:occupied[_key(pose)]=true
 var out:Array[Dictionary]=[]
 for pose:Transform3D in walls:
  var above:=pose;above.origin.y+=4
  if occupied.has(_key(above)):continue
  var top:=pose;top.origin.y+=4
  # Large vegetation patches modulate smaller strand choices. Individual
  # strands remain wholly inside their canonical native 3 m face slot.
  var patch:=top.origin.snapped(Vector3(18,12,18))
  var density:=lerpf(.18,.74,Helper.position_hash01(patch,seed_value+9181))
  if Helper.position_hash01(top.origin,seed_value+9187)>density:continue
  var bottom:=pose.origin.y-.3
  var below:=pose;below.origin.y-=4
  while occupied.has(_key(below)):
   bottom=below.origin.y-.3;below.origin.y-=4
  # Leaves on wet banks stop above the real water; a wet foot does not erase
  # all greenery from the dry exposed face.
  if water!=null and water.has_sources():
   for x:float in [-1.0,0.0,1.0]:
    var edge:=top*Vector3(x,0,1.6)
    var point:=Vector2(edge.x,edge.z)
    if water.is_wet(point):bottom=maxf(bottom,water.level_at(point)+.35)
  var variant:int=VARIANTS[mini(int(Helper.position_hash01(top.origin,seed_value+9199)*VARIANTS.size()),VARIANTS.size()-1)]
  var choices:Array[StringName]=[]
  for count:int in [1,2,3]:
   var asset:=StringName("native.cliff.trailing_%d_%d"%[variant,count])
   if top.origin.y+(_bounds[asset] as AABB).position.y>=bottom:choices.append(asset)
  if choices.is_empty():continue
  var choice:=mini(int(Helper.position_hash01(top.origin,seed_value+9203)*choices.size()),choices.size()-1)
  var asset:=choices[choice]
  var box:AABB=top*(_bounds[asset] as AABB)
  if _reserved(box,features):continue
  out.append({"asset":asset,"transform":top,"bounds":box,"kind":"vine","support_floor":bottom,"tint":BiomeRegistry.blended_foliage_tint(Helper.biome_weights5(top.origin,seed_value),"bush")})
 return out

static func compute(cliffs:Dictionary,terraces:Dictionary,region:HeightfieldRegion,seed_value:int,
  features:FeatureContext=null,water:WaterFieldContext=null)->Array[Dictionary]:
 var out:=vines(cliffs.wall,seed_value,features,water)
 var local:AABB=_bounds[FERN]
 var owners:Dictionary={}
 for placement:Dictionary in terraces.get("placements",[]):owners[placement.id]=true
 for support:Dictionary in terraces.get("grass_supports",[]):
  if not owners.has(support.id):continue
  var box:Rect2=support.bounds
  var key:=Vector3(box.position.x,support.height,box.position.y)
  var count:=1+int(Helper.position_hash01(key,seed_value+9221)*3)
  for i in count:
   var roll:=Helper.position_hash01(key+Vector3(i*7,0,0),seed_value+9227)
   var across:=Helper.position_hash01(key+Vector3(0,0,i*11),seed_value+9239)
   var point:=box.position+box.size*Vector2(lerpf(.18,.82,roll),lerpf(.18,.82,across))
   var hit:=GrassSupportSurfaces.at_point([support],point)
   if hit.is_empty() or hit.edge_distance<.45:continue
   if TerrainSurfaceField.surface_y(region,point.x,point.y)>=hit.y-.15:continue
   var scale_value:=lerpf(.70,1.15,roll)
   var pose:=Transform3D(Basis(Vector3.UP,across*TAU).scaled(Vector3.ONE*scale_value),
    Vector3(point.x,hit.y-local.position.y*scale_value-.025,point.y))
   var world_box:=pose*local
   if _reserved(world_box,features):continue
   out.append({"asset":FERN,"transform":pose,"bounds":world_box,"kind":"fern","support_id":support.id,"tint":BiomeRegistry.blended_foliage_tint(Helper.biome_weights5(pose.origin,seed_value),"bush")})
 return out

static func _reserved(box:AABB,features:FeatureContext)->bool:
 return features!=null and features.overlaps_clearance(FeatureGroundShape.axis_rect(
  Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))),.05)

static func _key(pose:Transform3D)->Array:
 return [pose.origin.snapped(Vector3.ONE*.001),pose.basis.z.round()]

static func build(placements:Array)->Node3D:
 assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
 var root:=Node3D.new();root.name="CliffVegetation"
 var batches:Dictionary={}
 for p:Dictionary in placements:
  if not batches.has(p.asset):batches[p.asset]=[]
  batches[p.asset].append(p)
 for asset:StringName in batches:
  var visual:EnvironmentVisual=_visuals[asset]
  for piece:EnvironmentVisualPiece in visual.pieces:
   var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D
   mm.mesh=piece.mesh;mm.use_colors=true;mm.instance_count=batches[asset].size()
   for i in mm.instance_count:
    mm.set_instance_transform(i,batches[asset][i].transform*piece.local_transform)
    mm.set_instance_color(i,batches[asset][i].get("tint",Color.WHITE))
   var node:=MultiMeshInstance3D.new();node.multimesh=mm
   node.material_override=piece.material_override
   node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   root.add_child(node)
 return root
