extends RefCounted


func run(review: Node) -> void:
	var probe = load("res://tests/harness/october9_water_branch_supply.gd").new()
	probe.sample_step = .25
	probe.support_trial = true
	probe.diagonals = true
	probe.output_suffix = "-fine"
	await probe.run(review)
	probe.support_trial = false
	probe.level_tolerance = .02
	probe.output_suffix = "-fine-tolerant"
	await probe.run(review)
