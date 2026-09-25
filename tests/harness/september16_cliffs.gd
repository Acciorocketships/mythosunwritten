extends "res://tests/harness/september15_reported_qa.gd"
func _spots()->Array:
 var records:=super._spots()
 records.append(["Q01","September 16 9.59.51 AM",Vector3(299.3,18.7,517.3),Vector3(300.0,20.9,518.3)])
 records.append(["Q02","September 16 10.06.06 AM",Vector3(471.5,30.2,875.1),Vector3(469.1,31.8,878.9)])
 return records
