extends "res://tests/harness/september11_floating_world_qa.gd"
func _spots() -> Array:
	var sites:Array=[
		["island","receiving lake island",Vector3(763.818,4.05,-208.6394),Vector3(763.818,5.25,-208.3394)],
		["lake","receiving lake peninsula",Vector3(-1124.092,4.05,1933.115),Vector3(-1124.092,5.25,1933.415)],
		["gorge","steep river gorge",Vector3(-1316.635,20,-354.345),Vector3(-1316.635,21.2,-354.045)]]

	var args:=OS.get_cmdline_user_args()
	if args.has("--spot"):
		for site:Array in sites:
			if site[0]==args[args.find("--spot")+1]: return [site]
	return sites
