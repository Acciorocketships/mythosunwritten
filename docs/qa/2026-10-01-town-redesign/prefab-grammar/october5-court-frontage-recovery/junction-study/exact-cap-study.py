from pathlib import Path
import subprocess
p=Path('scripts/terrain/features/villages/kit/KitVillageBuildings.gd');saved=p.read_bytes()
try:
 s=saved.decode()
 marker='\tvar room_projections := preload('
 start=s.index(marker)
 s=s[:start]+'''\t# Temporary exact-native cap study; restored after rendering.
	for tower: Dictionary in towers:
		if tower.get("attachment", &"") == &"corner":
			var native_cap: Dictionary = FileAccess.open("res://terrain/environment/geometry/pure_village_roof_turret.bin", FileAccess.READ).get_var()
			tower.cutters = preload("res://scripts/terrain/features/villages/kit/KitTowerAssembly.gd").roof_cutters(native_cap[&"pure_village.roof_turret.roof"], tower.pose*tower.parts[-1].transform)
'''+s[start:]
 p.write_text(s)
 with open('/tmp/exact-cap-study.out','w') as out:
  subprocess.run(['/Applications/Godot.app/Contents/MacOS/Godot','--path','.','--log-file','/tmp/exact-cap-study.log','-s','tests/harness/suntail/kit_town_review.gd','--','--cities','53:grand','--views','turrets','--output','/tmp/exact-cap-study'],stdout=out,stderr=subprocess.STDOUT,check=True,timeout=420)
finally:
 p.write_bytes(saved)
 assert p.read_bytes()==saved
 print('Original cap implementation restored',flush=True)
