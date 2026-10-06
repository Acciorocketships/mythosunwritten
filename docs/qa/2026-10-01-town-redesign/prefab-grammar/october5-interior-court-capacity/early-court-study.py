from pathlib import Path
import subprocess
h=Path('tests/harness/suntail/court_site_supply.gd').read_text()
a=h.index('\t\tvar streets :=');b=h.index('\n\t\tout[city] =',a)
body='\n'.join(line[1:] for line in h[a:b].splitlines())
helpers=h[h.index('\nfunc _count'):]
study='extends RefCounted\nvar _cut_depth := 6\nvar _field_only := false\nvar _share_flat_streets := false\nfunc analyze(plan: WarrenMazeSourcePlan):\n'+body+'\n\treturn {"sites":sites,"rejections":rejected,"supported":supported}\n'+helpers
Path('/tmp/early-court-supply.gd').write_text(study)
p=Path('scripts/terrain/features/villages/fabric/WarrenMazeCarver.gd');saved=p.read_bytes()
try:
 s=saved.decode();marker='\tWarrenPlotPlanner.reserve(preview, profile, false)'
 insertion='\tvar study_report: Dictionary = load("/tmp/early-court-supply.gd").new().analyze(preview)\n\tFileAccess.open("/tmp/early-court-%d.json" % world_seed,FileAccess.WRITE).store_string(JSON.stringify(study_report))\n'
 assert marker in s;p.write_text(s.replace(marker,insertion+marker))
 with open('/tmp/early-court-study.out','w') as out:
  subprocess.run(['/Applications/Godot.app/Contents/MacOS/Godot','--headless','--path','.','--log-file','/tmp/early-court-study.log','-s','tests/harness/suntail/court_site_supply.gd','--','--cities','31:large,8:grand,9:grand,13:grand,43:grand,53:grand,63:grand,83:grand,103:grand,301:grand','--cut-depth','6','--output','/tmp/early-court-final-supply.json'],stdout=out,stderr=subprocess.STDOUT,check=True,timeout=240)
finally:p.write_bytes(saved);assert p.read_bytes()==saved;print('Carver restored')
