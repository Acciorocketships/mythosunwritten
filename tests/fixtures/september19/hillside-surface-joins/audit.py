"""Localize the native surface rises; frozen seed experiments are not mesh fixes."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[4]
QA=ROOT/'docs/qa/2026-09-19-manual/114-hillside-surface-joins'
rows=json.loads((QA/'claims.json').read_text())
samples=[r for r in rows if r['group']=='samples']
summary={}
for metric in ['field','mesh','margin','fraction','distance']:
    def value(r):
        return r[metric] if metric in ['field','mesh'] else (r[metric][0]['level'] if r[metric] else None)
    rises=[]
    for a,b in zip(samples,samples[1:]):
        x,y=value(a),value(b)
        if x is not None and y is not None and y-x>.001:
            rises.append({'index':a['index'],'from':a['point'],'to':b['point'],'rise':y-x})
    summary[metric]={'rises':rises,'max_rise':max((r['rise'] for r in rises),default=0)}
for r in samples:
    print(r['index'],*(f'{r[k]:.4f}' for k in ['mesh','field']),*[f"{k}={r[k][0]['level']:.4f}@{r[k][0]['source']}:{r[k][0]['station']}" if r[k] else k+'=dry' for k in ['margin','fraction','distance']])
(QA/'audit.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
