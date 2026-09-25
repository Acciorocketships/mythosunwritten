extends GutTest
const CRAGS=preload("res://tests/fixtures/september17/cliff-triangulation/before.gd")
func test_tall_crags_do_not_stretch_dense_rows_diagonally()->void:
 CRAGS.prepare()
 var form:Dictionary=CRAGS.make(Transform3D.IDENTITY,24,64,2697992464)[0]
 var stretched:=0;var crossing:=0
 for i in range(0,form.faces.size(),3):
  for j in 3:
   var a:Vector3=form.faces[i+j];var b:Vector3=form.faces[i+(j+1)%3]
   if minf(a.z,b.z)<.8 or absf(a.x-b.x)<.2:continue
   crossing+=1
   if absf(a.y-b.y)>.8:stretched+=1
 print("CRAG_STRETCHED_EDGES ",stretched," / ",crossing)
 assert_lt(float(stretched)/maxi(1,crossing),.01,"Dense rock sampling must not stretch into diagonal hatching")

func test_steep_faces_keep_physical_detail_sampling()->void:
 CRAGS.prepare()
 var form:Dictionary=CRAGS.make(Transform3D.IDENTITY,24,64,2697992464)[0]
 var largest:=0.0
 for i in range(0,form.faces.size(),3):
  for j in 3:
   var a:Vector3=form.faces[i+j];var b:Vector3=form.faces[i+(j+1)%3]
   if minf(a.z,b.z)<.8 or absf(a.x-b.x)>.0001:continue
   largest=maxf(largest,absf(a.y-b.y))
 print("CRAG_VERTICAL_SAMPLE_GAP ",largest)
 assert_lte(largest,.201,"Tall faces need the same resolved crags as low faces, including gaps between ledges")
