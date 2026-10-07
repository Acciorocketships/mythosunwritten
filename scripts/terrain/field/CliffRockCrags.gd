extends RefCounted
## Render arrays and materials of the whole-wall slope solid
## (CliffSlopeField.solid): its field-gradient normals, moss grade, rock
## exposure and biome tint. The procedural crag formations this file once
## built for the native KayKit walls were retired with them (dual-grid terrain
## tiles, September 30). Worker-pure until mesh(), which runs on the main thread.
const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")

## Moss detail from the owner's asset packs (September 23): each pack's own
## rock-moss layer. Colour textures act relative to their mean colour, so the
## biome-derived moss tone still leads; masks break coverage into patches.
const MOSS_TEXTURES:={
 "raygeas":{"moss_detail":"res://terrain/materials/moss/raygeas_grass.png","moss_detail_mean":Vector3(.2825,.5289,.2044),"moss_detail_strength":.8,"moss_detail_scale":.55},
 "suntail":{"moss_mask":"res://terrain/materials/moss/suntail_mask.png","moss_mask_weight":1.2,"moss_mask_scale":.22,"moss_mask_cracks":true,"moss_mask_range":Vector2(.93,.99)},
 "angry":{"moss_detail":"res://terrain/materials/moss/angry_moss.png","moss_detail_mean":Vector3(.332,.5174,.1911),"moss_detail_strength":.9,"moss_detail_scale":.3,
  "moss_mask":"res://terrain/materials/moss/angry_mask.png","moss_mask_weight":.45,"moss_mask_scale":.12},
 "polyart":{"moss_detail":"res://terrain/materials/moss/polyart_moss.png","moss_detail_mean":Vector3(.3238,.5127,.1931),"moss_detail_strength":.9,"moss_detail_scale":.3},
 # Pure Village (October 1): its mottled Grass01 (the owner's pick, the
 # default) and its patchy Grass02 (green over sandy earth).
 "village":{"moss_detail":"res://terrain/materials/moss/village_grass.png","moss_detail_mean":Vector3(.2227,.4568,.1908),"moss_detail_strength":.85,"moss_detail_scale":.35},
 "village_patches":{"moss_detail":"res://terrain/materials/moss/village_patches.png","moss_detail_mean":Vector3(.4428,.5703,.3252),"moss_detail_strength":.9,"moss_detail_scale":.25},
}
## Shared moss parameters for the slope and slope-rock materials (main thread).
static func apply_moss(material:ShaderMaterial)->void:
 material.set_shader_parameter("ground_palette_texture",CliffDressing.ground_texture())
 material.set_shader_parameter("grass_uv",CliffDressing.ground_uv())
 material.set_shader_parameter("moss_amount",1.0)
 material.set_shader_parameter("moss_slopes",true)
 material.set_shader_parameter("moss_full",true)
 material.set_shader_parameter("lawn_steepness",SHEET_LAWN_STEEPNESS)
 material.set_shader_parameter("moss_steepness",SHEET_MOSS_STEEPNESS)
 material.set_shader_parameter("moss_rise",SHEET_MOSS_RISE)
 var moss:Dictionary=MOSS_TEXTURES[STYLE.moss_texture]
 for key:String in moss:
  var value=moss[key]
  material.set_shader_parameter(key,load(value) if value is String else value)
 # Rock exposed in the slope surface uses Meadow's authored stone.
 material.set_shader_parameter("exposure_rock",STYLE.sheet_study in ["bedrock","stamp"])
 material.set_shader_parameter("rock_albedo",load("res://terrain/environment/textures/meadow/T_Rock_02_A.res"))

static func mesh(rock:Dictionary,surfaces:Array=[],material:ShaderMaterial=null,lods:Dictionary={})->ArrayMesh:
 assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
 if surfaces.is_empty():surfaces=rock.render_arrays if rock.has("render_arrays") else mesh_arrays(rock)
 var result:=ArrayMesh.new()
 for surface in surfaces.size():
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surfaces[surface],[],lods)
  result.surface_set_material(surface,material if material!=null else sheet_material())
 return result

## One sheet material for every chunk while the style holds (each chunk made
## its own: a new material and uniform set per streamed chunk, in an
## integration step that reached 20-27 ms). Review tools that switch the style
## get a fresh one.
static var _shared_sheet:ShaderMaterial
static var _shared_sheet_key:=""
static func shared_sheet_material()->ShaderMaterial:
 var key:="%s|%s"%[STYLE.moss_texture,STYLE.sheet_study]
 if _shared_sheet==null or key!=_shared_sheet_key:
  _shared_sheet=sheet_material();_shared_sheet_key=key
 return _shared_sheet

static func sheet_material()->ShaderMaterial:
 var material:=ShaderMaterial.new();material.shader=load("res://terrain/materials/cliff_crag.gdshader")
 material.set_shader_parameter("moss_upward",.45)
 apply_moss(material)
 return material

## The sheet split into SHEET_TILE world squares (by triangle centroid), each
## one indexed surface with its own LODs. A chunk's sheet was one ~470k
## triangle unindexed draw touching the player's 3x3 chunks, so the GPU could
## neither cull what is behind the camera nor skip shadows past their distance,
## and shaded three vertices per triangle at full detail (October 6).
## Every attribute of a sheet vertex is a function of its position
## (`native_roots[point]`), so welding by position is exact. Worker-pure:
## returns [{"arrays": surface arrays with ARRAY_INDEX, "lods": {edge length:
## PackedInt32Array}}], plain data for mesh() on the main thread.
const SHEET_TILE:=48.0
static func split_tiles(arrays:Array,pose:Transform3D,tile:float=SHEET_TILE,with_lods:=true)->Array:
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var groups:Dictionary={}
 for t in vertices.size()/3:
  var centre:=pose*((vertices[3*t]+vertices[3*t+1]+vertices[3*t+2])/3.0)
  var key:=Vector2i(floori(centre.x/tile),floori(centre.z/tile))
  # Plain Arrays: a packed array read out of a Dictionary is a copy, and
  # appending to it would leave every tile empty.
  if not groups.has(key):groups[key]=[]
  (groups[key] as Array).append(t)
 var keys:Array=groups.keys()
 keys.sort()
 var tiles:Array=[]
 for key:Vector2i in keys:
  var triangles:Array=groups[key]
  var slot:Dictionary={}
  var sources:=PackedInt32Array()
  var indices:=PackedInt32Array();indices.resize(triangles.size()*3)
  var i:=0
  for t:int in triangles:
   for c in 3:
    var v:=3*t+c
    var at:int=slot.get(vertices[v],-1)
    if at<0:
     at=sources.size();slot[vertices[v]]=at;sources.append(v)
    indices[i]=at;i+=1
  var out:Array=[];out.resize(Mesh.ARRAY_MAX)
  for a in Mesh.ARRAY_MAX:
   if arrays[a]==null or a==Mesh.ARRAY_INDEX:continue
   var source=arrays[a]
   var copy=source.duplicate();copy.resize(sources.size())
   for k in sources.size():copy[k]=source[sources[k]]
   out[a]=copy
  out[Mesh.ARRAY_INDEX]=indices
  tiles.append({"arrays":out,"lods":_lods(out) if with_lods else {}})
 return tiles

## Godot's own importer simplification (the meshoptimizer pass the GLB import
## runs), as plain index lists keyed by the LOD's edge length. The importer may
## re-split vertices by normal, so its arrays replace the input's.
static func _lods(arrays:Array)->Dictionary:
 var importer:=ImporterMesh.new()
 importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
 importer.generate_lods(60.0,25.0,[])
 var lods:Dictionary={}
 for l in importer.get_surface_lod_count(0):
  lods[importer.get_surface_lod_size(0,l)]=importer.get_surface_lod_indices(0,l)
 var simplified:Array=importer.get_surface_arrays(0)
 for a in Mesh.ARRAY_MAX:arrays[a]=simplified[a]
 return lods

## Moss grade height per unit of (1 - normal.y) on the whole-wall slope: a
## 20 degree slope stays mostly lawn, 35 degrees is moss.
const SHEET_MOSS_RISE:=28.0
## The lawn-to-moss band (SlopeProfile.LAWN_STEEPNESS / MOSS_STEEPNESS):
## below it the sheet is exactly the terrain's lawn, above it moss.
const SHEET_LAWN_STEEPNESS:=SlopeProfile.LAWN_STEEPNESS
const SHEET_MOSS_STEEPNESS:=SlopeProfile.MOSS_STEEPNESS
## One surface of detached render arrays for a slope-solid placement (its
## `faces`, and per-vertex `native_roots` [normal, rock exposure, moss grade]).
## No mesh, material, node or rendering-server resource is created here.
static func mesh_arrays(rock:Dictionary,_region:HeightfieldRegion=null,seed_value:int=0)->Array:
 var points:PackedVector3Array=rock.faces
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=points
 var uv:=PackedVector2Array();uv.resize(points.size())
 arrays[Mesh.ARRAY_TEX_UV]=uv
 var normals:=PackedVector3Array();normals.resize(points.size())
 var colors:=PackedColorArray();var tints:Dictionary={}
 var pose:Transform3D=rock.transform
 for i in points.size():
  var p:Vector3=points[i]
  var root:Array=rock.native_roots[p]
  normals[i]=root[0]
  # RGB carries the lawn's biome tint for the moss grade (white without a
  # seed): bilinear on the terrain sheet's own 24 m tint lattice
  # (TerrainChunkMesher.CELL), so where the slope meets the terrain both
  # surfaces carry the identical colour. A snapped cell tint stepped
  # visibly across the fine mesh.
  var tint:=Color(1,1,1)
  if seed_value!=0:
   var world:=pose*p
   var step:=TerrainChunkMesher.CELL
   var gx:=floorf(world.x/step);var gz:=floorf(world.z/step)
   var corners:Array[Color]=[]
   for corner:Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
    var key:=Vector2(gx+corner.x,gz+corner.y)
    if not tints.has(key):tints[key]=BiomeRegistry.ground_tint_at(Vector3(key.x*step,0,key.y*step),seed_value)
    corners.append(tints[key])
   var fx:=world.x/step-gx;var fz:=world.z/step-gz
   tint=corners[0].lerp(corners[1],fx).lerp(corners[2].lerp(corners[3],fx),fz)
  colors.append(Color(tint.r,tint.g,tint.b,float(root[1])))
 arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors
 var top:float=rock.get("top",NAN)
 if is_nan(top):
  top=-INF
  for p:Vector3 in points:top=maxf(top,(pose*p).y)
 # The whole-wall slope is a hillside: lawn where it is gentle, moss as it
 # steepens past the steepest ordinary slope. Colour is a function of
 # steepness alone (owner, September 29: standard, predictable slopes): a
 # covered ordinary slope is lawn like the terrain beside it, and a cliff's
 # end ramp is mossy like the face beside it. x stands for the height the moss
 # grade reads (the shader maps x/28 through .05..24).
 var rise:=PackedVector2Array();rise.resize(points.size())
 for i in points.size():
  var grade:=SlopeProfile.moss_grade(normals[i].y)
  var root:Array=rock.native_roots[points[i]]
  if root.size()>2:grade=maxf(grade,root[2])
  rise[i]=Vector2(SHEET_MOSS_RISE*grade,top)
 arrays[Mesh.ARRAY_TEX_UV2]=rise
 return [arrays]


## Smooth maximum: the larger of a and b with a rounded join of radius k.
static func _smax(a:float,b:float,k:float)->float:
 var h:=maxf(k-absf(a-b),0.0)/k
 return maxf(a,b)+h*h*k*.25
