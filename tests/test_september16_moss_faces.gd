extends GutTest

# Owner follow-up rejects the all-upward-face treatment: turf belongs on
# broad flat-ish ledges, with gray cliff junctions and steep gray shoulders.
func test_turf_is_confined_to_flat_ledges_with_gray_wall_junctions()->void:
 var rocks=preload("res://scripts/terrain/field/CliffRockDressing.gd");rocks.prepare()
 for asset:StringName in rocks._visuals:
  if asset in rocks.PLANTS:continue
  var green_area:=0.0;var steep_green:=0.0;var junction_green:=0.0;var steep_stone:=0.0
  for piece:EnvironmentVisualPiece in rocks._visuals[asset].pieces:
   for surface in piece.mesh.get_surface_count():
    var part:=ArrayMesh.new();part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,piece.mesh.surface_get_arrays(surface))
    var faces:=part.get_faces();var turf:=piece.mesh.surface_get_material(surface)==CliffDressing.shared_material()
    for i in range(0,faces.size(),3):
     # Actual tall deployment proportions, not only normalized source normals.
     var size:=Vector3(26,16,9)
     var a:=faces[i]*size;var b:=faces[i+1]*size;var c:=faces[i+2]*size
     var normal:=(c-a).cross(b-a);var area:=normal.length()*.5
     if turf:
      green_area+=area
      if normal.normalized().y<.82:steep_green+=area
      if minf(a.z,minf(b.z,c.z))<.25:junction_green+=area
     elif normal.normalized().y<.70:steep_stone+=area
  assert_gt(green_area,15.0,str(asset)+": broad turf ledges")
  assert_lt(steep_green,.02,str(asset)+": no green steep faces")
  assert_lt(junction_green,.02,str(asset)+": gray native-wall junction")
  assert_gt(steep_stone,green_area,str(asset)+": rock dominates the vertical silhouette")
