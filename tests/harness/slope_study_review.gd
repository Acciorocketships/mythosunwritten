extends SceneTree
## STUDY (September 25 rethink): renders the sheet slope solid and its rocks
## for each study variant on a synthetic 12 m wall with an outer corner and a
## lower 5 m terrace, using the production crag material and rock meshes.
##   Godot --path . -s res://tests/harness/slope_study_review.gd -- OUT_DIR [styles]
const FIELD=preload("res://scripts/terrain/field/CliffSlopeField.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffSlopeRocks.gd")
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
const SEED:=2697992464
func _initialize()->void:
 call_deferred("_run")
func _run()->void:
 var args:=OS.get_cmdline_user_args()
 var out:String=args[0] if args.size()>0 else "/tmp/slope-study"
 var styles:PackedStringArray=(args[1] if args.size()>1 else "sheet,sheet_bedrock,sheet_stamp,sheet_blend").split(",")
 DirAccess.make_dir_recursive_absolute(out)
 root.size=Vector2i(1400,900)
 var scene:=Node3D.new();root.add_child(scene)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);light.light_energy=1.3;light.shadow_enabled=true;scene.add_child(light)
 var world:=WorldEnvironment.new();world.environment=Environment.new()
 var sky:=Sky.new();sky.sky_material=ProceduralSkyMaterial.new()
 world.environment.background_mode=Environment.BG_SKY;world.environment.sky=sky
 world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_SKY;world.environment.ambient_light_energy=.7
 world.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;world.environment.ssao_enabled=true
 scene.add_child(world)
 # Ground plane far below so the slope's foot reads.
 var views:={"oblique":[Vector3(-44,18,34),Vector3(-18,5,-4)],"close":[Vector3(4,8,18),Vector3(-6,5,0)],"face":[Vector3(-8,10,8),Vector3(-14,9,-6)],"low":[Vector3(-30,2.5,14),Vector3(-16,4,0)]}
 for style:String in styles:
  STYLE.apply(style)
  var started:=Time.get_ticks_msec()
  # An upper wall (5 -> 12 m) turning a corner at x = -28.5 and a lower wall
  # (0 -> 5 m), both facing +z (wall-segment foot lines).
  var upper:=FIELD.straight_wall(Vector2(-28.5,-8),Vector2(30,-8),Vector2(0,1),12.0,5.0)
  var corner:=FIELD.straight_wall(Vector2(-28.5,-20),Vector2(-28.5,-8),Vector2(-1,0),12.0,5.0)
  var lower:=FIELD.straight_wall(Vector2(-28.5,4),Vector2(30,4),Vector2(0,1),5.0)
  var field=FIELD.new([upper,corner,lower],SEED)
  field.ground_at=func(q:Vector2)->float:
   if q.x<-28.5:return 0.0
   return 12.0 if q.y<-8.0 else (5.0 if q.y<4.0 else 0.0)
  field._env=null
  var holder:=Node3D.new();scene.add_child(holder)
  var floor:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(200,200);floor.mesh=plane
  var grass:=StandardMaterial3D.new();grass.albedo_color=Color(.36,.5,.22);floor.material_override=grass;floor.position.y=-.03;holder.add_child(floor)
  for placement:Dictionary in field.solid(Rect2(-60,-40,110,70)):
   placement["render_arrays"]=CRAGS.mesh_arrays(placement,null,0)
   var node:=MeshInstance3D.new();node.mesh=CRAGS.mesh(placement);holder.add_child(node)
  var entries:={}
  for rock:Dictionary in field.rock_list:entries[rock.piece]=entries.get(rock.piece,[])+[rock]
  holder.add_child(ROCKS.build(entries,0))
  print("[slope_study] %s rocks=%d ms=%d"%[style,field.rock_list.size(),Time.get_ticks_msec()-started])
  var cam:=Camera3D.new();holder.add_child(cam);cam.current=true;cam.fov=60
  for id:String in views:
   cam.look_at_from_position(views[id][0],views[id][1])
   for i in 3:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("%s/%s_%s.png"%[out,style,id])
  holder.queue_free();await process_frame
 quit()
