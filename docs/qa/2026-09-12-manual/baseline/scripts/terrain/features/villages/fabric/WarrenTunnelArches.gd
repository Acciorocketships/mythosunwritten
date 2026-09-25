extends RefCounted

## A native frame belongs to the opening between two existing masonry banks.
## The complete three-band bore and both jamb columns precede this finishing
## choice. No street, room, support, or terrain is moved to make an arch fit.
const ASSET := &"sfv.fabric.tunnel_arch.001"
const BOUNDS := AABB(Vector3(-1.9354649,0,-0.1254021),Vector3(3.8709297,4.195075,0.2508041))

static func placements(source: WarrenSpatialPlan) -> Array[Dictionary]:
 var out: Array[Dictionary]=[]
 var public:Dictionary={}
 for p in source.route_floor_cells:public[p]=true
 var cells:Array[Vector3i]=source.route_floor_cells.duplicate()
 cells.sort_custom(func(a:Vector3i,b:Vector3i)->bool:
  return a.y<b.y if a.y!=b.y else a.x<b.x if a.x!=b.x else a.z<b.z)
 for p in cells:
  for direction:Vector3i in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
   var lateral:=Vector3i.RIGHT if direction.z!=0 else Vector3i.BACK
   var q:=p+lateral
   if not public.has(q) or not public.has(p+direction) or not public.has(q+direction):continue
   if not _solid(source.grid,p+Vector3i.UP*3) or not _solid(source.grid,q+Vector3i.UP*3):continue
   if _solid(source.grid,p+direction+Vector3i.UP*3) or _solid(source.grid,q+direction+Vector3i.UP*3):continue
   var jambs:=[p-lateral,q+lateral]
   var enclosed:=true
   for jamb:Vector3i in jambs:
    if not _bearing(source,jamb):enclosed=false
    for band in 3:
     if not _solid(source.grid,jamb+Vector3i.UP*band):enclosed=false
   if not enclosed:continue
   # Centre the native opening on the two walking lanes. Its legs stand in
   # the already solid side columns; 10 cm inset joins the masonry return.
   var outward:=Vector3(direction)
   var origin:=(Vector3(p)+Vector3(q))*0.75+outward*0.65
   var pose:=Transform3D(Basis(Vector3.UP,atan2(outward.x,outward.z)),origin)
   var id:=StringName("tunnel-mouth/%d/%d/%d/%d/%d"%[p.x,p.y,p.z,direction.x,direction.z])
   out.append({"asset_id":ASSET,"stable_id":id,"placement_id":&"tunnel_frame",
    "transform":pose,"bounds":pose*BOUNDS,"collision_pieces":1,
    "mouth_cells":[p,q],"outward":direction,"jamb_cells":jambs})
 return out

static func _solid(grid: WarrenSpatialGrid,cell:Vector3i)->bool:
 return grid.use_at(cell) in [WarrenSpatialGrid.Use.STRUCTURAL_VOLUME,WarrenSpatialGrid.Use.PRIVATE_VOLUME]

static func _bearing(source:WarrenSpatialPlan,cell:Vector3i)->bool:
 if _solid(source.grid,cell+Vector3i.DOWN):return true
 if source.source_volume==null:return false
 var maze:=source.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
 if maze==null:return false
 var column:=Vector2i(floori(float(cell.x)/2.0),floori(float(cell.z)/2.0))
 return maze.massif.has_column(column) and cell.y==maze.massif.base_at(column)
