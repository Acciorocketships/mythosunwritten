from pathlib import Path
import subprocess
p=Path('scripts/terrain/features/villages/kit/KitVillageBuildings.gd');saved=p.read_bytes()
try:
 s=saved.decode().replace('\tvar roof_blocked_windows := 0','\tfor study_roof: Dictionary in roofs: study_roof.dormers.clear()\n\tvar roof_blocked_windows := 0')
 assert s!=saved.decode();p.write_text(s)
 with open('/tmp/no-dormer-study.out','w') as out:
  subprocess.run(['/Applications/Godot.app/Contents/MacOS/Godot','--path','.','--log-file','/tmp/no-dormer-study.log','-s','tests/harness/suntail/kit_town_review.gd','--','--cities','53:grand','--views','none','--view','suspect:-20.49615,41,9.969208:-18,38,-10:65','--output','/tmp/no-dormer-study'],stdout=out,stderr=subprocess.STDOUT,check=True,timeout=300)
finally:
 p.write_bytes(saved);assert p.read_bytes()==saved;print('Original source restored')
