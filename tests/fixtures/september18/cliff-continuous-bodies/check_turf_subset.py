from pathlib import Path
import json, hashlib
import numpy as np
p=Path('tests/fixtures/september18/cliff-continuous-bodies');out=Path('docs/qa/2026-09-18-manual/73-cliff-continuous-bodies')
records=[]
for stem in ['union']+[f'world-union-{i:02d}' for i in [19,20,21]]:
 bodyname=stem+'_faces.bin' if stem=='union' else stem+'-faces.bin'
 greenname=stem+'_green.bin' if stem=='union' else stem+'-green.bin'
 faces=np.fromfile(p/bodyname,dtype='<f4').reshape(-1,9)
 green=np.fromfile(p/greenname,dtype='<f4').reshape(-1,9)
 keys={a.tobytes() for a in faces};missing=sum(a.tobytes() not in keys for a in green)
 assert missing==0,(stem,missing)
 record={'mesh':stem,'body_triangles':len(faces),'turf_triangles':len(green),'turf_triangles_missing_from_body':missing,'body_sha256':hashlib.sha256((p/bodyname).read_bytes()).hexdigest(),'turf_sha256':hashlib.sha256((p/greenname).read_bytes()).hexdigest()}
 records.append(record)
 manifest=p/(stem+'-manifest.json')
 if manifest.exists():
  data=json.loads(manifest.read_text());data.update(triangles=len(faces),green=len(green),final_body_sha256=record['body_sha256'],final_turf_sha256=record['turf_sha256']);manifest.write_text(json.dumps(data,indent=2)+'\n')
(out/'turf-subset-checks.json').write_text(json.dumps(records,indent=2)+'\n')
print(json.dumps(records,indent=2))
