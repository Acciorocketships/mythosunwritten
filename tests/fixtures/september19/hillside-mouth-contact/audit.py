"""Field/mesh route gates for the contact experiment; no tolerance relaxation."""
from pathlib import Path
import argparse,json
ROOT=Path(__file__).resolve().parents[4]
QA=ROOT/'docs/qa/2026-09-19-manual/116-hillside-mouth-contact'
BASE=QA.parent/'115-hillside-fill-stages'
parser=argparse.ArgumentParser();parser.add_argument('--require-downhill',action='store_true');args=parser.parse_args()
report={}
for folder,label in [(BASE,'before'),(QA,'after')]:
 rows=json.loads((folder/'candidate-samples.json').read_text())
 rises=[{'index':a['index'],'rise':b['field']-a['field']} for a,b in zip(rows,rows[1:]) if b['field']-a['field']>.001]
 report[label]={'points':len(rows),'rises':rises,'max_rise':max([x['rise'] for x in rises],default=0)}
 if label=='before':previous=rows
 else:
  assert all(a['point']==b['point'] and a['ground']==b['ground'] for a,b in zip(previous,rows))
  report['minimum_depth']=min(r['field']-r['ground'] for r in rows)
(QA/'field-audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
if args.require_downhill:assert not report['after']['rises'],'Candidate field rises downstream'
