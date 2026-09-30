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
}
## Shared moss parameters for the slope and slope-rock materials (main thread).
static func apply_moss(material:ShaderMaterial)->void:
 material.set_shader_parameter("ground_palette_texture",CliffDressing.ground_texture())
 material.set_shader_parameter("grass_uv",CliffDressing.ground_uv())
 material.set_shader_parameter("moss_amount",1.0)
 material.set_shader_parameter("moss_slopes",true)
 material.set_shader_parameter("moss_full",true)
 var moss:Dictionary=MOSS_TEXTURES[STYLE.moss_texture]
 for key:String in moss:
  var value=moss[key]
  material.set_shader_parameter(key,load(value) if value is String else value)
 # Rock exposed in the slope surface uses Meadow's authored stone.
 material.set_shader_parameter("exposure_rock",STYLE.sheet_study in ["bedrock","stamp"])
 material.set_shader_parameter("rock_albedo",load("res://terrain/environment/textures/meadow/T_Rock_02_A.res"))

static func mesh(rock:Dictionary)->ArrayMesh:
 assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
 var surfaces:Array=rock.render_arrays if rock.has("render_arrays") else mesh_arrays(rock)
 var result:=ArrayMesh.new()
 for surface in surfaces.size():
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surfaces[surface])
  var material:=ShaderMaterial.new();material.shader=load("res://terrain/materials/cliff_crag.gdshader")
  material.set_shader_parameter("moss_upward",.45)
  apply_moss(material)
  result.surface_set_material(surface,material)
 return result

## Moss grade height per unit of (1 - normal.y) on the whole-wall slope: a
## 20 degree slope stays mostly lawn, 35 degrees is moss.
const SHEET_MOSS_RISE:=28.0
## 1 - normal.y of the steepest ordinary slope: one storey plus three levels
## (7 m) over one 12 m tile, whose smootherstep peaks at 1.875x the mean
## gradient (47.6 degrees). Below it the sheet is exactly the terrain's lawn.
const SHEET_LAWN_STEEPNESS:=0.326
## Fully mossy from 60 degrees (cliff faces and cliff-end ramps).
const SHEET_MOSS_STEEPNESS:=0.5
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
  var steep:=1.0-normals[i].y
  var grade:=0.0
  if steep>SHEET_LAWN_STEEPNESS:
   grade=lerpf(.05,.24,clampf((steep-SHEET_LAWN_STEEPNESS)/(SHEET_MOSS_STEEPNESS-SHEET_LAWN_STEEPNESS),0.0,1.0))
  var root:Array=rock.native_roots[points[i]]
  if root.size()>2:grade=maxf(grade,root[2])
  rise[i]=Vector2(SHEET_MOSS_RISE*grade,top)
 arrays[Mesh.ARRAY_TEX_UV2]=rise
 return [arrays]


## Smooth maximum: the larger of a and b with a rounded join of radius k.
static func _smax(a:float,b:float,k:float)->float:
 var h:=maxf(k-absf(a-b),0.0)/k
 return maxf(a,b)+h*h*k*.25
