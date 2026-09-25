extends RefCounted
const BASE=preload("res://tests/fixtures/september19/bank-preserved-relief/attachments.gd")
const EXPOSURE=preload("res://tests/fixtures/september19/bank-exposure/exposure.gd")
static func publish(proposals:Array,sources:Array,banks:Array,region:HeightfieldRegion=null,
 features:FeatureContext=null,water:WaterFieldContext=null)->Array:
 return EXPOSURE.filter(BASE.publish(proposals,sources,banks,region,features,water),sources,banks)
