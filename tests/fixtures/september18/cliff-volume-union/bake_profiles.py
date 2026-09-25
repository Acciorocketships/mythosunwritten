import importlib.util, math, json, hashlib
from pathlib import Path
root=Path('/Users/ryko/story')
spec=importlib.util.spec_from_file_location('profiles',root/'tools/mountain_art/build_nature_terrace_profiles.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
sources=[]
for variant,yaw,pitch in [(3,30,12),(4,50,-15),(5,65,20),(6,25,-20)]:
 p=root/f'assets/UltimateNaturePack/OBJ/Rock_{variant}.obj'
 vertices,faces=mod.read_obj(p)
 a,b=map(math.radians,[yaw,pitch]);rot=[]
 for v in vertices:
  x,y,z=[t-.5 for t in v]
  x,z=math.cos(a)*x+math.sin(a)*z,-math.sin(a)*x+math.cos(a)*z
  y,z=math.cos(b)*y-math.sin(b)*z,math.sin(b)*y+math.cos(b)*z
  rot.append((x,y,z))
 lo=[min(v[i] for v in rot) for i in range(3)];hi=[max(v[i] for v in rot) for i in range(3)]
 rot=[tuple((v[i]-lo[i])/(hi[i]-lo[i]) for i in range(3)) for v in rot]
 for hand in [1,-1]:
  sources.append(dict(source=str(p.relative_to(root)),yaw=yaw,pitch=pitch,hand=hand,sha256=hashlib.sha256(p.read_bytes()).hexdigest(),body=[[max(0,mod.front(rot,faces,x/48,y/32,hand)) for x in range(49)] for y in range(33)]))
out=root/'tests/fixtures/september18/cliff-volume-union/rotated_bare_rocks.json'
out.write_text(json.dumps(dict(license='Quaternius Ultimate Nature Pack, CC0',sources=sources),separators=(',',':'))+'\n')
print(out)
