class_name TerrainGenerationRuleLibrary
extends Resource

# Array of TerrainGenerationRule instances
@export var rules: Array[TerrainGenerationRule] = []


func _init() -> void:
	rules.append(LevelContradictionRule.new())
	rules.append(LevelEdgeRule.new())
