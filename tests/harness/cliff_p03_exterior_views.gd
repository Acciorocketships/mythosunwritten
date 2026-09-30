extends RefCounted
func run(review:Node3D)->void:
 for view:Dictionary in review._views:
  if view.id=="ledges-side":
   view.id="ledges-side-exterior";view.position=Vector3(516,49,963);view.target=Vector3(497,40,955)
  if view.id=="ledges-front":
   view.id="ledges-front-exterior";view.position=Vector3(508,50,934);view.target=Vector3(497,40,955)
 await review._capture_all(2)
 print("[exterior_views] captured")
