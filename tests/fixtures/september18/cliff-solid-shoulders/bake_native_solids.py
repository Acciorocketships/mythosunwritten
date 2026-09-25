"""Study-only CC0 Ultimate Nature rock triangles, with shared midpoint refinement."""
from pathlib import Path
import importlib.util,json
root=Path(__file__).resolve().parents[4];d=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('p',root/'tools/mountain_art/build_nature_terrace_profiles.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
solids=[]
for v in [3,4,5,6]:
 pts,fs=m.read_obj(root/f'assets/UltimateNaturePack/OBJ/Rock_{v}.obj')
 tris=[[tuple(t-.5 for t in pts[i]) for i in f[::-1]] for f in fs]
 # Shared edge midpoint refinement retains source planes but permits a smooth
 # deformation into the existing cliff below the exposed authored face.
 for _ in range(2):
  out=[]
  for a,b,c in tris:
   ab=tuple((x+y)/2 for x,y in zip(a,b));bc=tuple((x+y)/2 for x,y in zip(b,c));ca=tuple((x+y)/2 for x,y in zip(c,a))
   out.extend([[a,ab,ca],[ab,b,bc],[ca,bc,c],[ab,bc,ca]])
  tris=out
 solids.append([list(p) for tri in tris for p in tri])
(d/'native_solids.json').write_text(json.dumps(solids,separators=(',',':')))
