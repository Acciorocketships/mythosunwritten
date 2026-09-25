extends RefCounted
const BASE=preload("res://tests/fixtures/september18/cliff-embedded-shoulders/before.gd")
static var _faces:=PackedVector3Array()
static var _green:=PackedVector3Array()
static func prepare()->void:
 BASE.prepare()
 if not _faces.is_empty():return
 _faces=FileAccess.open("res://tests/fixtures/september18/cliff-embedded-shoulders/bevel-union-faces.bin",FileAccess.READ).get_var()
 _green=FileAccess.open("res://tests/fixtures/september18/cliff-embedded-shoulders/bevel-union-green.bin",FileAccess.READ).get_var()
static func make(pose:Transform3D,width:float,height:float,seed_value:int,region:HeightfieldRegion=null,left_end:bool=false,right_end:bool=false)->Array[Dictionary]:
 prepare()
 var forms:=BASE.make(pose,width,height,seed_value,region,left_end,right_end)
 if pose.origin.distance_to(Vector3(-480,32,-253.5))>.01:return forms
 forms[0].faces=_faces;forms[0].green=_green
 var bounds:=AABB(_faces[0],Vector3.ZERO)
 for point:Vector3 in _faces:bounds=bounds.expand(point)
 forms[0].bounds=pose*bounds
 return forms
static func mesh(form:Dictionary)->ArrayMesh:return BASE.mesh(form)
